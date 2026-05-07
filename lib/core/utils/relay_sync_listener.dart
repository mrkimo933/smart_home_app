// lib/core/utils/relay_sync_listener.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/devices_provider.dart';
import '../../providers/esp_provider.dart';
import '../../providers/system_provider.dart';
import '../../services/notification_service.dart';
import '../../models/app_notification.dart';
import 'electricity_calculator.dart';
import '../../models/device.dart';
import '../../models/sensor_data.dart';

final relaySyncListenerProvider = Provider<void>((ref) {
  final notificationService = NotificationService();

  // Track when each device turned on (for high-usage warnings)
  final deviceOnTimers = <int, DateTime>{};

  // ── Feature 1: Relay state → immediate device toggle (zero-power on OFF) ──
  ref.listen<AsyncValue<Map<int, bool>>>(relayStatesProvider, (previous, next) {
    next.whenData((relayMap) {
      final devices = ref.read(devicesProvider);
      final devicesNotifier = ref.read(devicesProvider.notifier);

      for (final entry in relayMap.entries) {
        // relayMap keys are 0-based (from ESP); Device.relayId is 1-based
        final espIndex = entry.key;
        final relayId = espIndex + 1; // convert to 1-based
        final isOn = entry.value;
        try {
          final device = devices.firstWhere((d) => d.relayId == relayId);
          if (device.isOn != isOn) {
            devicesNotifier.toggleDevice(device.relayId, isOn);
            if (isOn) {
              deviceOnTimers[device.id] = DateTime.now();
            } else {
              deviceOnTimers.remove(device.id);
            }
          }
        } catch (_) {}
      }
    });
  });

  // ── Connection status: lost-connection notification ────────────────────────
  ref.listen<AsyncValue<bool>>(connectionStatusProvider, (previous, next) {
    next.whenData((isConnected) {
      if (previous?.value == true && !isConnected) {
        notificationService.showNotification(
          id: 999,
          title: 'Connection Lost',
          body: 'System disconnected. Possible power cut or network issue.',
        );
      }
    });
  });

  // ── Voltage status: Feature 5 ──────────────────────────────────────────────
  ref.listen<VoltageStatus>(voltageStatusProvider, (previous, next) {
    if (previous == next) return;

    final voltage = ref.read(sensorDataProvider).value?.voltage ?? 0.0;

    switch (next) {
      case VoltageStatus.low:
        notificationService.sendVoltageLowAlert(voltage);
        ref.read(notificationsProvider.notifier).add(AppNotification(
          id: DateTime.now().millisecondsSinceEpoch,
          title: '⚠️ Low Voltage Detected',
          body: '⚠️ Low voltage detected: ${voltage.toStringAsFixed(0)}V — This may damage sensitive devices.',
          type: NotificationType.voltageWarning,
          timestamp: DateTime.now(),
        ));
        break;
      case VoltageStatus.high:
        notificationService.sendVoltageHighAlert(voltage);
        ref.read(notificationsProvider.notifier).add(AppNotification(
          id: DateTime.now().millisecondsSinceEpoch,
          title: '🚨 HIGH VOLTAGE DANGER',
          body: '🚨 HIGH VOLTAGE DANGER: ${voltage.toStringAsFixed(0)}V detected! Disconnecting sensitive devices for safety.',
          type: NotificationType.voltageWarning,
          timestamp: DateTime.now(),
        ));
        _autoDisconnectNonEssential(ref, notificationService);
        break;
      case VoltageStatus.normal:
        if (previous != null &&
            previous != VoltageStatus.unknown &&
            previous != VoltageStatus.normal) {
          notificationService.sendVoltageNormalAlert(voltage);
        }
        break;
      case VoltageStatus.unknown:
        break;
    }
  });

  // ── Sensor data: Smart Protection Engine + per-device budget ──────────────
  ref.listen<AsyncValue<SensorData>>(sensorDataProvider, (previous, next) {
    next.whenData((data) {
      final devices = ref.read(devicesProvider);
      // Fire-and-forget: engine is internally guarded against re-entry.
      _protectionEngine.evaluate(
        data: data,
        devices: devices,
        ref: ref,
        notificationService: notificationService,
      );
      _checkDeviceBudgets(devices, ref, notificationService);
    });
  });

  // ── Periodic: device timers (Feature 6) + long-usage warnings ─────────────
  Timer? periodicTimer;
  periodicTimer = Timer.periodic(const Duration(minutes: 1), (_) {
    final now = DateTime.now();
    final devices = ref.read(devicesProvider);
    final espService = ref.read(httpEspServiceProvider);

    for (final device in devices) {
      if (!device.isOn) continue;

      // Timer check (Feature 6 & 7)
      if (device.timerMinutes != null && device.timerStartTime != null) {
        final elapsed = now.difference(device.timerStartTime!).inMinutes;
        if (elapsed >= device.timerMinutes!) {
          // relayId is 1-based; publishRelayCommand converts internally
          espService.publishRelayCommand(device.relayId, false);
          final isRunByBudget = device.runBudgetEGP != null;
          final budget = device.runBudgetEGP;
          ref.read(devicesProvider.notifier).clearDeviceTimer(device.id);
          if (isRunByBudget && budget != null) {
            notificationService.sendRunByBudgetEndAlert(device.name, budget);
            ref.read(notificationsProvider.notifier).add(AppNotification(
              id: DateTime.now().millisecondsSinceEpoch,
              title: 'Budget Run Ended 💰',
              body: '💰 ${device.name} budget of ${budget.toStringAsFixed(0)} EGP used — turned off.',
              type: NotificationType.scheduleExecuted,
              deviceName: device.name,
              timestamp: DateTime.now(),
            ));
          } else {
            notificationService.sendTimerEndAlert(device.name);
            ref.read(notificationsProvider.notifier).add(AppNotification(
              id: DateTime.now().millisecondsSinceEpoch,
              title: 'Timer Ended ⏰',
              body: '⏰ ${device.name} timer ended — turned off.',
              type: NotificationType.scheduleExecuted,
              deviceName: device.name,
              timestamp: DateTime.now(),
            ));
          }
        }
      }

      // Long-usage warning (fires every 3 hours)
      final startTime = deviceOnTimers[device.id];
      if (startTime != null) {
        final duration = now.difference(startTime);
        if (duration.inMinutes > 0 && duration.inMinutes % 180 == 0) {
          notificationService.showNotification(
            id: device.id,
            title: 'High Usage Warning',
            body: '${device.name} has been running for ${duration.inHours}h.',
          );
        }
      }
    }
  });
  ref.onDispose(() => periodicTimer?.cancel());
});

