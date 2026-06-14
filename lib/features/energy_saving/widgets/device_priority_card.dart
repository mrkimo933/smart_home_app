import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/modern_card.dart';
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
    final devices = ref.watch(devicesProvider);

    // Distribute evenly across all devices (at least 1 to avoid division by zero)
    final deviceCount = devices.isEmpty ? 1 : devices.length;
    final deviceShare = recommendedDailyKwh / deviceCount;
    final recommendedHours = (deviceShare * 1000) / device.wattage;

    return ModernCard(
      borderRadius: 20,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      backgroundColor: AppColors.cardColor,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getPriorityColor(device.priority).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getIconData(device.icon), color: _getPriorityColor(device.priority), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildPriorityBadge(device.priority),
                  ],
                ),
              ),
              _buildPrioritySelector(context, ref),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accentTeal.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'الاستخدام الموصى به',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${recommendedHours.toStringAsFixed(1)} س/يوم',
                      style: const TextStyle(color: AppColors.accentTeal, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'الاستخدام اليومي الحالي',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${((device.totalOnMinutesToday / 60) / recommendedHours.clamp(0.1, 24.0) * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (device.totalOnMinutesToday / 60) / recommendedHours.clamp(0.1, 24.0),
                  backgroundColor: Colors.white.withOpacity(0.08),
                  minHeight: 8,
                  valueColor: AlwaysStoppedAnimation<Color>(_getPriorityColor(device.priority)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(DevicePriority priority) {
    switch (priority) {
      case DevicePriority.essential:
        return AppColors.accentTeal;
      case DevicePriority.normal:
        return AppColors.primaryBlue;
      case DevicePriority.nonEssential:
        return AppColors.accentOrange;
    }
  }

  Widget _buildPriorityBadge(DevicePriority priority) {
    final color = _getPriorityColor(priority);
    String label;
    switch (priority) {
      case DevicePriority.essential:
        label = 'أساسي';
        break;
      case DevicePriority.normal:
        label = 'عادي';
        break;
      case DevicePriority.nonEssential:
        label = 'ثانوي';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildPrioritySelector(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<DevicePriority>(
      initialValue: device.priority,
      onSelected: (priority) {
        ref.read(devicesProvider.notifier).updateDevice(
          device.copyWith(priority: priority),
        );
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.cardColor,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 18),
      ),
      itemBuilder: (context) => const [
        PopupMenuItem(value: DevicePriority.essential, child: Text('أساسي')),
        PopupMenuItem(value: DevicePriority.normal, child: Text('عادي')),
        PopupMenuItem(value: DevicePriority.nonEssential, child: Text('ثانوي')),
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
