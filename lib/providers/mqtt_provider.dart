// lib/providers/mqtt_provider.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'devices_provider.dart';
import 'package:smart_home_app/services/mqtt/mqtt_service.dart';
import 'package:smart_home_app/services/mqtt/mqtt_service_interface.dart';

import '../models/sensor_data.dart';

enum VoltageStatus { unknown, normal, low, high }

/// Provider for the MqttService instance
final mqttServiceProvider = Provider<MqttServiceInterface>((ref) {
  final service = getMqttService();
  ref.onDispose(() {
    service.disconnect();
  });
  return service;
});

/// Provider for MQTT connection status
final connectionStatusProvider = StreamProvider<bool>((ref) {
  final mqttService = ref.watch(mqttServiceProvider);
  final controller = StreamController<bool>();
  controller.add(false);
  final sub = mqttService.connectionStatusStream.listen(
    (status) => controller.add(status),
    onError: (e) => controller.addError(e),
    onDone: () => controller.close(),
  );
  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Provider for incoming sensor data
final sensorDataProvider = StreamProvider<SensorData>((ref) {
  final mqttService = ref.watch(mqttServiceProvider);
  final controller = StreamController<SensorData>();

  controller.add(SensorData(
    power: 0.0,
    voltage: 0.0,
    current: 0.0,
    kwh: 0.0,
    timestamp: DateTime.now(),
  ));

  final sub = mqttService.sensorDataStream.listen(
    (data) {
      // ignore: avoid_print
      print('Provider received new data: V=${data.voltage}, A=${data.current}, W=${data.power}');
      controller.add(data);
    },
    onError: (e) => controller.addError(e),
    onDone: () => controller.close(),
  );

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Voltage status derived from the latest sensor reading
final voltageStatusProvider = Provider<VoltageStatus>((ref) {
  final sensorAsync = ref.watch(sensorDataProvider);
  return sensorAsync.when(
    data: (data) {
      if (data.voltage == 0.0) return VoltageStatus.unknown;
      if (data.voltage < 200) return VoltageStatus.low;
      if (data.voltage > 240) return VoltageStatus.high;
      return VoltageStatus.normal;
    },
    loading: () => VoltageStatus.unknown,
    error: (_, __) => VoltageStatus.unknown,
  );
});

/// Provider for relay states map
final relayStatesProvider = StreamProvider<Map<int, bool>>((ref) {
  final mqttService = ref.watch(mqttServiceProvider);
  return mqttService.relayStatesStream;
});

/// Sync relay states to devices provider (simple debounced sync)
final relaySyncProvider = Provider<void>((ref) {
  final debounceMap = <int, Timer>{};
  ref.listen<AsyncValue<Map<int, bool>>>(relayStatesProvider, (previous, next) {
    next.whenData((map) {
      final devicesState = ref.read(devicesProvider);
      final devicesNotifier = ref.read(devicesProvider.notifier);
      map.forEach((relayId, isOn) {
        final matches = devicesState.where((d) => d.relayId == relayId);
        if (matches.isEmpty) return;
        final device = matches.first;
        if (device.isOn != isOn) {
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

/// Helper class to handle relay actions
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