// ── Protection constants ───────────────────────────────────────────────────

/// House breaker limit in Amps. Overload is detected above this.
const double kHouseBreakerAmps = 30.0;

/// Any reading above this is a hard short-circuit / catastrophic fault.
/// At 220V, 50A = 11 kW — far beyond any residential load.
const double kShortCircuitThreshold = 50.0;

/// Tolerance before triggering overload (10% headroom for motor start surges).
const double kOverloadTolerance = 1.10;

/// How long to ignore repeated trips on the same device (anti-spam).
const Duration kPerDeviceCooldown = Duration(seconds: 30);

// ── Smart Protection Engine ────────────────────────────────────────────────
// A stateful singleton that lives for the lifetime of the provider.
// Tracks per-device trip timestamps + a global short-circuit lock.

class _SmartProtectionEngine {
  /// Last trip timestamp per device ID.
  final Map<int, DateTime> _deviceTripTimes = {};

  /// Prevent re-entrant calls while we are still sending HTTP requests.
  bool _handling = false;

  // ── Public entry point ───────────────────────────────────────────────────

  Future<void> evaluate({
    required SensorData data,
    required List<Device> devices,
    required Ref ref,
    required NotificationService notificationService,
  }) async {
    if (_handling) return; // already processing — skip this poll tick

    final current = data.current;
    final activeDevices = devices.where((d) => d.isOn).toList();

    // ── Tier 1: Short-circuit (catastrophic spike) ─────────────────────────
    if (current >= kShortCircuitThreshold) {
      await _handleShortCircuit(
        current: current,
        activeDevices: activeDevices,
        ref: ref,
        notificationService: notificationService,
      );
      return;
    }

    // ── Tier 2: Overload (exceeds sum of active device ratings or breaker) ─
    final expectedMax = _expectedMaxCurrent(activeDevices);
    const breakerLimit = kHouseBreakerAmps * kOverloadTolerance;
    if (current > breakerLimit || current > expectedMax * kOverloadTolerance) {
      await _handleOverload(
        current: current,
        expectedMax: expectedMax.clamp(0, kHouseBreakerAmps),
        activeDevices: activeDevices,
        ref: ref,
        notificationService: notificationService,
      );
    }
  }

