// lib/features/devices/widgets/device_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/device.dart';
import '../../../providers/mqtt_provider.dart';
import '../../../providers/devices_provider.dart';
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
      default: return Icons.device_unknown_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool active = device.isOn;

    return Dismissible(
      key: Key(device.id.toString()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Device?'),
            content: const Text('Are you sure you want to delete this device?'),
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
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: GestureDetector(
        onLongPress: () => showDialog(
          context: context,
          builder: (context) => DeviceEditDialog(device: device),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: active ? AppColors.primaryBlue.withAlpha((0.1 * 255).toInt()) : AppColors.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: active ? AppColors.primaryBlue.withAlpha((0.5 * 255).toInt()) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    _getIcon(device.icon),
                    color: active ? AppColors.primaryBlue : AppColors.textSecondary,
                    size: 32,
                  ),
                  Switch(
                    value: device.isOn,
                    onChanged: isMqttConnected 
                      ? (val) {
                          ref.read(mqttControllerProvider).toggleRelay(device.id, val);
                          ref.read(devicesProvider.notifier).toggleDevice(device.id, val);
                        }
                      : null,
                    activeThumbColor: AppColors.primaryBlue,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                device.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                active ? '${device.wattage.toInt()} W' : 'OFF',
                style: TextStyle(
                  color: active ? AppColors.accentGreen : AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${(device.totalOnMinutesToday / 60).floor()}:${(device.totalOnMinutesToday % 60).toString().padLeft(2, '0')} h',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
