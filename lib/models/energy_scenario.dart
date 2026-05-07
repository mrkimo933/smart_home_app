class ScenarioDevice {
  final String deviceName;
  final double hoursPerDay;
  final String bestTimeSlot;
  final double monthlyCost;

  const ScenarioDevice({
    required this.deviceName,
    required this.hoursPerDay,
    required this.bestTimeSlot,
    required this.monthlyCost,
  });

  factory ScenarioDevice.fromJson(Map<String, dynamic> json) => ScenarioDevice(
        deviceName: json['deviceName'] as String? ?? '',
        hoursPerDay: (json['hoursPerDay'] as num?)?.toDouble() ?? 0.0,
        bestTimeSlot: (json['bestTimeSlot'] as String?) ??
            (json['timeSlot'] as String?) ??
            '',
        monthlyCost: (json['monthlyCost'] as num?)?.toDouble() ?? 0.0,
      );
}

class EnergyScenario {
  final String name;
  final String emoji;
  final String description;
  final double predictedMonthlyCost;
  final double savingsEGP;
  final bool withinBudget;
  final List<ScenarioDevice> devices;
  final String tips;

  const EnergyScenario({
    required this.name,
    required this.emoji,
    required this.description,
    required this.predictedMonthlyCost,
    required this.savingsEGP,
    required this.withinBudget,
    required this.devices,
    required this.tips,
  });

  factory EnergyScenario.fromJson(Map<String, dynamic> json) => EnergyScenario(
        name: json['name'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '⚡',
        description: json['description'] as String? ?? '',
        predictedMonthlyCost:
            (json['predictedMonthlyCost'] as num?)?.toDouble() ??
                (json['predictedCost'] as num?)?.toDouble() ??
                0.0,
        savingsEGP: (json['savingsEGP'] as num?)?.toDouble() ?? 0.0,
        withinBudget: json['withinBudget'] as bool? ?? false,
        devices: (json['devices'] as List<dynamic>?)
                ?.map((d) =>
                    ScenarioDevice.fromJson(d as Map<String, dynamic>))
                .toList() ??
            [],
        tips: json['tips'] as String? ?? '',
      );
}
