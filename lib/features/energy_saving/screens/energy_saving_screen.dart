import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/electricity_calculator.dart';
import '../../../models/device.dart';
import '../../../providers/consumption_provider.dart';
import '../../../providers/devices_provider.dart';
import '../../../providers/mqtt_provider.dart';
import '../../../services/notification_service.dart';
import '../widgets/budget_input_card.dart';
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('توفير الطاقة', style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BudgetInputCard(),
            const SizedBox(height: 24),
            SwitchListTile(
              value: isAutoMode,
              onChanged: (val) => ref.read(energySavingModeProvider.notifier).state = val,
              title: const Text(
                'وضع التوفير التلقائي',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.right,
              ),
              subtitle: const Text(
                'سيقوم النظام بإطفاء الأجهزة غير الضرورية عند وصول الاستهلاك لـ 90%',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                textAlign: TextAlign.right,
              ),
              activeThumbColor: AppColors.primaryBlue,
            ),
            const SizedBox(height: 24),
            const Text(
              'أولويات الأجهزة',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
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
