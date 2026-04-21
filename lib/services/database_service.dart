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
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'smart_home_monitor.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
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
        relay_id INTEGER
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

    await _initDefaultDevices(db);
  }

  Future<void> _initDefaultDevices(Database db) async {
    final devices = Device.defaultDevices;
    for (var device in devices) {
      await db.insert('devices', {
        'id': device.id,
        'name': device.name,
        'icon': device.icon,
        'wattage': device.wattage,
        'is_on': device.isOn ? 1 : 0,
        'priority': device.priority.name,
        'total_on_minutes_today': device.totalOnMinutesToday,
        'relay_id': device.relayId,
      });
    }
  }

  // Public init for checking if empty
  Future<void> initDefaultDevices() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('devices');
    if (maps.isEmpty) {
      await _initDefaultDevices(db);
    }
  }

  // Devices
  Future<List<Device>> getDevices() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('devices');
    return List.generate(maps.length, (i) {
      return Device(
        id: maps[i]['id'],
        name: maps[i]['name'],
        icon: maps[i]['icon'],
        wattage: maps[i]['wattage'],
        isOn: maps[i]['is_on'] == 1,
        priority: DevicePriority.values.firstWhere(
          (e) => e.name == maps[i]['priority'],
          orElse: () => DevicePriority.normal,
        ),
        totalOnMinutesToday: maps[i]['total_on_minutes_today'],
        relayId: maps[i]['relay_id'],
      );
    });
  }

  Future<void> insertDevice(Device device) async {
    final db = await database;
    await db.insert('devices', {
      'id': device.id,
      'name': device.name,
      'icon': device.icon,
      'wattage': device.wattage,
      'is_on': device.isOn ? 1 : 0,
      'priority': device.priority.name,
      'total_on_minutes_today': device.totalOnMinutesToday,
      'relay_id': device.relayId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateDevice(Device device) async {
    final db = await database;
    await db.update(
      'devices',
      {
        'name': device.name,
        'icon': device.icon,
        'wattage': device.wattage,
        'is_on': device.isOn ? 1 : 0,
        'priority': device.priority.name,
        'total_on_minutes_today': device.totalOnMinutesToday,
        'relay_id': device.relayId,
      },
      where: 'id = ?',
      whereArgs: [device.id],
    );
  }

  // Sensor History
  Future<void> insertSensorData(SensorData data) async {
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
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sensor_history',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy: 'timestamp ASC',
    );
    return List.generate(maps.length, (i) {
      return SensorData(
        voltage: maps[i]['voltage'],
        current: maps[i]['current'],
        power: maps[i]['power'],
        kwh: maps[i]['kwh'],
        timestamp: DateTime.parse(maps[i]['timestamp']),
      );
    });
  }

  Future<void> deleteOldRecords() async {
    final db = await database;
    final sixtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    await db.delete(
      'sensor_history',
      where: 'timestamp < ?',
      whereArgs: [sixtyDaysAgo.toIso8601String()],
    );
  }

  // Consumption Records
  Future<void> insertConsumptionRecord(ConsumptionRecord record) async {
    final db = await database;
    await db.insert('consumption_records', {
      'kwh': record.kwh,
      'cost_egp': record.costEGP,
      'date': record.date.toIso8601String(),
      'device_id': record.deviceId,
    });
  }

  Future<List<ConsumptionRecord>> getConsumptionByRange(DateTime from, DateTime to) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'consumption_records',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy: 'date ASC',
    );
    return List.generate(maps.length, (i) {
      return ConsumptionRecord(
        id: maps[i]['id'],
        kwh: maps[i]['kwh'],
        costEGP: maps[i]['cost_egp'],
        date: DateTime.parse(maps[i]['date']),
        deviceId: maps[i]['device_id'],
      );
    });
  }

  Future<double> getTotalKwhThisMonth() async {
    final db = await database;
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
    
    final result = await db.rawQuery(
      'SELECT SUM(kwh) as total FROM consumption_records WHERE date >= ?',
      [firstDayOfMonth],
    );
    
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalCostThisMonth() async {
    final db = await database;
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
    
    final result = await db.rawQuery(
      'SELECT SUM(cost_egp) as total FROM consumption_records WHERE date >= ?',
      [firstDayOfMonth],
    );
    
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // Schedules
  Future<List<Schedule>> getSchedules() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('schedules');
    return List.generate(maps.length, (i) => Schedule.fromMap(maps[i]));
  }

  Future<int> insertSchedule(Schedule schedule) async {
    final db = await database;
    return await db.insert('schedules', schedule.toMap());
  }

  Future<void> updateSchedule(Schedule schedule) async {
    final db = await database;
    await db.update(
      'schedules',
      schedule.toMap(),
      where: 'id = ?',
      whereArgs: [schedule.id],
    );
  }

  Future<void> deleteSchedule(int id) async {
    final db = await database;
    await db.delete(
      'schedules',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
}
