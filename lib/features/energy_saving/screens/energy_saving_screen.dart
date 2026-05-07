import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../main.dart' show navigationIndexProvider;
import '../../../models/device.dart';
import '../../../models/energy_scenario.dart';
import '../../../models/schedule.dart';
import '../../../providers/consumption_provider.dart';
import '../../../providers/devices_provider.dart';
import '../../../providers/esp_provider.dart';
import '../../../services/ai_scenario_service.dart';
import '../../../services/database_service.dart';
import '../../../services/notification_service.dart';
import '../widgets/device_priority_card.dart';

final energySavingModeProvider = StateProvider<bool>((ref) => false);

class EnergySavingScreen extends ConsumerStatefulWidget {
  const EnergySavingScreen({super.key});

  @override
  ConsumerState<EnergySavingScreen> createState() =>
      _EnergySavingScreenState();
}

class _EnergySavingScreenState extends ConsumerState<EnergySavingScreen> {
  final TextEditingController _budgetController =
      TextEditingController(text: '500');

  List<EnergyScenario>? _scenarios;
  bool _isLoading = false;
  String? _errorType;
  int _tipIndex = 0;
  Timer? _tipTimer;

  static const List<String> _tips = [
    'جاري تحليل استهلاكك...',
    'بنحسب الشرائح المصرية...',
    'بنقترح أفضل الخطط...',
    'لحظة واحدة...',
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedBudget();
    _startAutomationListeners();
  }

