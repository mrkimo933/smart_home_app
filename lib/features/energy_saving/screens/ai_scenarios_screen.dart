import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/device.dart';
import '../../../models/energy_scenario.dart';
import '../../../models/schedule.dart';
import '../../../services/ai_scenario_service.dart';
import '../../../services/database_service.dart';
import '../../settings/screens/settings_screen.dart';

class AiScenariosScreen extends StatefulWidget {
  final double budgetEGP;
  final int currentDay;
  final double currentKwh;
  final List<Device> devices;

  const AiScenariosScreen({
    super.key,
    required this.budgetEGP,
    required this.currentDay,
    required this.currentKwh,
    required this.devices,
  });

  @override
  State<AiScenariosScreen> createState() => _AiScenariosScreenState();
}

class _AiScenariosScreenState extends State<AiScenariosScreen> {
  List<EnergyScenario>? _scenarios;
  bool _isLoading = true;
  String? _errorMessage;
  String? _errorType;

  @override
  void initState() {
    super.initState();
    _loadScenarios();
  }

  Future<void> _loadScenarios() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _errorType = null;
      _scenarios = null;
    });

    try {
      final scenarios = await AiScenarioService().generateScenarios(
        budgetEGP: widget.budgetEGP,
        currentDay: widget.currentDay,
        currentKwh: widget.currentKwh,
        devices: widget.devices,
      );
      if (mounted) {
        setState(() {
          _scenarios = scenarios;
          _isLoading = false;
        });
      }
    } on Exception catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      String displayMsg;
      String errorType = 'generic';

      if (msg.contains('NO_API_KEY')) {
        displayMsg = 'أضف Groq API Key في الإعدادات أولاً';
        errorType = 'NO_API_KEY';
      } else if (msg.contains('NO_INTERNET') || msg.contains('TimeoutException')) {
        displayMsg = 'تأكد من الاتصال بالإنترنت';
        errorType = 'NO_INTERNET';
      } else if (msg.contains('API_ERROR_')) {
        displayMsg = 'خطأ في الاتصال بالخدمة. حاول مرة أخرى.';
        errorType = 'API_ERROR';
      } else if (msg.contains('INVALID_JSON')) {
        displayMsg = 'حصل خطأ في معالجة الرد، حاول تاني';
        errorType = 'INVALID_JSON';
      } else {
        displayMsg = 'حصل خطأ غير متوقع. حاول مرة أخرى.';
        errorType = 'generic';
      }

      setState(() {
        _isLoading = false;
        _errorMessage = displayMsg;
        _errorType = errorType;
      });
    }
  }

  /// Parse a time slot string like "9PM-1AM" or "21:00-01:00" into onTime/offTime.
  /// Returns [onTime, offTime]. Falls back to 20:00-00:00 on parse failure.
  List<TimeOfDay> _parseTimeSlot(String slot) {
    try {
      final parts = slot.split('-');
      if (parts.length != 2) return [const TimeOfDay(hour: 20, minute: 0), const TimeOfDay(hour: 0, minute: 0)];
      return [_parseTime(parts[0].trim()), _parseTime(parts[1].trim())];
    } catch (_) {
      return [const TimeOfDay(hour: 20, minute: 0), const TimeOfDay(hour: 0, minute: 0)];
    }
  }

  TimeOfDay _parseTime(String raw) {
    // Try HH:mm format first
    final colonIdx = raw.indexOf(':');
    if (colonIdx != -1) {
      final h = int.tryParse(raw.substring(0, colonIdx)) ?? 20;
      final m = int.tryParse(raw.substring(colonIdx + 1).replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
    }

    // Try 12h format: 9PM, 1AM, 10AM, etc.
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
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'تطبيق سيناريو ${scenario.name}؟',
          style: const TextStyle(color: Colors.white),
        ),
        content: const Text(
          'هيتم إنشاء جداول تلقائية للأجهزة بناءً على هذا السيناريو.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تطبيق', style: TextStyle(color: AppColors.primaryBlue)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final dbService = DatabaseService();
    int created = 0;

    for (final sd in scenario.devices) {
      // Try to match device by name (case-insensitive partial match)
      final matchedDevice = widget.devices.cast<Device?>().firstWhere(
            (d) =>
                d!.name.toLowerCase().contains(sd.deviceName.toLowerCase()) ||
                sd.deviceName.toLowerCase().contains(d.name.toLowerCase()),
            orElse: () => null,
          );

      if (matchedDevice == null) continue;

      final times = _parseTimeSlot(sd.timeSlot);
      final schedule = Schedule(
        deviceId: matchedDevice.id,
        deviceName: matchedDevice.name,
        onTime: times[0],
        offTime: times[1],
        repeatDays: List.filled(7, true),
        isEnabled: true,
      );

      try {
        await dbService.insertSchedule(schedule);
        created++;
      } catch (_) {
        // Skip if DB insert fails
      }
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          created > 0
              ? '✅ تم تطبيق السيناريو! الجداول اتضبطت ($created جداول)'
              : '✅ تم تطبيق السيناريو!',
        ),
        backgroundColor: AppColors.accentGreen,
      ),
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'اقتراحات الذكاء الاصطناعي ✨',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primaryBlue),
            const SizedBox(height: 24),
            const Text(
              'الذكاء الاصطناعي بيحلل استهلاكك...',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'بيجهز ليك أفضل 3 سيناريوهات توفير',
              style: TextStyle(
                color: Colors.white.withAlpha((0.6 * 255).toInt()),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.errorRed, size: 64),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              if (_errorType == 'NO_API_KEY') ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('اذهب للإعدادات'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: _loadScenarios,
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final scenarios = _scenarios ?? [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'استناداً لميزانيتك ${widget.budgetEGP.toStringAsFixed(0)} ج.م واستهلاك ${widget.currentKwh.toStringAsFixed(1)} kWh',
          style: TextStyle(
            color: Colors.white.withAlpha((0.6 * 255).toInt()),
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ...scenarios.map((s) => _buildScenarioCard(s)),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildScenarioCard(EnergyScenario scenario) {
    return Card(
      color: AppColors.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Text(scenario.emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    scenario.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              scenario.description,
              style: TextStyle(
                color: Colors.white.withAlpha((0.75 * 255).toInt()),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),

            // Cost & Savings row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'التكلفة المتوقعة',
                        style: TextStyle(
                          color: Colors.white.withAlpha((0.5 * 255).toInt()),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${scenario.predictedCost.toStringAsFixed(0)} ج.م',
                        style: const TextStyle(
                          color: Color(0xFF42A5F5),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (scenario.savingsEGP > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withAlpha((0.15 * 255).toInt()),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.accentGreen.withAlpha((0.4 * 255).toInt())),
                    ),
                    child: Text(
                      'توفر ${scenario.savingsEGP.toStringAsFixed(0)} ج.م',
                      style: const TextStyle(
                        color: AppColors.accentGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),

            // Device table
            if (scenario.devices.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(color: Colors.white12),
              const SizedBox(height: 8),
              // Table header
              const Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text('الجهاز',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('ساعات/يوم',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('الوقت',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...scenario.devices.map(
                (d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          d.deviceName,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          d.hoursPerDay.toStringAsFixed(1),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          d.timeSlot,
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Apply button
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _applyScenario(scenario),
                child: const Text(
                  'طبّق السيناريو ده',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
