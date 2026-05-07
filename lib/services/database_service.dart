import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/sensor_data.dart';
import '../models/device.dart';
import '../models/consumption_record.dart';
import '../models/schedule.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    if (kIsWeb) throw UnsupportedError('DB not available on web');
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'smart_home_monitor.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE devices (
        id INTEGER PRIMARY KEY,
        name TEXT,
        icon TEXT,
        wattage REAL,
        is_on INTEGER,
        priority TEXT,
        total_on_minutes_today INTEGER,
        relay_id INTEGER,
        monthly_budget_egp REAL,
        auto_off_on_budget INTEGER DEFAULT 0,
        max_current_amps REAL,
        timer_minutes INTEGER,
        timer_start_time TEXT,
        run_budget_egp REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE sensor_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        voltage REAL,
        current REAL,
        power REAL,
        kwh REAL,
        timestamp TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE consumption_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kwh REAL,
        cost_egp REAL,
        date TEXT,
        device_id INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id INTEGER,
        device_name TEXT,
        on_hour INTEGER,
        on_minute INTEGER,
        off_hour INTEGER,
        off_minute INTEGER,
        repeat_days TEXT,
        is_enabled INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE overcurrent_incidents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id INTEGER,
        device_name TEXT,
        current REAL,
        max_current REAL,
        timestamp TEXT
      )
    ''');

    await _initDefaultDevices(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new device fields
      final columns = [
        'ALTER TABLE devices ADD COLUMN monthly_budget_egp REAL',
        'ALTER TABLE devices ADD COLUMN auto_off_on_budget INTEGER DEFAULT 0',
        'ALTER TABLE devices ADD COLUMN max_current_amps REAL',
        'ALTER TABLE devices ADD COLUMN timer_minutes INTEGER',
        'ALTER TABLE devices ADD COLUMN timer_start_time TEXT',
        'ALTER TABLE devices ADD COLUMN run_budget_egp REAL',
      ];
      for (final sql in columns) {
        try {
          await db.execute(sql);
        } catch (_) {
          // Column may already exist
        }
      }

      // Create overcurrent incidents table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS overcurrent_incidents (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          device_id INTEGER,
          device_name TEXT,
          current REAL,
          max_current REAL,
          timestamp TEXT
        )
      ''');
    }
  }

  Future<void> _initDefaultDevices(Database db) async {
    final devices = Device.defaultDevices;
    for (var device in devices) {
      await db.insert('devices', _deviceToMap(device));
    }
  }

  Map<String, dynamic> _deviceToMap(Device device) {
    return {
      'id': device.id,
      'name': device.name,
      'icon': device.icon,
      'wattage': device.wattage,
      'is_on': device.isOn ? 1 : 0,
      'priority': device.priority.name,
      'total_on_minutes_today': device.totalOnMinutesToday,
      'relay_id': device.relayId,
      'monthly_budget_egp': device.monthlyBudgetEGP,
      'auto_off_on_budget': device.autoOffOnBudget ? 1 : 0,
      'max_current_amps': device.maxCurrentAmps,
      'timer_minutes': device.timerMinutes,
      'timer_start_time': device.timerStartTime?.toIso8601String(),
      'run_budget_egp': device.runBudgetEGP,
    };
  }

  Device _deviceFromMap(Map<String, dynamic> m) {
    return Device(
      id: m['id'] as int,
      name: m['name'] as String,
      icon: m['icon'] as String,
      wattage: (m['wattage'] as num).toDouble(),
      isOn: m['is_on'] == 1,
      priority: DevicePriority.values.firstWhere(
        (e) => e.name == m['priority'],
        orElse: () => DevicePriority.normal,
      ),
      totalOnMinutesToday: m['total_on_minutes_today'] as int,
      relayId: m['relay_id'] as int,
      monthlyBudgetEGP: m['monthly_budget_egp'] != null
          ? (m['monthly_budget_egp'] as num).toDouble()
          : null,
      autoOffOnBudget: m['auto_off_on_budget'] == 1,
      maxCurrentAmps: m['max_current_amps'] != null
          ? (m['max_current_amps'] as num).toDouble()
          : null,
      timerMinutes: m['timer_minutes'] as int?,
      timerStartTime: m['timer_start_time'] != null
          ? DateTime.tryParse(m['timer_start_time'] as String)
          : null,
      runBudgetEGP: m['run_budget_egp'] != null
          ? (m['run_budget_egp'] as num).toDouble()
          : null,
    );
  }

  // Public init for checking if empty
  Future<void> initDefaultDevices() async {
    if (kIsWeb) return;
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('devices');
    if (maps.isEmpty) {
      await _initDefaultDevices(db);
    }
  }

  // Devices
  Future<List<Device>> getDevices() async {
    if (kIsWeb) return Device.defaultDevices;
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('devices');
    return maps.map(_deviceFromMap).toList();
  }

  Future<void> insertDevice(Device device) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert(
      'devices',
      _deviceToMap(device),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateDevice(Device device) async {
    if (kIsWeb) return;
    final db = await database;
    final map = _deviceToMap(device)..remove('id');
    await db.update(
      'devices',
      map,
      where: 'id = ?',
      whereArgs: [device.id],
    );
  }

  Future<void> deleteDevice(int id) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete('devices', where: 'id = ?', whereArgs: [id]);
  }

  // Sensor History
  Future<void> insertSensorData(SensorData data) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert('sensor_history', {
      'voltage': data.voltage,
      'current': data.current,
      'power': data.power,
      'kwh': data.kwh,
      'timestamp': data.timestamp.toIso8601String(),
    });
  }

  Future<List<SensorData>> getSensorHistory(DateTime from, DateTime to) async {
    if (kIsWeb) return [];
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sensor_history',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy: 'timestamp ASC',
    );
    return List.generate(maps.length, (i) {
      return SensorData(
        voltage: maps[i]['voltage'] as double,
        current: maps[i]['current'] as double,
        power: maps[i]['power'] as double,
        kwh: maps[i]['kwh'] as double,
        timestamp: DateTime.parse(maps[i]['timestamp'] as String),
      );
    });
  }

  Future<void> deleteOldRecords() async {
    if (kIsWeb) return;
    final db = await database;
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    await db.delete(
      'sensor_history',
      where: 'timestamp < ?',
      whereArgs: [thirtyDaysAgo.toIso8601String()],
    );
  }

  // Consumption Records
  Future<void> insertConsumptionRecord(ConsumptionRecord record) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert('consumption_records', {
      'kwh': record.kwh,
      'cost_egp': record.costEGP,
      'date': record.date.toIso8601String(),
      'device_id': record.deviceId,
    });
  }

  Future<List<ConsumptionRecord>> getConsumptionByRange(
      DateTime from, DateTime to) async {
    if (kIsWeb) return [];
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'consumption_records',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy: 'date ASC',
    );
    return List.generate(maps.length, (i) {
      return ConsumptionRecord(
        id: maps[i]['id'] as int,
        kwh: (maps[i]['kwh'] as num).toDouble(),
        costEGP: (maps[i]['cost_egp'] as num).toDouble(),
        date: DateTime.parse(maps[i]['date'] as String),
        deviceId: maps[i]['device_id'] as int,
      );
    });
  }

  Future<double> getTotalKwhThisMonth() async {
    if (kIsWeb) return 0.0;
    final db = await database;
    final now = DateTime.now();
    final firstDayOfMonth =
        DateTime(now.year, now.month, 1).toIso8601String();
    final result = await db.rawQuery(
      'SELECT SUM(kwh) as total FROM consumption_records WHERE date >= ?',
      [firstDayOfMonth],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalCostThisMonth() async {
    if (kIsWeb) return 0.0;
    final db = await database;
    final now = DateTime.now();
    final firstDayOfMonth =
        DateTime(now.year, now.month, 1).toIso8601String();
    final result = await db.rawQuery(
      'SELECT SUM(cost_egp) as total FROM consumption_records WHERE date >= ?',
      [firstDayOfMonth],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // Get overcurrent incidents
  Future<List<Map<String, dynamic>>> getOvercurrentIncidents() async {
    if (kIsWeb) return [];
    final db = await database;
    return await db.query(
      'overcurrent_incidents',
      orderBy: 'timestamp DESC',
      limit: 100,
    );
  }

  // Overcurrent incidents log
  Future<void> logOvercurrentIncident({
    required int deviceId,
    required String deviceName,
    required double current,
    required double maxCurrent,
  }) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert('overcurrent_incidents', {
      'device_id': deviceId,
      'device_name': deviceName,
      'current': current,
      'max_current': maxCurrent,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // Schedules
  Future<List<Schedule>> getSchedules() async {
    if (kIsWeb) return [];
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('schedules');
    return List.generate(maps.length, (i) => Schedule.fromMap(maps[i]));
  }

  Future<int> insertSchedule(Schedule schedule) async {
    if (kIsWeb) return 0;
    final db = await database;
    return await db.insert('schedules', schedule.toMap());
  }

  Future<void> updateSchedule(Schedule schedule) async {
    if (kIsWeb) return;
    final db = await database;
    await db.update(
      'schedules',
      schedule.toMap(),
      where: 'id = ?',
      whereArgs: [schedule.id],
    );
  }

  Future<void> deleteSchedule(int id) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete('schedules', where: 'id = ?', whereArgs: [id]);
  }
}
