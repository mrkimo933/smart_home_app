// lib/services/mqtt_service.dart

import 'dart:async';
import 'dart:io';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/mqtt_topics.dart';
import '../models/sensor_data.dart';
import 'database_service.dart';

class MqttService {
  MqttServerClient? _client;
  final String _clientId = 'flutter_energy_monitor_${DateTime.now().millisecondsSinceEpoch}';
  
  // Stream Controllers
  final _sensorDataController = StreamController<SensorData>.broadcast();
  final _relayStatesController = StreamController<Map<int, bool>>.broadcast();
  final _connectionStatusController = StreamController<bool>.broadcast();

  // Streams
  Stream<SensorData> get sensorDataStream => _sensorDataController.stream;
  Stream<Map<int, bool>> get relayStatesStream => _relayStatesController.stream;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  // Internal state
  double _voltage = 0.0;
  double _current = 0.0;
  double _power = 0.0;
  double _kwh = 0.0;
  final Map<int, bool> _relayStates = {1: false, 2: false, 3: false, 4: false, 5: false, 6: false, 7: false, 8: false};
  
  Timer? _reconnectTimer;
  bool _isManuallyDisconnected = false;
  // Buffer latest sensor data and persist periodically (throttle DB writes)
  SensorData? _latestSensorData;
  Timer? _sensorPersistTimer;

  MqttService() {
    _init();
  }

  Future<void> _init() async {
    await connect();
  }

  Future<void> connect() async {
    _isManuallyDisconnected = false;
    final prefs = await SharedPreferences.getInstance();
    
    // HiveMQ Cloud requires the full hostname (SNI support)
    final brokerHost = prefs.getString('mqtt_broker_ip') ?? '192.168.1.100'; 
    final brokerPort = prefs.getInt('mqtt_broker_port') ?? 1883;
    final username = prefs.getString('mqtt_username') ?? '';
    final password = prefs.getString('mqtt_password') ?? '';
    
    // Use MqttServerClient with the full hostname string for SNI support
    _client = MqttServerClient(brokerHost, _clientId);
    _client!.port = brokerPort;
    _client!.keepAlivePeriod = 20;
    _client!.onDisconnected = _onDisconnected;
    _client!.onConnected = _onConnected;
    _client!.onSubscribed = _onSubscribed;
    _client!.logging(on: true);

    // Mandatory SSL/TLS for HiveMQ Cloud (Port 8883)
    if (brokerPort == 8883 || brokerHost.contains('hivemq.cloud')) {
      _client!.secure = true;
      _client!.securityContext = SecurityContext.defaultContext;
      // Handshake Fix: Bypass certificate validation errors
      _client!.onBadCertificate = (dynamic cert) => true;
    }

    // Set MQTT Protocol Version to 3.1.1
    _client!.setProtocolV311();

    final connMess = MqttConnectMessage()
        .withClientIdentifier(_clientId)
        .withWillTopic('app/status')
        .withWillMessage('offline')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    
    // Authentication: Ensure username and password are provided
    if (username.isNotEmpty) {
      connMess.authenticateAs(username, password);
    }
    
    _client!.connectionMessage = connMess;

    try {
      // Connect with username and password explicitly if needed by the client implementation
      await _client!.connect(username, password);
    } catch (e) {
      // ignore: avoid_print
      print('MQTT: Connection failed: $e');
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
            // ignore: avoid_print
            print('DB: Failed to persist sensor data: $e');
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
      
      // ignore: avoid_print
      print('MQTT: Subscribed to all topics');
    }
  }

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

  void disconnect() {
    _isManuallyDisconnected = true;
    _reconnectTimer?.cancel();
    _client?.disconnect();
  }

  void dispose() {
    disconnect();
    _sensorDataController.close();
    _relayStatesController.close();
    _connectionStatusController.close();
  }
}
