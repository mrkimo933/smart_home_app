// lib/services/mqtt/mqtt_service_mobile.dart

import 'dart:async';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_app/models/consumption_record.dart';
import 'package:smart_home_app/services/database_service.dart';
import 'package:smart_home_app/services/mqtt/mqtt_service_interface.dart';
import 'package:smart_home_app/core/utils/electricity_calculator.dart';
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
  double _previousKwh = 0.0;
  final Map<int, bool> _relayStates = {1: false, 2: false, 3: false, 4: false};

  Timer? _reconnectTimer;
  bool _isManuallyDisconnected = false;
  int _reconnectAttempts = 0;
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
    
    // تعديل Host: منع أي زوائد في الـ الرابط
    // تعديل Host: منع أي زوائد في الـ الرابط (مثل البورت أو البروتوكول)
    String rawIp = prefs.getString('mqtt_broker_ip') ?? 'broker.hivemq.com';
    String brokerIp = rawIp
        .replaceAll('mqtt://', '')
        .replaceAll('tcp://', '')
        .replaceAll('ws://', '')
        .replaceAll('wss://', '')
        .split(':')
        .first;
    
    final port = prefs.getInt('mqtt_broker_port') ?? 1883;
    final username = prefs.getString('mqtt_username') ?? '';
    final password = prefs.getString('mqtt_password') ?? '';

    // تحديد نوع الـ Client
    _client = MqttServerClient(brokerIp, _clientId);
    _client!.port = port;
    
    // تعطيل التشفير وتفعيله فقط إذا كان البورت 8883
    _client!.secure = false;
    if (port == 8883) {
      _client!.secure = true;
      _client!.onBadCertificate = (dynamic cert) => true;
    }

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
      print('MQTT: Connecting to $brokerIp:$port...');
      if (username.isNotEmpty && password.isNotEmpty) {
        await _client!.connect(username, password);
      } else {
        await _client!.connect();
      }
    } catch (e) {
      // ignore: avoid_print
      print('MQTT: Exception $e');
      _client!.disconnect();
      _connectionStatusController.add(false);
      _scheduleReconnect();
    }

    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      // 1. إعداد الـ listener أولاً قبل الاشتراك لضمان عدم ضياع أول رسالة
      _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        final String topic = c[0].topic;
        
        _handleMessage(topic, payload);
      });

      // 2. تفعيل التنبيه بالاتصال والاشتراك في الـ topics
      _onConnected();
    } else {
      _connectionStatusController.add(false);
      _scheduleReconnect();
    }
  }

  void _handleMessage(String topic, String payload) {
    // ignore: avoid_print
    print('MQTT Received -> Topic: $topic, Payload: $payload');
    
    bool sensorUpdated = false;
    // تنظيف الـ payload من أي مسافات زائدة
    final cleanPayload = payload.trim();
    double? val = double.tryParse(cleanPayload);

    // معالجة الـ topic بشكل مرن (يتعامل مع وجود / في البداية)
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

      _latestSensorData = data;
      _sensorPersistTimer ??= Timer.periodic(const Duration(minutes: 5), (_) async {
        if (_latestSensorData != null) {
          try {
            final db = DatabaseService();
            await db.insertSensorData(_latestSensorData!);

            // Calculate delta kWh since last persist and record consumption
            final currentKwh = _latestSensorData!.kwh;
            final deltaKwh = currentKwh - _previousKwh;
            if (deltaKwh > 0) {
              final cost = ElectricityCalculator.calculateCost(deltaKwh);
              await db.insertConsumptionRecord(ConsumptionRecord(
                kwh: deltaKwh,
                costEGP: cost,
                date: DateTime.now(),
                deviceId: 0, // 0 = house total
              ));
            }
            _previousKwh = currentKwh;
          } catch (e) {
            // Log error
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
    _reconnectAttempts = 0; // Reset on successful connection
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
    // Exponential backoff: delay = min(5 * 2^attempts, 60) seconds
    final delaySeconds = (5 * (1 << _reconnectAttempts)).clamp(5, 60);
    _reconnectAttempts++;
    // ignore: avoid_print
    print('MQTT: Reconnect attempt $_reconnectAttempts in ${delaySeconds}s');
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      connect();
    });
  }

  void _onSubscribed(String topic) {
    // ignore: avoid_print
    print('MQTT Subscribed successfully to: $topic');
  }

  @override
  void disconnect() {
    _isManuallyDisconnected = true;
    _reconnectTimer?.cancel();
    _client?.disconnect();
  }
}
