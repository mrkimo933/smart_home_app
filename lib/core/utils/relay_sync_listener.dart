// lib/core/utils/relay_sync_listener.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/devices_provider.dart';
import '../../providers/mqtt_provider.dart';
import '../../services/notification_service.dart';

final relaySyncListenerProvider = Provider<void>((ref) {
  final notificationService = NotificationService();
  final deviceOnTimers = <int, DateTime>{};

  ref.listen<AsyncValue<Map<int, bool>>>(relayStatesProvider, (previous, next) {
    next.whenData((relayMap) {
      final devices = ref.read(devicesProvider);
      final devicesNotifier = ref.read(devicesProvider.notifier);

      for (var entry in relayMap.entries) {
        final relayId = entry.key;
        final isOn = entry.value;

        try {
          final device = devices.firstWhere((d) => d.relayId == relayId);

          if (device.isOn != isOn) {
            devicesNotifier.toggleDevice(device.id, isOn);
            
            if (isOn) {
              deviceOnTimers[device.id] = DateTime.now();
            } else {
              deviceOnTimers.remove(device.id);
            }
          }
        } catch (_) {
          // Device with relayId not found
        }
      }
    });
  });

  // Watch connection status for power cut detection
  ref.listen<AsyncValue<bool>>(connectionStatusProvider, (previous, next) {
    next.whenData((isConnected) {
      if (previous?.value == true && isConnected == false) {
        notificationService.showNotification(
          id: 999,
          title: 'Connection Lost',
          body: 'System disconnected. Possible power cut or network issue.',
        );
      }
    });
  });

  // Check for long-running devices every 15 minutes
  Timer.periodic(const Duration(minutes: 15), (_) {
    final now = DateTime.now();
    deviceOnTimers.forEach((deviceId, startTime) {
      final duration = now.difference(startTime);
      if (duration.inHours >= 3) {
        final device = ref.read(devicesProvider).firstWhere((d) => d.id == deviceId);
        notificationService.showNotification(
          id: deviceId,
          title: 'High Usage Warning',
          body: '${device.name} has been running for over 3 hours.',
        );
      }
    });
  });
});
