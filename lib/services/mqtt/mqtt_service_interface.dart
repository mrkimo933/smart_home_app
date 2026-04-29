// lib/services/mqtt/mqtt_service_interface.dart

import 'dart:async';
import 'package:smart_home_app/models/sensor_data.dart';

abstract class MqttServiceInterface {
  Stream<SensorData> get sensorDataStream;
  Stream<Map<int, bool>> get relayStatesStream;
  Stream<bool> get connectionStatusStream;

  Future<void> connect();
  void disconnect();
  void publishRelayCommand(int relayId, bool state);
}
