const _$sentinel = Object();

enum DevicePriority { essential, normal, nonEssential }

class Device {
  final int id;
  final String name;
  final String icon;
  final double wattage;
  final bool isOn;
  final DevicePriority priority;
  final int totalOnMinutesToday;
  final int relayId;
  // Feature 3: Per-device budget
  final double? monthlyBudgetEGP;
  final bool autoOffOnBudget;
  // Feature 4: Overcurrent protection
  final double maxCurrentAmps;
  // Feature 6 & 7: Device timer
  final int? timerMinutes;
  final DateTime? timerStartTime;
  // For run-by-budget label
  final double? runBudgetEGP;
  // Per-device consumption tracking: timestamp when device was turned ON
  final DateTime? turnedOnAt;

  Device({
    required this.id,
    required this.name,
    required this.icon,
    required this.wattage,
    required this.isOn,
    required this.priority,
    required this.totalOnMinutesToday,
    required this.relayId,
    this.monthlyBudgetEGP,
    this.autoOffOnBudget = false,
    double? maxCurrentAmps,
    this.timerMinutes,
    this.timerStartTime,
    this.runBudgetEGP,
    this.turnedOnAt,
  }) : maxCurrentAmps = maxCurrentAmps ?? _defaultMaxCurrent(icon);

  static double defaultMaxCurrentForIcon(String icon) =>
      _defaultMaxCurrent(icon);

  static double _defaultMaxCurrent(String icon) {
    switch (icon.toLowerCase()) {
      case 'lamp':
      case 'lightbulb':
        return 0.5;
      case 'ac':
      case 'ac_unit':
        return 8.0;
      case 'tv':
        return 1.0;
      case 'fan':
        return 0.5;
      case 'fridge':
      case 'kitchen':
        return 2.0;
      case 'washer':
      case 'washing_machine':
      case 'local_laundry_service':
        return 5.0;
      case 'pc':
      case 'computer':
        return 3.0;
      case 'heater':
      case 'water_heater':
      case 'hot_tub':
        return 13.0;
      case 'microwave':
        return 6.0;
      default:
        return 10.0;
    }
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as int,
      name: json['name'] as String,
      icon: json['icon'] as String,
      wattage: (json['wattage'] as num).toDouble(),
      isOn: json['isOn'] as bool,
      priority: DevicePriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => DevicePriority.normal,
      ),
      totalOnMinutesToday: json['totalOnMinutesToday'] as int,
      relayId: json['relayId'] as int,
      monthlyBudgetEGP: (json['monthlyBudgetEGP'] as num?)?.toDouble(),
      autoOffOnBudget: (json['autoOffOnBudget'] as bool?) ?? false,
      maxCurrentAmps: (json['maxCurrentAmps'] as num?)?.toDouble(),
      timerMinutes: json['timerMinutes'] as int?,
      timerStartTime: json['timerStartTime'] != null
          ? DateTime.tryParse(json['timerStartTime'] as String)
          : null,
      runBudgetEGP: (json['runBudgetEGP'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'wattage': wattage,
      'isOn': isOn,
      'priority': priority.name,
      'totalOnMinutesToday': totalOnMinutesToday,
      'relayId': relayId,
      'monthlyBudgetEGP': monthlyBudgetEGP,
      'autoOffOnBudget': autoOffOnBudget,
      'maxCurrentAmps': maxCurrentAmps,
      'timerMinutes': timerMinutes,
      'timerStartTime': timerStartTime?.toIso8601String(),
      'runBudgetEGP': runBudgetEGP,
    };
  }

  Device copyWith({
    int? id,
    String? name,
    String? icon,
    double? wattage,
    bool? isOn,
    DevicePriority? priority,
    int? totalOnMinutesToday,
    int? relayId,
    Object? monthlyBudgetEGP = _$sentinel,
    bool? autoOffOnBudget,
    double? maxCurrentAmps,
    Object? timerMinutes = _$sentinel,
    Object? timerStartTime = _$sentinel,
    Object? runBudgetEGP = _$sentinel,
    Object? turnedOnAt = _$sentinel,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      wattage: wattage ?? this.wattage,
      isOn: isOn ?? this.isOn,
      priority: priority ?? this.priority,
      totalOnMinutesToday: totalOnMinutesToday ?? this.totalOnMinutesToday,
      relayId: relayId ?? this.relayId,
      monthlyBudgetEGP: identical(monthlyBudgetEGP, _$sentinel)
          ? this.monthlyBudgetEGP
          : monthlyBudgetEGP as double?,
      autoOffOnBudget: autoOffOnBudget ?? this.autoOffOnBudget,
      maxCurrentAmps: maxCurrentAmps ?? this.maxCurrentAmps,
      timerMinutes: identical(timerMinutes, _$sentinel)
          ? this.timerMinutes
          : timerMinutes as int?,
      timerStartTime: identical(timerStartTime, _$sentinel)
          ? this.timerStartTime
          : timerStartTime as DateTime?,
      runBudgetEGP: identical(runBudgetEGP, _$sentinel)
          ? this.runBudgetEGP
          : runBudgetEGP as double?,
      turnedOnAt: identical(turnedOnAt, _$sentinel)
          ? this.turnedOnAt
          : turnedOnAt as DateTime?,
    );
  }

  static List<Device> get defaultDevices => [
        Device(
          id: 1,
          name: "Main Lamp",
          icon: "lamp",
          wattage: 60,
          isOn: false,
          priority: DevicePriority.normal,
          totalOnMinutesToday: 0,
          relayId: 1,
        ),
        Device(
          id: 2,
          name: "Air Conditioner",
          icon: "ac",
          wattage: 1500,
          isOn: false,
          priority: DevicePriority.essential,
          totalOnMinutesToday: 0,
          relayId: 2,
        ),
        Device(
          id: 3,
          name: "Living Room TV",
          icon: "tv",
          wattage: 150,
          isOn: false,
          priority: DevicePriority.nonEssential,
          totalOnMinutesToday: 0,
          relayId: 3,
        ),
        Device(
          id: 4,
          name: "Water Heater",
          icon: "water_heater",
          wattage: 2000,
          isOn: false,
          priority: DevicePriority.normal,
          totalOnMinutesToday: 0,
          relayId: 4,
        ),
        Device(
          id: 5,
          name: "Refrigerator",
          icon: "fridge",
          wattage: 300,
          isOn: true,
          priority: DevicePriority.essential,
          totalOnMinutesToday: 0,
          relayId: 5,
        ),
        Device(
          id: 6,
          name: "Washing Machine",
          icon: "washing_machine",
          wattage: 800,
          isOn: false,
          priority: DevicePriority.normal,
          totalOnMinutesToday: 0,
          relayId: 6,
        ),
        Device(
          id: 7,
          name: "Microwave",
          icon: "microwave",
          wattage: 1200,
          isOn: false,
          priority: DevicePriority.nonEssential,
          totalOnMinutesToday: 0,
          relayId: 7,
        ),
        Device(
          id: 8,
          name: "Coffee Maker",
          icon: "coffee_maker",
          wattage: 900,
          isOn: false,
          priority: DevicePriority.nonEssential,
          totalOnMinutesToday: 0,
          relayId: 8,
        ),
      ];
}
