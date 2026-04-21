// lib/providers/mqtt_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/mqtt_service.dart';
import '../models/sensor_data.dart';

/// Provider for the MqttService instance
final mqttServiceProvider = Provider<MqttService>((ref) {
  final service = MqttService();
  
  // Clean up when the provider is destroyed
  ref.onDispose(() {
    service.dispose();
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

/// Helper class to handle relay actions, or could just be individual functions
class MqttController {
  final MqttService _service;

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
