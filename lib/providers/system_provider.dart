import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'devices_provider.dart';

// Provider to handle daily reset and other system-level tasks
final systemProvider = Provider<void>((ref) {
  // Schedule a midnight reset
  void scheduleMidnightReset() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final untilMidnight = tomorrow.difference(now);

    Timer(untilMidnight, () async {
      final devicesNotifier = ref.read(devicesProvider.notifier);
      final devices = ref.read(devicesProvider);
      for (final d in devices) {
        final updated = d.copyWith(totalOnMinutesToday: 0);
        await ref.read(databaseServiceProvider).updateDevice(updated);
      }
      // Update in-memory state
      await devicesNotifier.loadDevices();
      // Reschedule next midnight
      scheduleMidnightReset();
    });
  }

  scheduleMidnightReset();

  return;
});
