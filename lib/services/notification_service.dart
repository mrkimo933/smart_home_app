import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(initSettings);
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    bool highPriority = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      highPriority ? 'danger_alerts' : 'energy_alerts',
      highPriority ? 'Danger Alerts' : 'Energy Alerts',
      channelDescription: 'Smart home energy and safety notifications',
      importance: highPriority ? Importance.max : Importance.high,
      priority: highPriority ? Priority.max : Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _plugin.show(id, title, body, details);
  }

  // Returns true if the notification type can be shown (10-min cooldown).
  Future<bool> _canShowWithCooldown(String key,
      {Duration cooldown = const Duration(minutes: 10)}) async {
    final prefs = await SharedPreferences.getInstance();
    final lastStr = prefs.getString('notif_ts_$key');
    if (lastStr != null) {
      final last = DateTime.tryParse(lastStr);
      if (last != null && DateTime.now().difference(last) < cooldown) {
        return false;
      }
    }
    await prefs.setString('notif_ts_$key', DateTime.now().toIso8601String());
    return true;
  }

  // Legacy daily-once smart notification (kept for backward compat)
  Future<void> showSmartNotification({
    required int id,
    required String type,
    required String title,
    required String body,
  }) async {
    if (await _canShowWithCooldown(type, cooldown: const Duration(hours: 12))) {
      await showNotification(id: id, title: title, body: body);
    }
  }

  // ─── Budget alerts (house) ─────────────────────────────────────────────────

  Future<void> sendHouseBudgetAlert(int percent, double spent, double budget) async {
    final key = 'house_budget_$percent';
    if (!await _canShowWithCooldown(key, cooldown: const Duration(hours: 6))) return;

    late String title;
    late String body;
    switch (percent) {
      case 50:
        title = 'Budget Notice 💡';
        body = "You've used half your monthly budget (${spent.toStringAsFixed(0)}/${budget.toStringAsFixed(0)} EGP).";
        break;
      case 75:
        title = 'Budget Warning ⚠️';
        body = "Warning: 75% of budget used (${spent.toStringAsFixed(0)}/${budget.toStringAsFixed(0)} EGP).";
        break;
      case 90:
        title = 'Budget Critical 🔴';
        body = "Critical: almost at limit! ${spent.toStringAsFixed(0)}/${budget.toStringAsFixed(0)} EGP used.";
        break;
      case 100:
        title = 'Budget Exceeded ❌';
        body = "Budget exceeded! ${spent.toStringAsFixed(0)} EGP spent. Consider turning off non-essential devices.";
        break;
      default:
        return;
    }
    await showNotification(id: 100 + percent, title: title, body: body);
  }

  // ─── Per-device budget alerts ──────────────────────────────────────────────

  Future<void> sendDeviceBudgetAlert(String deviceName, double cost, double budget) async {
    final key = 'device_budget_${deviceName.replaceAll(' ', '_')}';
    if (!await _canShowWithCooldown(key, cooldown: const Duration(hours: 3))) return;
    await showNotification(
      id: 400 + deviceName.hashCode.abs() % 99,
      title: 'Device Budget Reached',
      body: '$deviceName has reached its ${budget.toStringAsFixed(0)} EGP budget.',
    );
  }

  Future<void> sendDeviceAutoOffBudget(String deviceName) async {
    await showNotification(
      id: 450 + deviceName.hashCode.abs() % 49,
      title: 'Device Turned Off',
      body: '$deviceName turned off — monthly budget reached.',
    );
  }

  // ─── Overcurrent alerts ────────────────────────────────────────────────────

  /// Legacy single-device overcurrent — kept for backward compatibility.
  Future<void> sendOvercurrentAlert(
      String deviceName, double current, double maxCurrent) async {
    final key = 'overcurrent_${deviceName.replaceAll(' ', '_')}';
    if (!await _canShowWithCooldown(key)) return;
    await showNotification(
      id: 200 + deviceName.hashCode.abs() % 99,
      title: '⚠️ DANGER: Overcurrent',
      body: '⚠️ DANGER: $deviceName drawing abnormal current '
          '(${current.toStringAsFixed(1)}A)! Auto-disconnecting for safety.',
      highPriority: true,
    );
  }

  /// Tier-1: Catastrophic short-circuit — all active relays were killed.
  /// Short cooldown (30 s) so the user is always informed of a hard fault.
  Future<void> sendShortCircuitAlert({
    required String culpritName,
    required double detectedAmps,
    required int affectedCount,
  }) async {
    const key = 'short_circuit';
    if (!await _canShowWithCooldown(key, cooldown: const Duration(seconds: 30))) {
      return;
    }
    await showNotification(
      id: 210,
      title: '🚨 Short Circuit Detected!',
      body: '⚠️ Danger Averted! "$culpritName" and $affectedCount device(s) '
          'were automatically disconnected due to a severe Short Circuit '
          '(${detectedAmps.toStringAsFixed(1)}A detected — limit: 50A). '
          'Check your wiring before reconnecting.',
      highPriority: true,
    );
  }

  /// Tier-2: Overload — a single device was shed to reduce total load.
  Future<void> sendOverloadAlert({
    required String deviceName,
    required double detectedAmps,
    required double maxAmps,
    required double deviceMaxAmps,
  }) async {
    final key = 'overload_${deviceName.replaceAll(' ', '_')}';
    if (!await _canShowWithCooldown(key, cooldown: const Duration(seconds: 30))) {
      return;
    }
    await showNotification(
      id: 220 + deviceName.hashCode.abs() % 79,
      title: '⚠️ Overload — Device Disconnected',
      body: '"$deviceName" was automatically turned off to prevent an overload '
          '(house drawing ${detectedAmps.toStringAsFixed(1)}A, '
          'limit ${maxAmps.toStringAsFixed(1)}A). '
          'Device rated max: ${deviceMaxAmps.toStringAsFixed(1)}A.',
      highPriority: true,
    );
  }

  // ─── Voltage alerts ────────────────────────────────────────────────────────

  Future<void> sendVoltageLowAlert(double voltage) async {
    if (!await _canShowWithCooldown('voltage_low')) return;
    await showNotification(
      id: 300,
      title: '⚠️ Low Voltage Detected',
      body: '⚠️ Low voltage detected: ${voltage.toStringAsFixed(0)}V — This may damage sensitive devices.',
    );
  }

  Future<void> sendVoltageHighAlert(double voltage) async {
    // High voltage: no cooldown suppression, always alert immediately
    await showNotification(
      id: 301,
      title: '🚨 HIGH VOLTAGE DANGER',
      body: '🚨 HIGH VOLTAGE DANGER: ${voltage.toStringAsFixed(0)}V detected! Disconnecting sensitive devices for safety.',
      highPriority: true,
    );
  }

  Future<void> sendVoltageNormalAlert(double voltage) async {
    if (!await _canShowWithCooldown('voltage_normal')) return;
    await showNotification(
      id: 302,
      title: '✅ Voltage Normal',
      body: '✅ Voltage back to normal: ${voltage.toStringAsFixed(0)}V.',
    );
  }

  // ─── Timer alerts ──────────────────────────────────────────────────────────

  Future<void> sendTimerEndAlert(String deviceName) async {
    await showNotification(
      id: 500 + deviceName.hashCode.abs() % 99,
      title: 'Timer Ended ⏰',
      body: '⏰ $deviceName timer ended — turned off.',
    );
  }

  Future<void> sendRunByBudgetEndAlert(String deviceName, double budget) async {
    await showNotification(
      id: 600 + deviceName.hashCode.abs() % 99,
      title: 'Budget Run Ended 💰',
      body: '💰 $deviceName budget of ${budget.toStringAsFixed(0)} EGP used — turned off.',
    );
  }
}
