import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/modern_card.dart';
import '../../../models/schedule.dart';

class ScheduleCard extends StatelessWidget {
  final Schedule schedule;
  final Function(bool) onToggle;
  final VoidCallback onDelete;

  const ScheduleCard({
    super.key,
    required this.schedule,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
                  color: AppColors.primaryBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getIconData(schedule.deviceName),
                  color: AppColors.primaryBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule.deviceName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_formatTime(schedule.onTime)} → ${_formatTime(schedule.offTime)}',
                        style: TextStyle(
                          color: AppColors.primaryBlue.withOpacity(0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: schedule.isEnabled,
                onChanged: onToggle,
                activeColor: AppColors.primaryBlue,
                activeThumbImage: null,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.errorRed, size: 22),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                final days = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح']; // Mon-Sun Arabic initials
                final isSelected = schedule.repeatDays[index];
                return Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryBlue.withOpacity(0.2) : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primaryBlue.withOpacity(0.5) : Colors.white.withOpacity(0.1),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      days[index],
                      style: TextStyle(
                        color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  IconData _getIconData(String deviceName) {
    final name = deviceName.toLowerCase();
    if (name.contains('lamp') || name.contains('لمبة')) return Icons.lightbulb_outline;
    if (name.contains('ac') || name.contains('تكييف')) return Icons.ac_unit;
    if (name.contains('tv') || name.contains('تلفاز')) return Icons.tv;
    if (name.contains('fan') || name.contains('مروحة')) return Icons.air;
    return Icons.settings_remote;
  }
}
