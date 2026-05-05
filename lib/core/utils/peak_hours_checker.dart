// lib/core/utils/peak_hours_checker.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PeakStatus { none, afternoonPeak, eveningPeak }

class PeakHoursChecker {
  /// Returns the current peak status based on current time and month.
  static PeakStatus currentStatus() {
    final now = DateTime.now();
    final month = now.month;
    final hour = now.hour;

    final isSummer = month >= 6 && month <= 9;

    if (isSummer) {
      // Afternoon peak 12:00 – 16:00
      if (hour >= 12 && hour < 16) return PeakStatus.afternoonPeak;
      // Evening peak 19:00 – 22:00
      if (hour >= 19 && hour < 22) return PeakStatus.eveningPeak;
    } else {
      // Winter evening peak 17:00 – 21:00
      if (hour >= 17 && hour < 21) return PeakStatus.eveningPeak;
    }
    return PeakStatus.none;
  }

  /// Human-readable end time string for current peak (Arabic).
  static String peakEndTimeAr() {
    final now = DateTime.now();
    final month = now.month;
    final hour = now.hour;
    final isSummer = month >= 6 && month <= 9;

    if (isSummer) {
      if (hour >= 12 && hour < 16) return 'ينتهي الساعة 4 العصر';
      if (hour >= 19 && hour < 22) return 'ينتهي الساعة 10 مساءً';
    } else {
      if (hour >= 17 && hour < 21) return 'ينتهي الساعة 9 مساءً';
    }
    return '';
  }

  static bool get isInPeak => currentStatus() != PeakStatus.none;
}

/// A provider that re-evaluates every minute.
final peakStatusProvider = StreamProvider<PeakStatus>((ref) async* {
  // Emit immediately
  yield PeakHoursChecker.currentStatus();

  // Then re-emit every 60 seconds
  await for (final _ in Stream.periodic(const Duration(minutes: 1))) {
    yield PeakHoursChecker.currentStatus();
  }
});
