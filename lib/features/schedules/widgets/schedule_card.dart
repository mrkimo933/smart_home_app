import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
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
                Icon(_getIconData(schedule.deviceName), color: AppColors.primaryBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schedule.deviceName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_formatTime(schedule.onTime)} → ${_formatTime(schedule.offTime)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: schedule.isEnabled,
                  onChanged: onToggle,
                  activeThumbColor: AppColors.primaryBlue,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.errorRed),
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                final days = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح']; // Mon-Sun Arabic initials
                final isSelected = schedule.repeatDays[index];
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryBlue.withAlpha((0.2 * 255).toInt()) : Colors.transparent,
                    shape: BoxShape.circle,
                    border: isSelected ? Border.all(color: AppColors.primaryBlue, width: 1) : null,
                  ),
                  child: Text(
                    days[index],
                    style: TextStyle(
                      color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
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
