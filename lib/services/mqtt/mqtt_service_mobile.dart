// lib/services/mqtt/mqtt_service_mobile.dart

import 'dart:async';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_app/services/database_service.dart';
import 'package:smart_home_app/services/mqtt/mqtt_service_interface.dart';
import '../../core/constants/mqtt_topics.dart';
import '../../models/sensor_data.dart';

MqttServiceInterface getMqttService() => MqttServiceMobile();

class MqttServiceMobile implements MqttServiceInterface {
  MqttServerClient? _client;
  final String _clientId = 'flutter_energy_monitor_${DateTime.now().millisecondsSinceEpoch}';
  
  final _sensorDataController = StreamController<SensorData>.broadcast();
  final _relayStatesController = StreamController<Map<int, bool>>.broadcast();
  final _connectionStatusController = StreamController<bool>.broadcast();

  @override
  Stream<SensorData> get sensorDataStream => _sensorDataController.stream;
  @override
  Stream<Map<int, bool>> get relayStatesStream => _relayStatesController.stream;
  @override
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  double _voltage = 0.0;
  double _current = 0.0;
  double _power = 0.0;
  double _kwh = 0.0;
  final Map<int, bool> _relayStates = {1: false, 2: false, 3: false, 4: false};
  
  Timer? _reconnectTimer;
  bool _isManuallyDisconnected = false;
  SensorData? _latestSensorData;
  Timer? _sensorPersistTimer;

  MqttServiceMobile() {
    _init();
  }

  Future<void> _init() async {
    await connect();
  }

  @override
  Future<void> connect() async {
    _isManuallyDisconnected = false;
    final prefs = await SharedPreferences.getInstance();
    final brokerIp = prefs.getString('mqtt_broker_ip') ?? '192.168.1.100';
    
    _client = MqttServerClient(brokerIp, _clientId);
    _client!.port = 1883;
    _client!.keepAlivePeriod = 20;
    _client!.onDisconnected = _onDisconnected;
    _client!.onConnected = _onConnected;
    _client!.onSubscribed = _onSubscribed;
    _client!.logging(on: false);

    final connMess = MqttConnectMessage()
        .withClientIdentifier(_clientId)
        .withWillTopic('app/status')
        .withWillMessage('offline')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    
    _client!.connectionMessage = connMess;

    try {
      await _client!.connect();
    } catch (e) {
      _connectionStatusController.add(false);
      _scheduleReconnect();
    }

    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      _onConnected();
      
      _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        final String topic = c[0].topic;
        
        _handleMessage(topic, payload);
      });
    } else {
      _connectionStatusController.add(false);
      _scheduleReconnect();
    }
  }

  void _handleMessage(String topic, String payload) {
    bool sensorUpdated = false;
    double? val = double.tryParse(payload);

    if (topic == MqttTopics.voltage) {
      _voltage = val ?? 0.0;
      sensorUpdated = true;
    } else if (topic == MqttTopics.current) {
      _current = val ?? 0.0;
      sensorUpdated = true;
    } else if (topic == MqttTopics.power) {
      _power = val ?? 0.0;
      sensorUpdated = true;
    } else if (topic == MqttTopics.kwh) {
      _kwh = val ?? 0.0;
      sensorUpdated = true;
    } else if (topic.startsWith('esp/relay/')) {
      final parts = topic.split('/');
      if (parts.length >= 3) {
        final id = int.tryParse(parts[2]);
        if (id != null) {
          _relayStates[id] = payload.toUpperCase() == 'ON';
          _relayStatesController.add(Map.unmodifiable(_relayStates));
        }
      }
    }

    if (sensorUpdated) {
      final data = SensorData(
        voltage: _voltage,
        current: _current,
        power: _power,
        kwh: _kwh,
        timestamp: DateTime.now(),
      );
      _sensorDataController.add(data);

      _latestSensorData = data;
      _sensorPersistTimer ??= Timer.periodic(const Duration(minutes: 5), (_) async {
        if (_latestSensorData != null) {
          try {
            await DatabaseService().insertSensorData(_latestSensorData!);
          } catch (e) {
            // Log error or handle silently in production
          }
          _latestSensorData = null;
        }
      });
    }
  }

  void _subscribeToTopics() {
    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      for (var topic in MqttTopics.sensorTopics) {
        _client!.subscribe(topic, MqttQos.atMostOnce);
      }
      
      for (var topic in MqttTopics.relayStateTopics) {
        _client!.subscribe(topic, MqttQos.atMostOnce);
      }
    }
  }

  @override
  void publishRelayCommand(int relayId, bool state) {
    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      final topic = MqttTopics.relaySet(relayId);
      final payload = state ? 'ON' : 'OFF';
      
      final builder = MqttClientPayloadBuilder();
      builder.addString(payload);
      
      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    }
  }

  void _onConnected() {
    _connectionStatusController.add(true);
    _reconnectTimer?.cancel();
    _subscribeToTopics();
  }

  void _onDisconnected() {
    _connectionStatusController.add(false);
    if (!_isManuallyDisconnected) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      connect();
    });
  }

  void _onSubscribed(String topic) {
  }

  @override
  void disconnect() {
    _isManuallyDisconnected = true;
    _reconnectTimer?.cancel();
    _client?.disconnect();
  }
}
