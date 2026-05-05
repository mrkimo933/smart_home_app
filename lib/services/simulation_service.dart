// lib/services/simulation_service.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sensor_data.dart';

enum SimulationScenario { normalDay, highConsumption, savingDay }

enum SimulationSpeed { x1, x60, x144, x1440 }

extension SimulationSpeedExt on SimulationSpeed {
  int get multiplier {
    switch (this) {
      case SimulationSpeed.x1:
        return 1;
      case SimulationSpeed.x60:
        return 60;
      case SimulationSpeed.x144:
        return 144;
      case SimulationSpeed.x1440:
        return 1440;
    }
  }

  String get label {
    switch (this) {
      case SimulationSpeed.x1:
        return '1x (وقت حقيقي)';
      case SimulationSpeed.x60:
        return '60x (دقيقة = ساعة)';
      case SimulationSpeed.x144:
        return '144x (10 دقايق = يوم)';
      case SimulationSpeed.x1440:
        return '1440x (دقيقة = يوم)';
    }
  }
}

extension SimulationScenarioExt on SimulationScenario {
  String get label {
    switch (this) {
      case SimulationScenario.normalDay:
        return 'يوم عادي';
      case SimulationScenario.highConsumption:
        return 'يوم استهلاك عالي';
      case SimulationScenario.savingDay:
        return 'يوم توفير';
    }
  }
}

class SimulationState {
  final bool isRunning;
  final bool isPaused;
  final SimulationScenario scenario;
  final SimulationSpeed speed;
  final double simulatedHour; // 0.0–24.0
  final double progress; // 0.0–1.0
  final SensorData? currentData;
  final String statusMessage;
  final double totalKwh;
  final double totalCost;

  const SimulationState({
    this.isRunning = false,
    this.isPaused = false,
    this.scenario = SimulationScenario.normalDay,
    this.speed = SimulationSpeed.x60,
    this.simulatedHour = 0,
    this.progress = 0,
    this.currentData,
    this.statusMessage = '',
    this.totalKwh = 0,
    this.totalCost = 0,
  });

  SimulationState copyWith({
    bool? isRunning,
    bool? isPaused,
    SimulationScenario? scenario,
    SimulationSpeed? speed,
    double? simulatedHour,
    double? progress,
    SensorData? currentData,
    String? statusMessage,
    double? totalKwh,
    double? totalCost,
  }) {
    return SimulationState(
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
      scenario: scenario ?? this.scenario,
      speed: speed ?? this.speed,
      simulatedHour: simulatedHour ?? this.simulatedHour,
      progress: progress ?? this.progress,
      currentData: currentData ?? this.currentData,
      statusMessage: statusMessage ?? this.statusMessage,
      totalKwh: totalKwh ?? this.totalKwh,
      totalCost: totalCost ?? this.totalCost,
    );
  }
}

/// Generates a SensorData snapshot for a given hour and scenario.
SensorData _generateData(double hour, SimulationScenario scenario) {
  double power = 0;
  double voltage = 220 + (hour % 3) * 2.0;

  switch (scenario) {
    case SimulationScenario.normalDay:
      if (hour >= 6 && hour < 7) power = 60; // lights on
      if (hour >= 7 && hour < 8) power = 210; // fridge + tv
      if (hour >= 8 && hour < 22) power = 1710; // AC on
      if (hour >= 12 && hour < 14) power = 2200; // peak + AC
      if (hour >= 22 && hour < 24) power = 150; // light tv
      break;

    case SimulationScenario.highConsumption:
      power = hour >= 6 && hour < 24 ? 4500 : 150;
      if (hour >= 12 && hour < 16) power = 6000;
      voltage = hour >= 19 && hour < 21 ? 185 : 220; // low voltage
      break;

    case SimulationScenario.savingDay:
      if (hour >= 6 && hour < 8) power = 60;
      if (hour >= 8 && hour < 18) power = 300; // essential only
      if (hour >= 18 && hour < 22) power = 210;
      break;
  }

  final current = voltage > 0 ? (power / voltage).toDouble() : 0.0;
  final kwh = power * (1 / 60) / 1000; // kWh per minute tick

  return SensorData(
    voltage: voltage,
    current: current,
    power: power,
    kwh: kwh,
    timestamp: DateTime.now(),
  );
}

