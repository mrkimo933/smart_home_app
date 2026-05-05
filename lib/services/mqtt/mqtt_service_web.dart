// lib/services/mqtt/mqtt_service_web.dart

import 'dart:async';

import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_app/services/mqtt/mqtt_service_interface.dart';
import '../../core/constants/mqtt_topics.dart';
import '../../models/sensor_data.dart';

MqttServiceInterface getMqttService() => MqttServiceWeb();

class MqttServiceWeb implements MqttServiceInterface {
  MqttBrowserClient? _client;
  final String _clientId = 'flutter_web_energy_monitor_${DateTime.now().millisecondsSinceEpoch}';

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

  MqttServiceWeb() {
    _init();
  }

  Future<void> _init() async {
    await connect();
  }

  @override
  Future<void> connect() async {
    _isManuallyDisconnected = false;
    final prefs = await SharedPreferences.getInstance();
    
    // تعديل Host: منع أي زوائد في الـ الرابط (مثل البورت أو البروتوكول)
    String rawIp = prefs.getString('mqtt_broker_ip') ?? 'broker.hivemq.com';
    String brokerIp = rawIp
        .replaceAll('mqtt://', '')
        .replaceAll('tcp://', '')
        .replaceAll('ws://', '')
        .replaceAll('wss://', '')
        .split(':')
        .first;
    
    // للويب بنستخدم بورت الـ websocket اللي غالباً بيكون 8083 أو 8084 للـ EMQX
    // و 8000 للـ HiveMQ
    final port = prefs.getInt('mqtt_broker_port') ?? 8000;
    final username = prefs.getString('mqtt_username') ?? '';
    final password = prefs.getString('mqtt_password') ?? '';

    // Use WebSocket for web
    String wsScheme = port == 8884 || port == 8084 ? 'wss' : 'ws'; 
    String wsUrl = '$wsScheme://$brokerIp:$port/mqtt';
    
    _client = MqttBrowserClient(wsUrl, _clientId);
    _client!.port = port;
    _client!.keepAlivePeriod = 20;
    _client!.onDisconnected = _onDisconnected;
    _client!.onConnected = _onConnected;
    _client!.onSubscribed = _onSubscribed;
    _client!.logging(on: true);

    final connMess = MqttConnectMessage()
        .withClientIdentifier(_clientId)
        .withWillTopic('app/status')
        .withWillMessage('offline')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    if (username.isNotEmpty && password.isNotEmpty) {
      connMess.authenticateAs(username, password);
    }
    
    _client!.connectionMessage = connMess;

    try {
      // ignore: avoid_print
      print('MQTT Web: Connecting to $wsUrl on port $port...');
      if (username.isNotEmpty && password.isNotEmpty) {
        await _client!.connect(username, password);
      } else {
        await _client!.connect();
      }
    } catch (e) {
      // ignore: avoid_print
      print('MQTT Web: Exception $e');
      _client!.disconnect();
      _connectionStatusController.add(false);
      _scheduleReconnect();
    }

    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      // 1. إعداد الـ listener أولاً قبل الاشتراك
      _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        final String topic = c[0].topic;
        _handleMessage(topic, payload);
      });

      // 2. تفعيل التنبيه بالاتصال والاشتراك
      _onConnected();
    } else {
      _connectionStatusController.add(false);
      _scheduleReconnect();
    }
  }

  void _handleMessage(String topic, String payload) {
    // ignore: avoid_print
    print('MQTT Web Received -> Topic: $topic, Payload: $payload');
    
    bool sensorUpdated = false;
    final cleanPayload = payload.trim();
    double? val = double.tryParse(cleanPayload);

    // معالجة الـ topic بشكل مرن
    final normalizedTopic = topic.startsWith('/') ? topic.substring(1) : topic;
    final voltageTopic = MqttTopics.voltage.startsWith('/') ? MqttTopics.voltage.substring(1) : MqttTopics.voltage;
    final currentTopic = MqttTopics.current.startsWith('/') ? MqttTopics.current.substring(1) : MqttTopics.current;
    final powerTopic = MqttTopics.power.startsWith('/') ? MqttTopics.power.substring(1) : MqttTopics.power;
    final kwhTopic = MqttTopics.kwh.startsWith('/') ? MqttTopics.kwh.substring(1) : MqttTopics.kwh;

    if (normalizedTopic == voltageTopic) {
      _voltage = val ?? 0.0;
      sensorUpdated = true;
    } else if (normalizedTopic == currentTopic) {
      _current = val ?? 0.0;
      sensorUpdated = true;
    } else if (normalizedTopic == powerTopic) {
      _power = val ?? 0.0;
      sensorUpdated = true;
    } else if (normalizedTopic == kwhTopic) {
      _kwh = val ?? 0.0;
      sensorUpdated = true;
    } else if (normalizedTopic.startsWith('esp/relay/')) {
      final parts = normalizedTopic.split('/');
      if (parts.length >= 3) {
        final id = int.tryParse(parts[2]);
        if (id != null) {
          _relayStates[id] = cleanPayload.toUpperCase() == 'ON';
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
    // ignore: avoid_print
    print('MQTT Web Subscribed successfully to: $topic');
  }

  @override
  void disconnect() {
    _isManuallyDisconnected = true;
    _reconnectTimer?.cancel();
    _client?.disconnect();
  }
}
