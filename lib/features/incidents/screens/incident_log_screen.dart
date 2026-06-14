// lib/features/incidents/screens/incident_log_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/modern_card.dart';
import '../../../providers/devices_provider.dart';

final incidentLogProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await ref.watch(databaseServiceProvider).getOvercurrentIncidents();
});

class IncidentLogScreen extends ConsumerWidget {
  const IncidentLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidentsAsync = ref.watch(incidentLogProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Incident Log',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: incidentsAsync.when(
        data: (incidents) => incidents.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.successGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(Icons.check_circle_outline, size: 64, color: AppColors.successGreen),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No overcurrent incidents',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your system is operating normally',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: incidents.length,
                itemBuilder: (context, index) {
                  final incident = incidents[index];
                  final timestamp = incident['timestamp'] as String? ?? '';
                  final deviceName = incident['device_name'] as String? ?? 'Unknown';
                  final current = (incident['current'] as num?)?.toDouble() ?? 0.0;
                  final maxCurrent = (incident['max_current'] as num?)?.toDouble() ?? 0.0;

                  DateTime? parsedTime;
                  try {
                    parsedTime = DateTime.parse(timestamp);
                  } catch (_) {}

                  return ModernCard(
                    borderRadius: 18,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    backgroundColor: AppColors.cardColor,
                    border: Border.all(
                      color: AppColors.errorRed.withOpacity(0.25),
                      width: 1.5,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.errorRed.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.electric_bolt, color: AppColors.errorRed, size: 22),
                        ),
                        const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  deviceName,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Current: ${current.toStringAsFixed(2)} A  |  Limit: ${maxCurrent.toStringAsFixed(1)} A',
                                  style: const TextStyle(
                                    color: AppColors.errorRed,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  parsedTime != null
                                      ? '${parsedTime.day}/${parsedTime.month}/${parsedTime.year}  ${parsedTime.hour.toString().padLeft(2, '0')}:${parsedTime.minute.toString().padLeft(2, '0')}'
                                      : timestamp,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.errorRed))),
      ),
    );
  }
}
