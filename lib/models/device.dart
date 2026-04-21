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

  Device({
    required this.id,
    required this.name,
    required this.icon,
    required this.wattage,
    required this.isOn,
    required this.priority,
    required this.totalOnMinutesToday,
    required this.relayId,
  });

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
    );
  }

  static List<Device> get defaultDevices => [
        Device(
          id: 1,
          name: "Lamp",
          icon: "lamp",
          wattage: 60,
          isOn: false,
          priority: DevicePriority.normal,
          totalOnMinutesToday: 0,
          relayId: 1,
        ),
        Device(
          id: 2,
          name: "AC",
          icon: "ac",
          wattage: 1500,
          isOn: false,
          priority: DevicePriority.essential,
          totalOnMinutesToday: 0,
          relayId: 2,
        ),
        Device(
          id: 3,
          name: "TV",
          icon: "tv",
          wattage: 150,
          isOn: false,
          priority: DevicePriority.normal,
          totalOnMinutesToday: 0,
          relayId: 3,
        ),
        Device(
          id: 4,
          name: "Fan",
          icon: "fan",
          wattage: 75,
          isOn: false,
          priority: DevicePriority.normal,
          totalOnMinutesToday: 0,
          relayId: 4,
        ),
      ];
}
