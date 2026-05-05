import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/devices_provider.dart';
import '../../providers/mqtt_provider.dart';
import '../../services/notification_service.dart';

final smartMorningProvider = Provider<void>((ref) {
  if (kIsWeb) return; // Notifications not supported on web

  Timer.periodic(const Duration(minutes: 1), (_) async {
    final now = DateTime.now();
    // Only run during morning window 6 AM – 10 AM
    if (now.hour < 6 || now.hour >= 10) return;

    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getString('last_morning_check_date') ?? '';
    final todayKey = '${now.year}-${now.month}-${now.day}';

    if (lastCheck == todayKey) return; // Already checked today

    final devices = ref.read(devicesProvider);
    bool checkedAnything = false;

    // Check 1: Lights still ON
    final lightsOn = devices
        .where((d) =>
            (d.icon == 'lamp' || d.icon == 'lightbulb') && d.isOn)
        .toList();
    if (lightsOn.isNotEmpty) {
      checkedAnything = true;
      await NotificationService().showNotification(
        id: 800,
        title: '💡 الإضاءة شغالة',
        body: 'الإضاءة في البيت لسه شغالة، تفصلها؟',
      );
    }

    // Check 2: AC running too long (> 6 hours = 360 minutes)
    final acDevices = devices
        .where((d) =>
            d.icon.toLowerCase().contains('ac') &&
            d.isOn &&
            d.totalOnMinutesToday > 360)
        .toList();
    if (acDevices.isNotEmpty) {
      checkedAnything = true;
      final hoursOn =
          (acDevices.first.totalOnMinutesToday / 60).round();
      await NotificationService().showNotification(
        id: 801,
        title: '❄️ التكييف شغال فترة طويلة',
        body: 'التكييف شغال من $hoursOn ساعات، تفصله؟',
      );
    }

    // Check 3: Multiple devices ON (>= 3)
    final activeDevices = devices.where((d) => d.isOn).toList();
    if (activeDevices.length >= 3) {
      checkedAnything = true;
      await NotificationService().showNotification(
        id: 802,
        title: '🏠 أجهزة كتير شغالة',
        body:
            'فيه ${activeDevices.length} أجهزة شغالين دلوقتي، تفصل كلهم؟',
      );
    }

    if (checkedAnything) {
      await prefs.setString('last_morning_check_date', todayKey);
    }
  });

  ref.onDispose(() {});
});

/// Helper: turn off all lamp devices via MQTT
void turnOffAllLamps(WidgetRef ref) {
  final devices = ref.read(devicesProvider);
  final mqtt = ref.read(mqttControllerProvider);
  for (final d in devices) {
    if ((d.icon == 'lamp' || d.icon == 'lightbulb') && d.isOn) {
      mqtt.toggleRelay(d.relayId, false);
      ref.read(devicesProvider.notifier).toggleDevice(d.relayId, false);
    }
  }
}

/// Helper: turn off all AC devices via MQTT
void turnOffAllAc(WidgetRef ref) {
  final devices = ref.read(devicesProvider);
  final mqtt = ref.read(mqttControllerProvider);
  for (final d in devices) {
    if (d.icon.toLowerCase().contains('ac') && d.isOn) {
      mqtt.toggleRelay(d.relayId, false);
      ref.read(devicesProvider.notifier).toggleDevice(d.relayId, false);
    }
  }
}

/// Helper: turn off ALL devices
void turnOffAllDevices(WidgetRef ref) {
  final devices = ref.read(devicesProvider);
  final mqtt = ref.read(mqttControllerProvider);
  for (final d in devices) {
    if (d.isOn) {
      mqtt.toggleRelay(d.relayId, false);
      ref.read(devicesProvider.notifier).toggleDevice(d.relayId, false);
    }
  }
}
