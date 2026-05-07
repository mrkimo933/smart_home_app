// lib/core/utils/relay_sync_listener.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/devices_provider.dart';
import '../../providers/esp_provider.dart';
import '../../services/notification_service.dart';
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
        break;
      case VoltageStatus.high:
        notificationService.sendVoltageHighAlert(voltage);
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

  // ── Sensor data: overcurrent (Feature 4) + per-device budget (Feature 3) ──
  ref.listen<AsyncValue<SensorData>>(sensorDataProvider, (previous, next) {
    next.whenData((data) {
      final devices = ref.read(devicesProvider);
      _checkOvercurrent(data, devices, ref, notificationService);
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
          } else {
            notificationService.sendTimerEndAlert(device.name);
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

// ── House breaker limit (configurable) ────────────────────────────────────
const double kHouseBreakerAmps = 30.0;

// ── Overcurrent detection ──────────────────────────────────────────────────

void _checkOvercurrent(
  SensorData data,
  List<Device> devices,
  Ref ref,
  NotificationService notificationService,
) {
  const threshold = kHouseBreakerAmps * 1.1; // 10% tolerance
  if (data.current > threshold) {
    final onDevices = devices.where((d) => d.isOn).toList()
      ..sort((a, b) => b.wattage.compareTo(a.wattage));

    final targetDevice = onDevices.isNotEmpty ? onDevices.first : null;

    notificationService.sendOvercurrentAlert(
      targetDevice?.name ?? 'House',
      data.current,
      kHouseBreakerAmps,
    );

    if (targetDevice != null) {
      ref.read(httpEspServiceProvider).publishRelayCommand(targetDevice.relayId, false);
      ref.read(devicesProvider.notifier).toggleDevice(targetDevice.relayId, false);
    }

    ref.read(databaseServiceProvider).logOvercurrentIncident(
          deviceId: targetDevice?.id ?? 0,
          deviceName: targetDevice?.name ?? 'House',
          current: data.current,
          maxCurrent: kHouseBreakerAmps,
        );
  }
}

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
