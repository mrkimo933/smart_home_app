import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device.dart';
import '../services/database_service.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

class DevicesNotifier extends StateNotifier<List<Device>> {
  final DatabaseService _dbService;

  DevicesNotifier(this._dbService) : super([]) {
    // Initial state with some defaults while we wait for DB
    state = _getDefaultDevices();
    loadDevices();
  }

  List<Device> _getDefaultDevices() {
    return [
      Device(id: 1, name: 'Air Conditioner', icon: 'ac_unit', relayId: 1, wattage: 2000.0, isOn: false, priority: DevicePriority.normal, totalOnMinutesToday: 0),
      Device(id: 2, name: 'Water Heater', icon: 'hot_tub', relayId: 2, wattage: 3000.0, isOn: false, priority: DevicePriority.normal, totalOnMinutesToday: 0),
      Device(id: 3, name: 'Lighting', icon: 'lightbulb', relayId: 3, wattage: 100.0, isOn: false, priority: DevicePriority.essential, totalOnMinutesToday: 0),
      Device(id: 4, name: 'Washing Machine', icon: 'local_laundry_service', relayId: 4, wattage: 1500.0, isOn: false, priority: DevicePriority.nonEssential, totalOnMinutesToday: 0),
    ];
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