  // ── Tier 1 handler: Short Circuit ────────────────────────────────────────

  Future<void> _handleShortCircuit({
    required double current,
    required List<Device> activeDevices,
    required Ref ref,
    required NotificationService notificationService,
  }) async {
    final now = DateTime.now();
    _handling = true;

    // Identify the most likely culprit:
    // The device with the highest rated current that is currently ON.
    // Rationale: a short circuit usually involves the load just switched on,
    // which tends to be the heaviest one.
    activeDevices.sort((a, b) => b.maxCurrentAmps.compareTo(a.maxCurrentAmps));
    final culprit = activeDevices.isNotEmpty ? activeDevices.first : null;

    final espService = ref.read(httpEspServiceProvider);
    final devicesNotifier = ref.read(devicesProvider.notifier);

    // Kill ALL active relays immediately for safety.
    final trippedRelayIds = <int>{};
    for (final device in activeDevices) {
      espService.publishRelayCommand(device.relayId, false);
      devicesNotifier.toggleDevice(device.relayId, false);
      _deviceTripTimes[device.id] = now;
      trippedRelayIds.add(device.relayId);
    }

    // Lock every tripped relay so the user must confirm before re-enabling.
    if (trippedRelayIds.isNotEmpty) {
      final current = ref.read(protectedRelaysProvider);
      ref.read(protectedRelaysProvider.notifier).state = {
        ...current,
        ...trippedRelayIds,
      };
    }

    // Fire high-priority notification.
    await notificationService.sendShortCircuitAlert(
      culpritName: culprit?.name ?? 'Unknown Device',
      detectedAmps: current,
      affectedCount: activeDevices.length,
    );
    ref.read(notificationsProvider.notifier).add(AppNotification(
      id: DateTime.now().millisecondsSinceEpoch,
      title: '🚨 Short Circuit Detected!',
      body: '⚠️ Danger Averted! "${culprit?.name ?? 'Unknown Device'}" and ${activeDevices.length} device(s) '
          'were automatically disconnected due to a severe Short Circuit '
          '(${current.toStringAsFixed(1)}A detected — limit: 50A).',
      type: NotificationType.shortCircuit,
      deviceName: culprit?.name,
      timestamp: DateTime.now(),
    ));

    // Log every tripped device to the incident DB.
    final db = ref.read(databaseServiceProvider);
    for (final device in activeDevices) {
      await db.logOvercurrentIncident(
        deviceId: device.id,
        deviceName: device.name,
        current: current,
        maxCurrent: kShortCircuitThreshold,
      );
    }

    _handling = false;
  }

  // ── Tier 2 handler: Overload ──────────────────────────────────────────────

