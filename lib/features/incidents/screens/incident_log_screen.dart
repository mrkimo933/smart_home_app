// lib/features/incidents/screens/incident_log_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
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
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, size: 64, color: AppColors.accentGreen),
                    SizedBox(height: 16),
                    Text(
                      'No overcurrent incidents recorded',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
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

                  return Card(
                    color: AppColors.cardColor,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: AppColors.errorRed.withAlpha((0.3 * 255).toInt()),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.errorRed.withAlpha((0.15 * 255).toInt()),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.electric_bolt, color: AppColors.errorRed, size: 24),
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