String _getStatusMessage(double hour, SimulationScenario scenario) {
  if (scenario == SimulationScenario.normalDay) {
    if (hour < 6) return '🌙 الليل - كل الأجهزة مطفية';
    if (hour < 7) return '🌅 الصبح - الإضاءة اتفتحت';
    if (hour < 8) return '🕑 الفريدج والتليفزيون شغالين';
    if (hour < 12) return '❄️ التكييف اتفتح';
    if (hour < 16) return '⚡ وقت الذروة - استهلاك عالي';
    if (hour < 19) return '🌇 بعد الذروة';
    if (hour < 22) return '⚡ ذروة المساء';
    return '🌙 وضع الليل';
  }
  if (scenario == SimulationScenario.highConsumption) {
    if (hour >= 12 && hour < 16) return '🚨 استهلاك خطير - تجاوز الميزانية!';
    if (hour >= 19 && hour < 21) return '⚠️ جهد منخفض - خطر على الأجهزة';
    return '🔴 استهلاك عالي - كل الأجهزة شغالة';
  }
  if (hour < 8) return '🌱 بداية يوم التوفير';
  if (hour < 18) return '✅ الأجهزة الضرورية فقط شغالة';
  return '🌙 توفير ممتاز!';
}

class SimulationNotifier extends StateNotifier<SimulationState> {
  Timer? _timer;
  final StreamController<SensorData> _dataController;

  SimulationNotifier(this._dataController) : super(const SimulationState());

  Stream<SensorData> get dataStream => _dataController.stream;

  void setScenario(SimulationScenario s) =>
      state = state.copyWith(scenario: s);

  void setSpeed(SimulationSpeed s) => state = state.copyWith(speed: s);

  void start() {
    if (state.isRunning && !state.isPaused) return;
    state = state.copyWith(isRunning: true, isPaused: false);
    _startTick();
  }

  void pause() {
    _timer?.cancel();
    state = state.copyWith(isPaused: true);
  }

  void resume() {
    state = state.copyWith(isPaused: false);
    _startTick();
  }

  void stop() {
    _timer?.cancel();
    state = const SimulationState();
  }

  void reset() {
    _timer?.cancel();
    state = SimulationState(
      scenario: state.scenario,
      speed: state.speed,
    );
  }

  void _startTick() {
    _timer?.cancel();
    // Real-time tick: 1 second = (speed) simulated minutes
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.isPaused) return;

      final minutesPerTick = state.speed.multiplier / 60.0;
      final newHour = state.simulatedHour + minutesPerTick;

      if (newHour >= 24) {
        _timer?.cancel();
        state = state.copyWith(
          isRunning: false,
          simulatedHour: 24,
          progress: 1.0,
          statusMessage: '✅ انتهى اليوم! اضغط Reset لتكرار',
        );
        return;
      }

      final data = _generateData(newHour, state.scenario);
      _dataController.add(data);

      final newKwh = state.totalKwh + data.kwh;
      final cost = newKwh * 1.4; // ~1.4 EGP/kWh average

      state = state.copyWith(
        simulatedHour: newHour,
        progress: newHour / 24.0,
        currentData: data,
        statusMessage: _getStatusMessage(newHour, state.scenario),
        totalKwh: newKwh,
        totalCost: cost,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final _simDataController =
    Provider<StreamController<SensorData>>((ref) {
  final ctrl = StreamController<SensorData>.broadcast();
  ref.onDispose(ctrl.close);
  return ctrl;
});

final simulationProvider =
    StateNotifierProvider<SimulationNotifier, SimulationState>((ref) {
  final ctrl = ref.watch(_simDataController);
  return SimulationNotifier(ctrl);
});

final simulationDataStreamProvider = Provider<Stream<SensorData>>((ref) {
  final ctrl = ref.watch(_simDataController);
  return ctrl.stream;
});

final isSimulatingProvider = Provider<bool>((ref) {
  return ref.watch(simulationProvider).isRunning;
});
