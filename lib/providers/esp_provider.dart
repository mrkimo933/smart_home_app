// lib/providers/esp_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sensor_data.dart';
import '../services/http_esp_service.dart';

enum VoltageStatus { unknown, normal, low, high }

/// The single HttpEspService instance.
final httpEspServiceProvider = Provider<HttpEspService>((ref) {
  final service = HttpEspService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Initialises the service on startup (loads saved IP and starts polling).
/// Watch this provider in the app root to kick-off polling automatically.
final espInitProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(httpEspServiceProvider);
  final savedIp = await service.getEspIp();
  if (savedIp != null && savedIp.isNotEmpty) {
    await service.setEspIp(savedIp); // restarts polling with saved IP
  }
});

/// Connection status stream — true = connected, false = disconnected.
final connectionStatusProvider = StreamProvider<bool>((ref) {
  return ref.watch(httpEspServiceProvider).connectionStatusStream;
});

/// Live sensor data stream.
final sensorDataProvider = StreamProvider<SensorData>((ref) {
  final controller = ref.watch(httpEspServiceProvider);
  return controller.sensorDataStream;
});

/// Relay states map (0-based ESP index → on/off).
final relayStatesProvider = StreamProvider<Map<int, bool>>((ref) {
  return ref.watch(httpEspServiceProvider).relayStatesStream;
});

/// Voltage status derived from the latest sensor reading.
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

/// Kept for backward-compatibility: anything that used mqttControllerProvider
/// now gets the HttpEspService directly.
final mqttControllerProvider = Provider<HttpEspService>((ref) {
  return ref.watch(httpEspServiceProvider);
});
