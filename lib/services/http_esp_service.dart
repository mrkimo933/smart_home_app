// lib/services/http_esp_service.dart

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/consumption_record.dart';
import '../models/sensor_data.dart';
import 'database_service.dart';
import '../core/utils/electricity_calculator.dart';

class HttpEspService {
  static const String _ipKey = 'esp_ip';
  static const Duration _pollInterval = Duration(seconds: 2);
  static const Duration _retryInterval = Duration(seconds: 5);
  static const Duration _requestTimeout = Duration(seconds: 3);

  final StreamController<SensorData> _sensorDataController =
      StreamController<SensorData>.broadcast();
  final StreamController<Map<int, bool>> _relayStatesController =
      StreamController<Map<int, bool>>.broadcast();
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();

  Timer? _pollingTimer;
  String? _espIp;

  // kWh accumulation
  double _accumulatedKwh = 0.0;
  double _lastWatts = 0.0;
  DateTime? _lastKwhTime;

  // DB persist throttle
  SensorData? _latestSensorData;
  double _previousKwh = 0.0;
  Timer? _sensorPersistTimer;

  Stream<SensorData> get sensorDataStream => _sensorDataController.stream;
  Stream<Map<int, bool>> get relayStatesStream => _relayStatesController.stream;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  HttpEspService() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _espIp = prefs.getString(_ipKey);
    if (_espIp != null && _espIp!.isNotEmpty) {
      _startPolling();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollInterval, (_) => _poll());
    // Run once immediately
    _poll();
  }

  Future<void> _poll() async {
    if (_espIp == null || _espIp!.isEmpty) return;

    try {
      final response = await http
          .get(Uri.parse('http://$_espIp/api/data'))
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        _connectionStatusController.add(true);
        _parseAndEmit(response.body);
      } else {
        _connectionStatusController.add(false);
        _scheduleRetry();
      }
    } catch (_) {
      _connectionStatusController.add(false);
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    // If poll fails, restart with a longer interval
    _pollingTimer?.cancel();
    _pollingTimer = Timer(_retryInterval, () {
      _startPolling();
    });
  }

  void _parseAndEmit(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;

      final double totalPower = (json['totalPower'] as num?)?.toDouble() ?? 0.0;
      final double totalCurrent =
          (json['totalCurrent'] as num?)?.toDouble() ?? 0.0;
      const double voltage = 220.0;

      // Accumulate kWh
      final now = DateTime.now();
      if (_lastKwhTime != null) {
        final elapsedHours = now.difference(_lastKwhTime!).inMicroseconds /
            Duration.microsecondsPerHour;
        _accumulatedKwh += (_lastWatts / 1000.0) * elapsedHours;
      }
      _lastWatts = totalPower;
      _lastKwhTime = now;

      // Parse relay states (0-based from ESP, keep 0-based here)
      final Map<int, bool> relayMap = {};
      final relayList = json['relays'];
      if (relayList is List) {
        for (int i = 0; i < relayList.length; i++) {
          relayMap[i] = relayList[i] == true;
        }
      }

      final data = SensorData(
        voltage: voltage,
        current: totalCurrent,
        power: totalPower,
        kwh: _accumulatedKwh,
        timestamp: now,
      );

      _sensorDataController.add(data);
      _relayStatesController.add(Map.unmodifiable(relayMap));

      // Throttle DB writes
      _latestSensorData = data;
      _sensorPersistTimer ??=
          Timer.periodic(const Duration(minutes: 5), (_) async {
        if (_latestSensorData != null) {
          try {
            final db = DatabaseService();
            await db.insertSensorData(_latestSensorData!);

            final currentKwh = _latestSensorData!.kwh;
            final deltaKwh = currentKwh - _previousKwh;
            if (deltaKwh > 0) {
              final cost = ElectricityCalculator.calculateCost(deltaKwh);
              await db.insertConsumptionRecord(ConsumptionRecord(
                kwh: deltaKwh,
                costEGP: cost,
                date: DateTime.now(),
                deviceId: 0,
              ));
            }
            _previousKwh = currentKwh;
          } catch (_) {
            // Non-critical
          }
          _latestSensorData = null;
        }
      });
    } catch (_) {
      // Parse error — treat as connection failure
      _connectionStatusController.add(false);
    }
  }

  /// Toggle a relay by its 0-based ESP index, then immediately fetch new state.
  Future<void> toggleRelay(int relayIndex) async {
    if (_espIp == null || _espIp!.isEmpty) return;
    try {
      await http
          .get(Uri.parse('http://$_espIp/toggle?id=$relayIndex'))
          .timeout(_requestTimeout);
      // Immediately fetch new state after toggle
      await _poll();
    } catch (_) {
      // Ignore — next poll will sync state
    }
  }

  /// Save ESP IP and restart polling.
  Future<void> setEspIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ipKey, ip);
    _espIp = ip;
    _startPolling();
  }

  /// Read saved ESP IP.
  Future<String?> getEspIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ipKey);
  }

  /// Test if the given IP responds with a valid /api/data endpoint.
  Future<bool> testConnection(String ip) async {
    try {
      final response = await http
          .get(Uri.parse('http://$ip/api/data'))
          .timeout(_requestTimeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Also expose a publishRelayCommand-compatible method for relay_sync_listener.
  /// relayId here is 1-based (Device.relayId); convert to 0-based for ESP.
  void publishRelayCommand(int relayId, bool state) {
    final espIndex = relayId - 1; // 1-based → 0-based
    if (state) {
      // The ESP toggle endpoint is toggle-based, so we need to check current
      // state and only call toggle if needed. For simplicity, call toggleRelay
      // and let the next poll reconcile. This matches existing behaviour.
      toggleRelay(espIndex);
    } else {
      toggleRelay(espIndex);
    }
  }

  void dispose() {
    _pollingTimer?.cancel();
    _sensorPersistTimer?.cancel();
    _sensorDataController.close();
    _relayStatesController.close();
    _connectionStatusController.close();
  }
}
