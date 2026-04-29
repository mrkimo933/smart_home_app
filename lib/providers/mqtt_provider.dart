// lib/providers/mqtt_provider.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'devices_provider.dart';
import 'package:smart_home_app/services/mqtt/mqtt_service.dart';
import 'package:smart_home_app/services/mqtt/mqtt_service_interface.dart';

import '../models/sensor_data.dart';

/// Provider for the MqttService instance
final mqttServiceProvider = Provider<MqttServiceInterface>((ref) {
  final service = getMqttService();
  
  // Clean up when the provider is destroyed
  ref.onDispose(() {
    service.disconnect();
  });
  
  return service;
});

/// Provider for MQTT connection status
final connectionStatusProvider = StreamProvider<bool>((ref) {
  final mqttService = ref.watch(mqttServiceProvider);
  return mqttService.connectionStatusStream;
});

/// Provider for incoming sensor data
final sensorDataProvider = StreamProvider<SensorData>((ref) {
  final mqttService = ref.watch(mqttServiceProvider);
  return mqttService.sensorDataStream;
});

/// Provider for relay states map
final relayStatesProvider = StreamProvider<Map<int, bool>>((ref) {
  final mqttService = ref.watch(mqttServiceProvider);
  return mqttService.relayStatesStream;
});

/// Sync relay states to devices provider: when relayStates stream emits,
/// update the devicesProvider state accordingly.
final relaySyncProvider = Provider<void>((ref) {
  // Listen to relay states stream and apply to devicesProvider
  final debounceMap = <int, Timer>{};
  ref.listen<AsyncValue<Map<int, bool>>>(relayStatesProvider, (previous, next) {
    next.whenData((map) {
      final devicesState = ref.read(devicesProvider);
      final devicesNotifier = ref.read(devicesProvider.notifier);
      map.forEach((relayId, isOn) {
        // Find device with matching relayId (safe)
        final matches = devicesState.where((d) => d.relayId == relayId);
        if (matches.isEmpty) return;
        final device = matches.first;

        // Only toggle if state differs
        if (device.isOn != isOn) {
          // Debounce to avoid rapid repeated updates
          debounceMap[relayId]?.cancel();
          debounceMap[relayId] = Timer(const Duration(milliseconds: 300), () {
            devicesNotifier.toggleDevice(relayId, isOn);
          });
        }
      });
    });
  });
  return;
});

/// Helper class to handle relay actions, or could just be individual functions
class MqttController {
  final MqttServiceInterface _service;

  MqttController(this._service);

  void toggleRelay(int relayId, bool state) {
    _service.publishRelayCommand(relayId, state);
  }
}

/// Provider for MQTT actions (like toggling relays)
final mqttControllerProvider = Provider<MqttController>((ref) {
  final service = ref.watch(mqttServiceProvider);
  return MqttController(service);
});
