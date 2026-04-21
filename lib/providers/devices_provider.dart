import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device.dart';
import '../services/database_service.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

class DevicesNotifier extends StateNotifier<List<Device>> {
  final DatabaseService _dbService;

  DevicesNotifier(this._dbService) : super([]) {
    loadDevices();
  }

  Future<void> loadDevices() async {
    final devices = await _dbService.getDevices();
    if (devices.isEmpty) {
      await _dbService.initDefaultDevices();
      final reloaded = await _dbService.getDevices();
      state = reloaded;
    } else {
      state = devices;
    }
  }

  Future<void> updateDevice(Device device) async {
    await _dbService.updateDevice(device);
    state = [
      for (final d in state)
        if (d.id == device.id) device else d
    ];
  }

  Future<void> toggleDevice(int relayId, bool isOn) async {
    final index = state.indexWhere((d) => d.relayId == relayId);
    if (index != -1) {
      final device = state[index].copyWith(isOn: isOn);
      await updateDevice(device);
    }
  }

  Future<void> updateOnTime(int relayId, int minutes) async {
    final index = state.indexWhere((d) => d.relayId == relayId);
    if (index != -1) {
      final device = state[index].copyWith(
        totalOnMinutesToday: state[index].totalOnMinutesToday + minutes,
      );
      await updateDevice(device);
    }
  }
}

final devicesProvider = StateNotifierProvider<DevicesNotifier, List<Device>>((ref) {
  return DevicesNotifier(ref.watch(databaseServiceProvider));
});