  Future<void> _handleOverload({
    required double current,
    required double expectedMax,
    required List<Device> activeDevices,
    required Ref ref,
    required NotificationService notificationService,
  }) async {
    final now = DateTime.now();

    // Sort by priority (shed nonEssential first) then by wattage (highest first).
    final shedOrder = List<Device>.from(activeDevices)
      ..sort((a, b) {
        final pa = _priorityWeight(a.priority);
        final pb = _priorityWeight(b.priority);
        if (pa != pb) return pb.compareTo(pa); // higher weight = shed first
        return b.wattage.compareTo(a.wattage);
      });

    final espService = ref.read(httpEspServiceProvider);
    final devicesNotifier = ref.read(devicesProvider.notifier);
    final db = ref.read(databaseServiceProvider);

    double runningCurrent = current;

    // Shed devices one by one until we are back under the breaker limit.
    for (final device in shedOrder) {
      if (runningCurrent <= kHouseBreakerAmps) break;

      // Skip devices that tripped recently (per-device cooldown).
      final lastTrip = _deviceTripTimes[device.id];
      if (lastTrip != null && now.difference(lastTrip) < kPerDeviceCooldown) {
        continue;
      }

      _handling = true;
      _deviceTripTimes[device.id] = now;

      espService.publishRelayCommand(device.relayId, false);
      devicesNotifier.toggleDevice(device.relayId, false);

      await notificationService.sendOverloadAlert(
        deviceName: device.name,
        detectedAmps: current,
        maxAmps: expectedMax,
        deviceMaxAmps: device.maxCurrentAmps,
      );
      ref.read(notificationsProvider.notifier).add(AppNotification(
        id: DateTime.now().millisecondsSinceEpoch,
        title: '⚠️ Overload — Device Disconnected',
        body: '"${device.name}" was automatically turned off to prevent an overload '
            '(house drawing ${current.toStringAsFixed(1)}A, '
            'limit ${expectedMax.toStringAsFixed(1)}A).',
        type: NotificationType.overcurrent,
        deviceName: device.name,
        timestamp: DateTime.now(),
      ));

      await db.logOvercurrentIncident(
        deviceId: device.id,
        deviceName: device.name,
        current: current,
        maxCurrent: expectedMax,
      );

      // Approximate how much current this device contributed.
      runningCurrent -= (device.wattage / 220.0);
      _handling = false;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Sum of maxCurrentAmps for all currently active devices.
  double _expectedMaxCurrent(List<Device> activeDevices) {
    return activeDevices.fold(0.0, (sum, d) => sum + d.maxCurrentAmps);
  }

  /// Higher weight = shed this device first during overload.
  int _priorityWeight(DevicePriority priority) {
    switch (priority) {
      case DevicePriority.nonEssential:
        return 3;
      case DevicePriority.normal:
        return 2;
      case DevicePriority.essential:
        return 1; // shed last
    }
  }
}

// Global engine instance — lives for the Provider lifetime.
final _protectionEngine = _SmartProtectionEngine();

// ── Per-device budget check ────────────────────────────────────────────────

void _checkDeviceBudgets(
  List<Device> devices,
  Ref ref,
  NotificationService notificationService,
) {
  for (final device in devices) {
    if (!device.isOn) continue;
    final budget = device.monthlyBudgetEGP;
    if (budget == null || budget <= 0) continue;

    final dailyKwh =
        device.wattage * (device.totalOnMinutesToday / 60.0) / 1000.0;
    final monthlyCostEstimate =
        ElectricityCalculator.calculateCost(dailyKwh) * 30;

    if (monthlyCostEstimate >= budget) {
      notificationService.sendDeviceBudgetAlert(
          device.name, monthlyCostEstimate, budget);
      ref.read(notificationsProvider.notifier).add(AppNotification(
        id: DateTime.now().millisecondsSinceEpoch,
        title: 'Device Budget Reached 💰',
        body: '${device.name} has reached its ${budget.toStringAsFixed(0)} EGP monthly budget.',
        type: NotificationType.budgetAlert,
        deviceName: device.name,
        timestamp: DateTime.now(),
      ));

      if (device.autoOffOnBudget) {
        ref.read(httpEspServiceProvider).publishRelayCommand(device.relayId, false);
        ref.read(devicesProvider.notifier).toggleDevice(device.relayId, false);
        notificationService.sendDeviceAutoOffBudget(device.name);
      }
    }
  }
}

// ── High-voltage: auto-disconnect non-essential devices ───────────────────

void _autoDisconnectNonEssential(
    Ref ref, NotificationService notificationService) {
  final devices = ref.read(devicesProvider);
  final espService = ref.read(httpEspServiceProvider);
  for (final device in devices) {
    if (device.isOn && device.priority == DevicePriority.nonEssential) {
      espService.publishRelayCommand(device.relayId, false);
      ref.read(devicesProvider.notifier).toggleDevice(device.relayId, false);
    }
  }
}
