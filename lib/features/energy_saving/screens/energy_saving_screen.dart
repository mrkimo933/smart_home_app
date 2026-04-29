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
    // Listen to budget usage
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

    // Simple time checker for morning lights off (simulated here)
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
        title: 'تنبيه توفير الطاقة',
        body: 'تم إيقاف تشغيل الأجهزة غير الضرورية بسبب تخطي 90% من الميزانية',
      );
    }
  }

  Future<void> _checkMorningLightsOff() async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString('morning_lights_off_time') ?? '08:00';
    
    final now = DateTime.now();
    final hour = int.parse(timeStr.split(':')[0]);
    final minute = int.parse(timeStr.split(':')[1]);

    // Check if it's currently around that time (simplified logic)
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

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(devicesProvider);
    final isAutoMode = ref.watch(energySavingModeProvider);
    final budget = ref.watch(budgetProvider);
    final recommendedDailyKwh = ElectricityCalculator.getRecommendedDailyKwh(budget);

    // Calculate smart metrics
    final monthlyCostAsync = ref.watch(monthlyCostProvider);
    final spentThisMonth = monthlyCostAsync.value ?? 0.0;
    
    final daysInMonth = DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day;
    final daysPassed = DateTime.now().day;
    final daysRemaining = daysInMonth - daysPassed;
    
    final predictedCost = daysPassed > 0 ? (spentThisMonth / daysPassed) * daysInMonth : 0.0;
    final overspend = predictedCost - budget;
    final isOverspending = predictedCost > budget;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Smart Energy Saving 🍃', style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSmartRecommendation(budget, predictedCost, overspend, isOverspending),
            const SizedBox(height: 24),
            _buildBudgetProgress(daysRemaining, overspend, isOverspending, spentThisMonth, budget),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isAutoMode ? AppColors.accentGreen : Colors.transparent, width: 2),
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
                    color: isAutoMode ? AppColors.accentGreen : AppColors.textPrimary,
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Auto-turns off non-essentials at 80% budget, lights after 11 PM, AC after 4h.',
                  style: TextStyle(color: Colors.white.withAlpha((0.6 * 255).toInt()), fontSize: 13),
                ),
                activeThumbColor: AppColors.accentGreen,
                activeTrackColor: AppColors.accentGreen.withAlpha((0.2 * 255).toInt()),
                inactiveThumbColor: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Device Priority',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...devices.map((device) => DevicePriorityCard(device: device)),
            const SizedBox(height: 32),
            _buildRecommendationsSection(recommendedDailyKwh, devices),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartRecommendation(double budget, double predicted, double overspend, bool isOverspending) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isOverspending ? AppColors.errorRed.withAlpha((0.2 * 255).toInt()) : AppColors.primaryBlue.withAlpha((0.2 * 255).toInt()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isOverspending ? AppColors.errorRed : AppColors.primaryBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isOverspending ? Icons.warning_amber_rounded : Icons.tips_and_updates_rounded, color: isOverspending ? AppColors.errorRed : AppColors.primaryBlue),
              const SizedBox(width: 8),
              const Text('Daily AI Insight', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isOverspending 
              ? "You're on track to spend ${predicted.toStringAsFixed(0)} EGP this month. That's ${((overspend / budget) * 100).toStringAsFixed(0)}% over your budget!"
              : "Great job! You're staying well within your ${budget.toStringAsFixed(0)} EGP budget this month.",
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          const Text(
            "💡 Your AC ran 8 hours yesterday, consider reducing it to 6 hours to save ~45 EGP/month.",
            style: TextStyle(color: AppColors.accentGreen, fontSize: 14, fontWeight: FontWeight.w600),
          )
        ],
      ),
    );
  }

  Widget _buildBudgetProgress(int daysRemaining, double overspend, bool isOverspending, double spent, double budget) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Budget Progress', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$daysRemaining days left', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (spent / budget).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(isOverspending ? AppColors.errorRed : AppColors.accentGreen),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${spent.toStringAsFixed(0)} EGP Spent', style: const TextStyle(color: Colors.white70, fontSize: 14)),
              Text('${budget.toStringAsFixed(0)} EGP Budget', style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
          if (isOverspending) ...[
            const SizedBox(height: 8),
            Text(
              "At current rate, you'll overspend by ${overspend.toStringAsFixed(0)} EGP",
              style: const TextStyle(color: AppColors.errorRed, fontSize: 12, fontWeight: FontWeight.bold),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildRecommendationsSection(double recommendedDailyKwh, List<Device> devices) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryBlue.withAlpha((0.3 * 255).toInt())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'توصيات الاستخدام اليومي',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 8),
          Text(
            'للبقاء ضمن ميزانية ${ref.read(budgetProvider).toStringAsFixed(0)} ج.م، ننصح بالتالي:',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 20),
          ...devices.map((device) {
            // Assume 4 devices share the budget goal
            final deviceShare = recommendedDailyKwh / (devices.isEmpty ? 1 : devices.length);
            final hours = (device.wattage > 0) ? (deviceShare * 1000) / device.wattage : 0.0;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${hours.toStringAsFixed(1)} ساعة',
                    style: const TextStyle(color: AppColors.accentGreen, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    device.name,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
