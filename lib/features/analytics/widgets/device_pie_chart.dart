import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/device.dart';

class DevicePieChart extends StatelessWidget {
  final List<Device> devices;

  const DevicePieChart({
    super.key, 
    required this.devices,
  });

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد أجهزة مضافة',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    // Mock breakdown: In a real app, calculate total kWh consumed per device
    // Here we use wattage as a simple proxy for visualization
    double totalWattage = devices.fold(0, (sum, item) => sum + item.wattage);

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 4,
              centerSpaceRadius: 40,
              sections: devices.asMap().entries.map((e) {
                final index = e.key;
                final device = e.value;
                final percentage = (device.wattage / totalWattage) * 100;
                
                return PieChartSectionData(
                  color: _getDeviceColor(index),
                  value: device.wattage,
                  title: '${percentage.toStringAsFixed(0)}%',
                  radius: 50,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: devices.asMap().entries.map((e) {
            return _LegendItem(
              color: _getDeviceColor(e.key),
              text: e.value.name,
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _getDeviceColor(int index) {
    final colors = [
      AppColors.primaryBlue,
      AppColors.accentGreen,
      const Color(0xFFF72585), // Neon pink
      const Color(0xFF7209B7), // Deep purple
      const Color(0xFF4CC9F0), // Sky blue
    ];
    return colors[index % colors.length];
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
