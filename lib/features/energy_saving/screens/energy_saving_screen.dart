import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/devices_provider.dart';
import '../../../core/utils/electricity_calculator.dart';
import '../../../models/device.dart';
import '../../../providers/consumption_provider.dart';
import '../../../providers/mqtt_provider.dart';
import '../../../services/notification_service.dart';
import '../widgets/device_priority_card.dart';

final energySavingModeProvider = StateProvider<bool>((ref) => false);

class EnergySavingScreen extends ConsumerStatefulWidget {
  const EnergySavingScreen({super.key});

  @override
  ConsumerState<EnergySavingScreen> createState() => _EnergySavingScreenState();
}

class _EnergySavingScreenState extends ConsumerState<EnergySavingScreen> {
  @override
  void initState() {
    super.initState();
    _startAutomationListeners();
  }

  void _startAutomationListeners() {
    ref.listenManual(monthlyCostProvider, (previous, next) {
      final isAutoMode = ref.read(energySavingModeProvider);
      if (!isAutoMode) return;
      final budget = ref.read(budgetProvider);
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
    final mqtt = ref.read(mqttControllerProvider);
    bool acted = false;
    for (var device in devices) {
      if (device.priority == DevicePriority.nonEssential && device.isOn) {
        mqtt.toggleRelay(device.relayId, false);
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
      final mqtt = ref.read(mqttControllerProvider);
      for (var device in devices) {
        if (device.icon.toLowerCase() == 'lamp' && device.isOn) {
          mqtt.toggleRelay(device.relayId, false);
        }
      }
    }
  }

  // ── House Budget card ──────────────────────────────────────────────────────

  void _showBudgetEditDialog() {
    final budget = ref.read(budgetProvider);
    final controller =
        TextEditingController(text: budget.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardColor,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Set House Budget',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Monthly Budget (EGP)',
            labelStyle: const TextStyle(color: Colors.white54),
            suffixText: 'EGP',
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
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) {
                ref.read(budgetProvider.notifier).setBudget(val);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save',
                style: TextStyle(color: AppColors.primaryBlue)),
          ),
        ],
      ),
    );
  }

  Widget _buildHouseBudgetCard(double budget, double spent) {
    final progress = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    final daysInMonth =
        DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day;
    final daysPassed = DateTime.now().day;
    final predicted =
        daysPassed > 0 ? (spent / daysPassed) * daysInMonth : 0.0;

    Color progressColor = AppColors.accentGreen;
    if (progress >= 1.0) {
      progressColor = AppColors.errorRed;
    } else if (progress >= 0.9) {
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
        border: Border.all(color: progressColor.withAlpha((0.4 * 255).toInt())),
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
                    'Budget Progress',
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
                label: const Text('Edit'),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${spent.toStringAsFixed(0)} EGP Spent',
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
              Text('${budget.toStringAsFixed(0)} EGP Budget',
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Predicted end of month: ${predicted.toStringAsFixed(0)} EGP",
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          if (notification.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: progressColor.withAlpha((0.15 * 255).toInt()),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      notification,
                      style: TextStyle(
                          color: progressColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(devicesProvider);
    final isAutoMode = ref.watch(energySavingModeProvider);
    final budget = ref.watch(budgetProvider);
    final monthlyCostAsync = ref.watch(monthlyCostProvider);
    final spentThisMonth = monthlyCostAsync.value ?? 0.0;
    final daysInMonth =
        DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day;
    final daysPassed = DateTime.now().day;
    final predictedCost =
        daysPassed > 0 ? (spentThisMonth / daysPassed) * daysInMonth : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Smart Energy Saving 🍃',
            style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Feature 2: House Budget card at the top
            _buildHouseBudgetCard(budget, spentThisMonth),
            const SizedBox(height: 24),
            _buildScenarios(budget, predictedCost, devices),
            const SizedBox(height: 24),
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
                  'Smart AI Mode 🧠',
                  style: TextStyle(
                    color: isAutoMode
                        ? AppColors.accentGreen
                        : AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Auto-turns off non-essentials at 80% budget, lights after 11 PM, AC after 4h.',
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
            const Text(
              'Device Priority',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...devices.map((device) => DevicePriorityCard(device: device)),
            const SizedBox(height: 32),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarios(
      double budget, double predictedCost, List<Device> devices) {
    // 1. Max Saving
    double maxSavingCost = 0;
    Map<Device, double> maxSavingHours = {};
    for (var d in devices) {
      double h = d.priority == DevicePriority.essential
          ? 24
          : (d.priority == DevicePriority.normal ? 2 : 0);
      maxSavingHours[d] = h;
      maxSavingCost += (d.wattage / 1000) * h * 30;
    }
    maxSavingCost = ElectricityCalculator.calculateCost(maxSavingCost);

    // 2. Balanced
    double balancedCost = 0;
    Map<Device, double> balancedHours = {};
    for (var d in devices) {
      double h = d.priority == DevicePriority.essential
          ? 24
          : (d.priority == DevicePriority.normal ? 6 : 2);
      balancedHours[d] = h;
      balancedCost += (d.wattage / 1000) * h * 30;
    }
    balancedCost = ElectricityCalculator.calculateCost(balancedCost);

    // 3. Comfort
    double comfortCost = 0;
    Map<Device, double> comfortHours = {};
    for (var d in devices) {
      double h = d.priority == DevicePriority.essential
          ? 24
          : (d.priority == DevicePriority.normal ? 12 : 6);
      comfortHours[d] = h;
      comfortCost += (d.wattage / 1000) * h * 30;
    }
    comfortCost = ElectricityCalculator.calculateCost(comfortCost);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Smart Budget Scenarios 💡',
          style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildScenarioCard(
          title: 'توفير أقصى',
          emoji: '📉',
          scenarioCost: maxSavingCost,
          budget: budget,
          predictedCost: predictedCost,
          deviceHours: maxSavingHours,
        ),
        _buildScenarioCard(
          title: 'توازن',
          emoji: '⚖️',
          scenarioCost: balancedCost,
          budget: budget,
          predictedCost: predictedCost,
          deviceHours: balancedHours,
        ),
        _buildScenarioCard(
          title: 'راحة',
          emoji: '🛋️',
          scenarioCost: comfortCost,
          budget: budget,
          predictedCost: predictedCost,
          deviceHours: comfortHours,
        ),
      ],
    );
  }

  Widget _buildScenarioCard({
    required String title,
    required String emoji,
    required double scenarioCost,
    required double budget,
    required double predictedCost,
    required Map<Device, double> deviceHours,
  }) {
    final savings = predictedCost - scenarioCost;
    final isOverBudget = scenarioCost > budget;
    final overBudgetAmount = scenarioCost - budget;

    String comparisonText = '';
    if (title == 'توفير أقصى' || title == 'توازن') {
      if (savings > 0) {
        comparisonText =
            'هتوفر ${savings.toStringAsFixed(0)} جنيه مقارنة باستهلاكك الحالي';
      } else {
        comparisonText = 'استهلاكك الحالي ممتاز ولن يوفر هذا السيناريو الكثير';
      }
    } else {
      if (isOverBudget) {
        comparisonText =
            'هتعدي الـ budget بـ ${overBudgetAmount.toStringAsFixed(0)} جنيه';
      } else {
        comparisonText = 'في حدود الـ budget';
      }
    }

    return Card(
      color: AppColors.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${scenarioCost.toStringAsFixed(0)} ج.م',
                    style: TextStyle(
                        color: isOverBudget && title == 'راحة'
                            ? AppColors.errorRed
                            : AppColors.accentGreen,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(comparisonText,
                style: const TextStyle(
                    color: Colors.orangeAccent, fontSize: 14)),
            const SizedBox(height: 16),
            ...deviceHours.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key.name,
                          style: const TextStyle(color: Colors.white70)),
                      Text('${e.value.toStringAsFixed(0)} ساعة/يوم',
                          style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                )),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                for (var entry in deviceHours.entries) {
                  final minutes = (entry.value * 60).toInt();
                  if (minutes > 0) {
                    ref
                        .read(mqttControllerProvider)
                        .toggleRelay(entry.key.relayId, true);
                    ref
                        .read(devicesProvider.notifier)
                        .setDeviceTimer(entry.key.id, minutes);
                  } else {
                    ref
                        .read(mqttControllerProvider)
                        .toggleRelay(entry.key.relayId, false);
                    ref
                        .read(devicesProvider.notifier)
                        .toggleDevice(entry.key.relayId, false);
                  }
                }
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('تم تطبيق السيناريو! الجداول اتضبطت تلقائياً'),
                  backgroundColor: AppColors.accentGreen,
                ));
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B4D8)),
              child: const Text('طبّق السيناريو ده',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}
