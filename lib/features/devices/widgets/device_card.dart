// lib/features/devices/widgets/device_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/device.dart';
import '../../../providers/mqtt_provider.dart';
import '../../../providers/devices_provider.dart';
import '../../../core/utils/electricity_calculator.dart';
import 'device_edit_dialog.dart';

class DeviceCard extends ConsumerWidget {
  final Device device;
  final bool isMqttConnected;

  const DeviceCard({
    super.key,
    required this.device,
    required this.isMqttConnected,
  });

  IconData _getIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'lamp': return Icons.light_outlined;
      case 'ac': return Icons.air_rounded;
      case 'tv': return Icons.tv_rounded;
      case 'fan': return Icons.mode_fan_off_rounded;
      case 'fridge': return Icons.kitchen_rounded;
      case 'washer': return Icons.local_laundry_service_rounded;
      case 'pc': return Icons.computer_rounded;
      case 'router': return Icons.router_rounded;
      case 'heater': return Icons.waves_rounded;
      case 'water_heater': return Icons.hot_tub_rounded;
      case 'microwave': return Icons.microwave_rounded;
      case 'coffee_maker': return Icons.coffee_maker_rounded;
      case 'washing_machine': return Icons.local_laundry_service_rounded;
      default: return Icons.device_unknown_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool active = device.isOn;
    final accentColor = active ? AppColors.primaryBlue : AppColors.textSecondary;

    return Dismissible(
      key: Key(device.id.toString()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Delete Device?', style: TextStyle(color: Colors.white)),
            content: const Text('Are you sure you want to delete this device?', style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        ref.read(devicesProvider.notifier).deleteDevice(device.id);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withAlpha((0.2 * 255).toInt()),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 30),
      ),
      child: GestureDetector(
        onLongPress: () => showDialog(
          context: context,
          builder: (context) => DeviceEditDialog(device: device),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: active ? AppColors.primaryBlue.withAlpha((0.6 * 255).toInt()) : Colors.white10,
              width: 1.5,
            ),
            boxShadow: active ? [
              BoxShadow(
                color: AppColors.primaryBlue.withAlpha((0.2 * 255).toInt()),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              )
            ] : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primaryBlue.withAlpha((0.15 * 255).toInt()) : Colors.white.withAlpha((0.05 * 255).toInt()),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _getIcon(device.icon),
                      color: accentColor,
                      size: 28,
                    ),
                  ),
                  Transform.scale(
                    scale: 0.9,
                    child: Switch(
                      value: device.isOn,
                      activeThumbColor: AppColors.primaryBlue,
                      activeTrackColor: AppColors.primaryBlue.withAlpha((0.765 * 255).toInt()),
                      inactiveThumbColor: Colors.grey,
                      inactiveTrackColor: Colors.white10,
                      onChanged: isMqttConnected 
                        ? (val) {
                            ref.read(mqttControllerProvider).toggleRelay(device.relayId, val);
                            ref.read(devicesProvider.notifier).toggleDevice(device.relayId, val);
                          }
                        : null,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? AppColors.accentGreen : Colors.grey,
                      shape: BoxShape.circle,
                      boxShadow: active ? [
                        BoxShadow(
                          color: AppColors.accentGreen.withAlpha((0.6 * 255).toInt()),
                          blurRadius: 6,
                          spreadRadius: 2,
                        )
                      ] : [],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      device.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${device.wattage.toInt()}W',
                    style: TextStyle(
                      color: Colors.white.withAlpha((0.6 * 255).toInt()),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${ElectricityCalculator.calculateCost(device.wattage / 1000).toStringAsFixed(2)} EGP/hr',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                active ? 'Running: ${_formatMinutes(device.totalOnMinutesToday)}' : 'Total today: ${_formatMinutes(device.totalOnMinutesToday)}',
                style: TextStyle(
                  color: Colors.white.withAlpha((0.4 * 255).toInt()),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (device.totalOnMinutesToday / (8 * 60)).clamp(0.0, 1.0),
                  backgroundColor: Colors.white.withAlpha((0.05 * 255).toInt()),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    active ? AppColors.primaryBlue : Colors.white30,
                  ),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m}m';
  }
}
