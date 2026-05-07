import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:intl/intl.dart';
import 'devices_provider.dart';
import 'esp_provider.dart';
// import 'consumption_provider.dart';
import '../services/notification_service.dart';
// import '../core/utils/electricity_calculator.dart';
import '../features/energy_saving/screens/energy_saving_screen.dart';
import '../models/device.dart';
import '../models/energy_scenario.dart';

// Provider to handle daily reset and other system-level tasks
final systemProvider = Provider<void>((ref) {
  // Timer? smartCheckTimer;

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
      scheduleMidnightReset();
    });
  }

  Timer? smartCheckTimer;

  void startSmartChecks() {
    smartCheckTimer = Timer.periodic(const Duration(minutes: 15), (timer) async {
      final now = DateTime.now();
      final devices = ref.read(devicesProvider);
      final mqtt = ref.read(mqttControllerProvider);
      final isAutoMode = ref.read(energySavingModeProvider);

      if (isAutoMode) {
        // Night logic: 11 PM logic: turn off all non-essential
        if (now.hour >= 23 || now.hour < 6) {
          for (final device in devices) {
            if (device.isOn && (device.priority == DevicePriority.nonEssential || device.icon == 'lamp' || device.icon == 'tv')) {
              mqtt.publishRelayCommand(device.relayId, false);
            }
          }
        }
        
        // Ensure High-power devices (AC, Water Heater) don't run > 4 hours straight in Auto Mode
        for (final device in devices) {
          final isHighPower = device.icon.toLowerCase().contains("ac") || device.icon.toLowerCase().contains("heater");
          if (isHighPower && device.isOn && device.totalOnMinutesToday > 240) {
            mqtt.publishRelayCommand(device.relayId, false);
            NotificationService().showNotification(
              id: 9,
              title: 'Auto Saving 🌿',
              body: 'Turned off ${device.name} to save energy after 4 continuous hours.',
            );
          }
        }

        // Eco-mode: If total power is very high (> 5000W), turn off some non-essentials
        final totalActivePower = devices.where((d) => d.isOn).fold(0.0, (sum, d) => sum + d.wattage);
        if (totalActivePower > 5000) {
           for (final device in devices) {
             if (device.isOn && device.priority == DevicePriority.nonEssential) {
               mqtt.publishRelayCommand(device.relayId, false);
               NotificationService().showNotification(
                  id: 10,
                  title: 'Load Balancing ⚡',
                  body: 'Power usage exceeded 5000W. Temporarily disabled ${device.name}.',
                );
                break; // Only turn off one at a time
             }
           }
        }
      }

      // Smart notifications logic
      if (now.hour == 8) {
        NotificationService().showSmartNotification(
          id: 2,
          type: "morning_tip",
          title: "💡 Smart Energy Tip",
          body: "Running your AC at 26°C instead of 22°C saves ~30% energy!",
        );
      } else if (now.hour == 21) {
        final cost = await ref.read(databaseServiceProvider).getTotalCostThisMonth();
        NotificationService().showSmartNotification(
          id: 3,
          type: "night_summary",
          title: "🌔 Daily Energy Summary",
          body: "You've spent ~${cost.toStringAsFixed(1)} EGP so far this month. Keep it up!",
        );
      }
    });
  }

  scheduleMidnightReset();
  startSmartChecks();

  ref.onDispose(() {
    smartCheckTimer?.cancel();
  });

  return;
});

final activeScenarioProvider = StateProvider<EnergyScenario?>((ref) => null);

/// Relay IDs (1-based) that were tripped by the short-circuit protection.
/// A device in this set cannot be turned ON until the user explicitly
/// acknowledges the warning and clears the lock.
final protectedRelaysProvider = StateProvider<Set<int>>((ref) => {});
