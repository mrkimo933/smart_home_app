class SensorData {
  final double voltage;
  final double current;
  final double power;
  final double kwh;
  final DateTime timestamp;

  SensorData({
    required this.voltage,
    required this.current,
    required this.power,
    required this.kwh,
    required this.timestamp,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      voltage: (json['voltage'] as num).toDouble(),
      current: (json['current'] as num).toDouble(),
      power: (json['power'] as num).toDouble(),
      kwh: (json['kwh'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'voltage': voltage,
      'current': current,
      'power': power,
      'kwh': kwh,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  SensorData copyWith({
    double? voltage,
    double? current,
    double? power,
    double? kwh,
    DateTime? timestamp,
  }) {
    return SensorData(
      voltage: voltage ?? this.voltage,
      current: current ?? this.current,
      power: power ?? this.power,
      kwh: kwh ?? this.kwh,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
