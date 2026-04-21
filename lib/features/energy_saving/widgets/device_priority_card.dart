import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/electricity_calculator.dart';
import '../../../models/device.dart';
import '../../../providers/consumption_provider.dart';
import '../../../providers/devices_provider.dart';

class DevicePriorityCard extends ConsumerWidget {
  final Device device;

  const DevicePriorityCard({super.key, required this.device});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = ref.watch(budgetProvider);
    final recommendedDailyKwh = ElectricityCalculator.getRecommendedDailyKwh(budget);
    
    // We assume an even distribution for recommendation as a baseline
    final deviceShare = recommendedDailyKwh / 4; // Assuming 4 devices
    final recommendedHours = (deviceShare * 1000) / device.wattage;

    return Card(
      color: AppColors.cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                _buildPriorityBadge(device.priority),
                const Spacer(),
                Text(
                  device.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(_getIconData(device.icon), color: AppColors.primaryBlue),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPrioritySelector(context, ref),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'الاستخدام الموصى به',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    Text(
                      '${recommendedHours.toStringAsFixed(1)} ساعة/يوم',
                      style: const TextStyle(color: AppColors.accentGreen, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'الاستخدام اليومي الحالي',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (device.totalOnMinutesToday / 60) / recommendedHours.clamp(0.1, 24.0),
                    backgroundColor: AppColors.background,
                    color: AppColors.primaryBlue,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(DevicePriority priority) {
    Color color;
    String label;
    switch (priority) {
      case DevicePriority.essential:
        color = AppColors.accentGreen;
        label = 'أساسي';
        break;
      case DevicePriority.normal:
        color = AppColors.primaryBlue;
        label = 'عادي';
        break;
      case DevicePriority.nonEssential:
        color = Colors.orange;
        label = 'ثانوي';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPrioritySelector(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<DevicePriority>(
      initialValue: device.priority,
      onSelected: (priority) {
        ref.read(devicesProvider.notifier).updateDeviceDetails(
          device.copyWith(priority: priority),
        );
      },
      child: Row(
        children: [
          const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
          const Text(
            'تغيير الأولوية',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(value: DevicePriority.essential, child: Text('أساسي')),
        const PopupMenuItem(value: DevicePriority.normal, child: Text('عادي')),
        const PopupMenuItem(value: DevicePriority.nonEssential, child: Text('ثانوي')),
      ],
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'lamp': return Icons.lightbulb_outline;
      case 'ac': return Icons.ac_unit;
      case 'tv': return Icons.tv;
      case 'fan': return Icons.air;
      default: return Icons.device_unknown;
    }
  }
}
