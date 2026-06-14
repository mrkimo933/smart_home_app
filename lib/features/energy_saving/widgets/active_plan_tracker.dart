import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/modern_card.dart';
import '../../../providers/system_provider.dart';
import '../../../providers/devices_provider.dart';
import '../../../providers/consumption_provider.dart';

class ActivePlanTracker extends ConsumerWidget {
  const ActivePlanTracker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenario = ref.watch(activeScenarioProvider);
    if (scenario == null) return const SizedBox.shrink();

    final devices = ref.watch(devicesProvider);
    final actualSpend = ref.watch(monthlyCostProvider).value ?? 0.0;

    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysRemaining = daysInMonth - now.day;
    final dailyAllowance = scenario.predictedMonthlyCost / daysInMonth;

    // Estimate today's spend based on monthly total divided by days elapsed
    final todayEstimate = now.day > 0 ? actualSpend / now.day : 0.0;
    final statusMsg = todayEstimate <= dailyAllowance
        ? 'أنت في المسار الصح! 🎯'
        : 'تجاوزت الميزانية اليومية بـ ${(todayEstimate - dailyAllowance).toStringAsFixed(1)} جنيه ⚠️';
    final statusColor = todayEstimate <= dailyAllowance
        ? const Color(0xFF00F5A0)
        : Colors.orange;

    return ModernCard(
      borderRadius: 24,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      backgroundColor: AppColors.cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accentOrange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(scenario.emoji, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scenario.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.4)),
                      ),
                      child: const Text(
                        'الخطة النشطة',
                        style: TextStyle(color: AppColors.primaryBlue, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

            // Budget ring + stats row
            Row(
              children: [
                // Circular progress
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: (actualSpend / scenario.predictedMonthlyCost).clamp(0.0, 1.0),
                        strokeWidth: 8,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _progressColor(actualSpend, scenario.predictedMonthlyCost),
                        ),
                      ),
                      Text(
                        '${((actualSpend / scenario.predictedMonthlyCost) * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${scenario.predictedMonthlyCost.toStringAsFixed(0)} جنيه/شهر',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'باقي $daysRemaining يوم',
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'المسموح اليومي: ${dailyAllowance.toStringAsFixed(1)} جنيه',
                        style: const TextStyle(
                            color: Color(0xFF00B4D8), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (scenario.devices.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(color: Colors.white12),
              const SizedBox(height: 8),
              const Text(
                'حالة الأجهزة:',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...scenario.devices.map((sd) {
                // Find matching device to get actualOnMinutesToday
                final matchingDevice = devices
                    .where((d) =>
                        d.name
                            .toLowerCase()
                            .contains(sd.deviceName.toLowerCase()) ||
                        sd.deviceName
                            .toLowerCase()
                            .contains(d.name.toLowerCase()))
                    .firstOrNull;

                final actualHours =
                    (matchingDevice?.totalOnMinutesToday ?? 0) / 60.0;
                final plannedHours = sd.hoursPerDay;
                final ratio =
                    plannedHours > 0 ? actualHours / plannedHours : 0.0;

                Color statusColor;
                IconData statusIcon;
                if (ratio <= 1.0) {
                  statusColor = const Color(0xFF00F5A0);
                  statusIcon = Icons.check_circle_rounded;
                } else if (ratio <= 1.3) {
                  statusColor = Colors.orange;
                  statusIcon = Icons.warning_amber_rounded;
                } else {
                  statusColor = const Color(0xFFFF4B4B);
                  statusIcon = Icons.error_rounded;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.electrical_services_rounded,
                          color: Colors.white38, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          sd.deviceName,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${plannedHours.toStringAsFixed(1)}س مخطط',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${actualHours.toStringAsFixed(1)}س فعلي',
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      Icon(statusIcon, color: statusColor, size: 14),
                    ],
                  ),
                );
              }),
            ],

            const SizedBox(height: 12),
            const Divider(color: Colors.white12),
            const SizedBox(height: 8),

            // Status message
            Text(
              statusMsg,
              style: TextStyle(
                  color: statusColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Cancel button
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () =>
                    ref.read(activeScenarioProvider.notifier).state = null,
                icon: const Icon(Icons.cancel_outlined,
                    color: Colors.red, size: 16),
                label: const Text('إلغاء الخطة',
                    style: TextStyle(color: Colors.red, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _progressColor(double actual, double planned) {
    final ratio = planned > 0 ? actual / planned : 0.0;
    if (ratio <= 0.8) return AppColors.accentTeal;
    if (ratio <= 1.0) return AppColors.accentOrange;
    return AppColors.errorRed;
  }
}
