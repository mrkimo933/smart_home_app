class ConsumptionRecord {
  final int? id;
  final double kwh;
  final double costEGP;
  final DateTime date;
  final int deviceId;

  ConsumptionRecord({
    this.id,
    required this.kwh,
    required this.costEGP,
    required this.date,
    required this.deviceId,
  });

  factory ConsumptionRecord.fromJson(Map<String, dynamic> json) {
    return ConsumptionRecord(
      id: json['id'] as int?,
      kwh: (json['kwh'] as num).toDouble(),
      costEGP: (json['costEGP'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      deviceId: json['deviceId'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kwh': kwh,
      'costEGP': costEGP,
      'date': date.toIso8601String(),
      'deviceId': deviceId,
    };
  }

  factory ConsumptionRecord.fromMap(Map<String, dynamic> map) {
    return ConsumptionRecord(
      id: map['id'] as int?,
      kwh: (map['kwh'] as num).toDouble(),
      costEGP: (map['costEGP'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      deviceId: map['deviceId'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kwh': kwh,
      'costEGP': costEGP,
      'date': date.toIso8601String(),
      'deviceId': deviceId,
    };
  }
}