  Future<void> _loadSavedBudget() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble('monthly_budget') ?? 500.0;
    if (mounted) {
      _budgetController.text = saved.toStringAsFixed(0);
    }
  }

  void _startAutomationListeners() {
    ref.listenManual(monthlyCostProvider, (previous, next) {
      final isAutoMode = ref.read(energySavingModeProvider);
      if (!isAutoMode) return;
      final budget = double.tryParse(_budgetController.text) ?? 500.0;
      next.whenData((spent) {
        if (spent / budget > 0.9) {
          _performAutoShutdown();
        }
      });
    });
    _checkMorningLightsOff();
  }

  Future<void> _performAutoShutdown() async {
    final devices = ref.read(devicesProvider);
    final espService = ref.read(httpEspServiceProvider);
    bool acted = false;
    for (var device in devices) {
      if (device.priority == DevicePriority.nonEssential && device.isOn) {
        espService.publishRelayCommand(device.relayId, false);
        acted = true;
      }
    }
    if (acted) {
      NotificationService().showNotification(
        id: 1,
        title: 'Energy Saving Active',
        body: 'Non-essential devices turned off — 90% budget reached.',
      );
    }
  }

  Future<void> _checkMorningLightsOff() async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString('morning_lights_off_time') ?? '08:00';
    final now = DateTime.now();
    final hour = int.parse(timeStr.split(':')[0]);
    final minute = int.parse(timeStr.split(':')[1]);
    if (now.hour == hour && now.minute == minute) {
      final devices = ref.read(devicesProvider);
      final espService = ref.read(httpEspServiceProvider);
      for (var device in devices) {
        if (device.icon.toLowerCase() == 'lamp' && device.isOn) {
          espService.publishRelayCommand(device.relayId, false);
        }
      }
    }
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _tipTimer?.cancel();
    super.dispose();
  }

  void _generateScenarios() async {
    final budget = double.tryParse(_budgetController.text) ?? 500.0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('monthly_budget', budget);

    setState(() {
      _isLoading = true;
      _errorType = null;
      _scenarios = null;
      _tipIndex = 0;
    });

    _tipTimer?.cancel();
    _tipTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (mounted) setState(() => _tipIndex = (_tipIndex + 1) % _tips.length);
    });

    try {
      final devices = ref.read(devicesProvider);
      final currentKwh = ref.read(monthlyKwhProvider).value ?? 0.0;
      final currentCost = ref.read(monthlyCostProvider).value ?? 0.0;

      final scenarios = await AiScenarioService().generateScenarios(
        budgetEGP: budget,
        currentDay: DateTime.now().day,
        currentKwh: currentKwh,
        currentCostEGP: currentCost,
        devices: devices,
      );

      if (mounted) {
        setState(() {
          _scenarios = scenarios;
          _isLoading = false;
        });
      }
    } catch (e) {
      final msg = e.toString();
      String errorType = 'API_ERROR';
      if (msg.contains('NO_API_KEY')) {
        errorType = 'NO_API_KEY';
      } else if (msg.contains('NO_INTERNET') ||
          msg.contains('SocketException') ||
          msg.contains('TimeoutException')) {
        errorType = 'NO_INTERNET';
      } else if (msg.contains('INVALID_JSON')) {
        errorType = 'INVALID_JSON';
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorType = errorType;
        });
      }
    } finally {
      _tipTimer?.cancel();
    }
  }

  /// Parse time slot like "10م - 2ص", "9PM-1AM", "21:00-01:00"
  List<TimeOfDay> _parseTimeSlot(String slot) {
    try {
      // Handle Arabic PM/AM markers: م = PM, ص = AM
      final normalized = slot
          .replaceAll('م', 'PM')
          .replaceAll('ص', 'AM')
          .replaceAll(' ', '');
      final parts = normalized.split('-');
      if (parts.length < 2) {
        return [
          const TimeOfDay(hour: 20, minute: 0),
          const TimeOfDay(hour: 0, minute: 0),
        ];
      }
      return [_parseTime(parts[0].trim()), _parseTime(parts[1].trim())];
    } catch (_) {
      return [
        const TimeOfDay(hour: 20, minute: 0),
        const TimeOfDay(hour: 0, minute: 0),
      ];
    }
  }

  TimeOfDay _parseTime(String raw) {
    final colonIdx = raw.indexOf(':');
    if (colonIdx != -1) {
      final h = int.tryParse(raw.substring(0, colonIdx)) ?? 20;
      final m = int.tryParse(
              raw.substring(colonIdx + 1).replaceAll(RegExp(r'[^0-9]'), '')) ??
          0;
      return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
    }

    final upperRaw = raw.toUpperCase();
    final isPm = upperRaw.contains('PM');
    final isAm = upperRaw.contains('AM');
    final numStr = upperRaw.replaceAll(RegExp(r'[^0-9]'), '');
    int hour = int.tryParse(numStr) ?? 12;

    if (isPm && hour != 12) hour += 12;
    if (isAm && hour == 12) hour = 0;

    return TimeOfDay(hour: hour.clamp(0, 23), minute: 0);
  }

  Future<void> _applyScenario(EnergyScenario scenario) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'تطبيق خطة ${scenario.name}',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'هيتم ضبط جداول كل الأجهزة تلقائياً بناءً على خطة ${scenario.name}. متأكد؟',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('إلغاء', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final db = DatabaseService();
    final allDevices = ref.read(devicesProvider);

    for (final sd in scenario.devices) {
      final device = allDevices.cast<Device?>().firstWhere(
            (d) =>
                d!.name.toLowerCase().contains(sd.deviceName.toLowerCase()) ||
                sd.deviceName.toLowerCase().contains(d.name.toLowerCase()),
            orElse: () => allDevices.isNotEmpty ? allDevices.first : null,
          );

      if (device == null) continue;

      final times = _parseTimeSlot(sd.bestTimeSlot);
      final offHour =
          (times[0].hour + sd.hoursPerDay.toInt()) % 24;
      final schedule = Schedule(
        deviceId: device.id,
        deviceName: device.name,
        onTime: times[0],
        offTime: times.length > 1 && times[1].hour != times[0].hour
            ? times[1]
            : TimeOfDay(hour: offHour, minute: 0),
        repeatDays: List.filled(7, true),
        isEnabled: true,
      );
      try {
        await db.insertSchedule(schedule);
      } catch (_) {
        // Skip if insert fails for this device
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم تطبيق الخطة! روح الجداول تشوف التفاصيل'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      ref.read(navigationIndexProvider.notifier).state = 4;
    }
  }

  void _showBudgetEditDialog() {
    final budget = double.tryParse(_budgetController.text) ?? 500.0;
    final controller = TextEditingController(text: budget.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardColor,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تعديل الميزانية',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'الميزانية الشهرية (جنيه)',
            labelStyle: const TextStyle(color: Colors.white54),
            suffixText: 'جنيه',
            suffixStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء',
                style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () async {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) {
                setState(() => _budgetController.text = val.toStringAsFixed(0));
                final prefs = await SharedPreferences.getInstance();
                await prefs.setDouble('monthly_budget', val);
                ref.read(budgetProvider.notifier).setBudget(val);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حفظ',
                style: TextStyle(color: AppColors.primaryBlue)),
          ),
        ],
      ),
    );
  }

  // ─── Build Helpers ───────────────────────────────────────────────────────────

  Widget _buildBudgetCard(double budget, double spent) {
    final progress = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    final daysInMonth =
        DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day;
    final daysPassed = DateTime.now().day;
    final predicted =
        daysPassed > 0 ? (spent / daysPassed) * daysInMonth : 0.0;

    Color progressColor = AppColors.accentGreen;
    if (progress >= 1.0 || progress >= 0.9) {
      progressColor = AppColors.errorRed;
    } else if (progress >= 0.75) {
      progressColor = Colors.orange;
    }

    String notification = '';
    if (progress >= 1.0) {
      notification = '⚠️ تجاوزت الميزانية بنسبة 100%';
    } else if (progress >= 0.9) {
      notification = '⚠️ وصلت لـ 90% من الميزانية';
    } else if (progress >= 0.75) {
      notification = '⚠️ وصلت لـ 75% من الميزانية';
    } else if (progress >= 0.5) {
      notification = 'وصلت لـ 50% من الميزانية';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: progressColor.withAlpha((0.4 * 255).toInt())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded,
                      color: progressColor, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'تقدم الميزانية',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _showBudgetEditDialog,
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('تعديل'),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF00B4D8)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'أنفقت ${spent.toStringAsFixed(0)} من ${budget.toStringAsFixed(0)} جنيه هذا الشهر',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            'المتوقع نهاية الشهر: ${predicted.toStringAsFixed(0)} جنيه',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          if (notification.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: progressColor.withAlpha((0.15 * 255).toInt()),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                notification,
                style: TextStyle(
                    color: progressColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.2),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            builder: (_, val, child) =>
                Transform.scale(scale: val, child: child),
            child: const Text('🤖', style: TextStyle(fontSize: 64)),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              _tips[_tipIndex],
              key: ValueKey(_tipIndex),
              style:
                  const TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    final String message;
    final IconData icon;
    final Widget actionButton;

    switch (_errorType) {
      case 'NO_API_KEY':
        message = 'أضف Groq API Key في الإعدادات أولاً';
        icon = Icons.key_off_rounded;
        actionButton = ElevatedButton.icon(
          onPressed: () =>
              ref.read(navigationIndexProvider.notifier).state = 5,
          icon: const Icon(Icons.settings),
          label: const Text('الإعدادات'),
        );
        break;
      case 'NO_INTERNET':
        message = 'تحتاج إنترنت لاستخدام الذكاء الاصطناعي';
        icon = Icons.wifi_off_rounded;
        actionButton = ElevatedButton.icon(
          onPressed: _generateScenarios,
          icon: const Icon(Icons.refresh),
          label: const Text('إعادة المحاولة'),
        );
        break;
      default:
        message = 'حصل خطأ، حاول تاني';
        icon = Icons.error_outline_rounded;
        actionButton = ElevatedButton.icon(
          onPressed: _generateScenarios,
          icon: const Icon(Icons.refresh),
          label: const Text('إعادة المحاولة'),
        );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 16, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          actionButton,
        ],
      ),
    );
  }

  Widget _buildScenarioCard(EnergyScenario scenario, bool isFirst, double budget) {
    final progress =
        budget > 0 ? (scenario.predictedMonthlyCost / budget).clamp(0.0, 1.0) : 0.0;

    Color borderColor;
    if (scenario.withinBudget && isFirst) {
      borderColor = Colors.blue;
    } else if (scenario.withinBudget) {
      borderColor = Colors.green;
    } else {
      borderColor = Colors.orange;
    }

    return Card(
      color: AppColors.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor.withAlpha((0.6 * 255).toInt()), width: 1.5),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Text(scenario.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Text(
                  scenario.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  scenario.withinBudget ? '✅' : '⚠️',
                  style: const TextStyle(fontSize: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Description
            Text(
              scenario.description,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const Divider(color: Colors.white12, height: 24),
            // Cost row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'التكلفة المتوقعة',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                Text(
                  '${scenario.predictedMonthlyCost.toStringAsFixed(0)} جنيه/شهر',
                  style: const TextStyle(
                      color: Color(0xFF42A5F5),
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(
                    scenario.withinBudget ? Colors.green : Colors.orange),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(progress * 100).toStringAsFixed(0)}% من ميزانيتك',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            if (scenario.savingsEGP > 0) ...[
              const SizedBox(height: 8),
              Text(
                'توفر ${scenario.savingsEGP.toStringAsFixed(0)} جنيه',
                style: const TextStyle(
                    color: Colors.green,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
            ],
            // Device list
            if (scenario.devices.isNotEmpty) ...[
              const Divider(color: Colors.white12, height: 24),
              const Text(
                'جدول الأجهزة:',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...scenario.devices.map(
                (d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          d.deviceName,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${d.hoursPerDay.toStringAsFixed(1)}س/يوم',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          d.bestTimeSlot,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 11),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${d.monthlyCost.toStringAsFixed(0)}ج',
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                              color: Color(0xFF42A5F5), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            // Tips
            if (scenario.tips.isNotEmpty) ...[
              const Divider(color: Colors.white12, height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡 ', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Text(
                      scenario.tips,
                      style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            // Apply button
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _applyScenario(scenario),
                child: const Text(
                  'طبّق الخطة دي',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(devicesProvider);
    final isAutoMode = ref.watch(energySavingModeProvider);
    final monthlyCostAsync = ref.watch(monthlyCostProvider);
    final spentThisMonth = monthlyCostAsync.value ?? 0.0;
    final budget =
        double.tryParse(_budgetController.text) ?? 500.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('توفير الطاقة الذكي 🍃',
            style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Budget Input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الميزانية الشهرية',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _budgetController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    decoration: InputDecoration(
                      suffixText: 'جنيه',
                      suffixStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      hintText: '500',
                      hintStyle: const TextStyle(color: Colors.white30),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Spending Progress
            _buildBudgetCard(budget, spentThisMonth),
            const SizedBox(height: 16),

            // AI Generate Button
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isLoading ? null : _generateScenarios,
                icon: const Text('✨', style: TextStyle(fontSize: 20)),
                label: const Text(
                  'اقتراح خطط ذكية',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Loading / Error / Scenarios
            if (_isLoading)
              SizedBox(height: 300, child: _buildLoadingState())
            else if (_errorType != null)
              SizedBox(height: 300, child: _buildError())
            else if (_scenarios != null && _scenarios!.isNotEmpty) ...[
              const Text(
                'الخطط المقترحة 💡',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ..._scenarios!.asMap().entries.map(
                    (e) => _buildScenarioCard(e.value, e.key == 0, budget),
                  ),
            ],

            // Smart Mode Toggle
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isAutoMode
                        ? AppColors.accentGreen
                        : Colors.transparent,
                    width: 2),
              ),
              child: SwitchListTile(
                value: isAutoMode,
                onChanged: (val) {
                  ref.read(energySavingModeProvider.notifier).state = val;
                  if (val) {
                    NotificationService().showNotification(
                      id: 4,
                      title: 'Smart Mode Enabled 🌿',
                      body: 'AI will now optimize your energy consumption.',
                    );
                  }
                },
                title: Text(
                  'الوضع الذكي التلقائي 🧠',
                  style: TextStyle(
                    color: isAutoMode
                        ? AppColors.accentGreen
                        : AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'إيقاف الأجهزة غير الأساسية عند 90% من الميزانية.',
                  style: TextStyle(
                      color: Colors.white.withAlpha((0.6 * 255).toInt()),
                      fontSize: 13),
                ),
                activeThumbColor: AppColors.accentGreen,
                activeTrackColor:
                    AppColors.accentGreen.withAlpha((0.2 * 255).toInt()),
                inactiveThumbColor: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),

            // Device Priority
            const Text(
              'أولوية الأجهزة',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...devices.map((device) => DevicePriorityCard(device: device)),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
