class ScenarioDevice {
  final String deviceName;
  final double hoursPerDay;
  final String timeSlot;

  const ScenarioDevice({
    required this.deviceName,
    required this.hoursPerDay,
    required this.timeSlot,
  });

  factory ScenarioDevice.fromJson(Map<String, dynamic> json) => ScenarioDevice(
        deviceName: json['deviceName'] as String? ?? '',
        hoursPerDay: (json['hoursPerDay'] as num?)?.toDouble() ?? 0.0,
        timeSlot: json['timeSlot'] as String? ?? '',
      );
}

class EnergyScenario {
  final String name;
  final String emoji;
  final String description;
  final double predictedCost;
  final double savingsEGP;
  final List<ScenarioDevice> devices;

  const EnergyScenario({
    required this.name,
    required this.emoji,
    required this.description,
    required this.predictedCost,
    required this.savingsEGP,
    required this.devices,
  });

  factory EnergyScenario.fromJson(Map<String, dynamic> json) => EnergyScenario(
        name: json['name'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '⚡',
        description: json['description'] as String? ?? '',
        predictedCost: (json['predictedCost'] as num?)?.toDouble() ?? 0.0,
        savingsEGP: (json['savingsEGP'] as num?)?.toDouble() ?? 0.0,
        devices: (json['devices'] as List<dynamic>?)
                ?.map((d) =>
                    ScenarioDevice.fromJson(d as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
