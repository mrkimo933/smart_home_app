// lib/features/devices/widgets/device_edit_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/device.dart';
import '../../../providers/devices_provider.dart';

class DeviceEditDialog extends ConsumerStatefulWidget {
  final Device device;

  const DeviceEditDialog({super.key, required this.device});

  @override
  ConsumerState<DeviceEditDialog> createState() => _DeviceEditDialogState();
}

class _DeviceEditDialogState extends ConsumerState<DeviceEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _wattageController;
  late String _selectedIcon;
  late DevicePriority _priority;

  final List<String> _icons = ['lamp', 'ac', 'tv', 'fan', 'fridge', 'washer', 'pc', 'router'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.device.name);
    _wattageController = TextEditingController(text: widget.device.wattage.toString());
    _selectedIcon = widget.device.icon;
    _priority = widget.device.priority;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _wattageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Edit Device', style: TextStyle(color: AppColors.textPrimary)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Device Name',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _wattageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Wattage (W)',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 24),
            const Text('Icon', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _icons.length,
                itemBuilder: (context, index) {
                  final icon = _icons[index];
                  final isSelected = _selectedIcon == icon;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = icon),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryBlue : Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _buildIcon(icon, isSelected),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            const Text('Priority', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            Row(
              children: [
                _priorityChip(DevicePriority.essential, 'Essential'),
                _priorityChip(DevicePriority.normal, 'Normal'),
                _priorityChip(DevicePriority.nonEssential, 'Low'),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () {
            final updated = widget.device.copyWith(
              name: _nameController.text,
              wattage: double.tryParse(_wattageController.text) ?? 100.0,
              icon: _selectedIcon,
              priority: _priority,
            );
            ref.read(devicesProvider.notifier).updateDevice(updated);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _priorityChip(DevicePriority priority, String label) {
    final isSelected = _priority == priority;
    return GestureDetector(
      onTap: () => setState(() => _priority = priority),
      child: Container(
        margin: const EdgeInsets.only(top: 8, right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue.withAlpha((0.2 * 255).toInt()) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppColors.primaryBlue : Colors.white10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(String iconName, bool active) {
    IconData data;
    switch (iconName) {
      case 'lamp': data = Icons.light_outlined; break;
      case 'ac': data = Icons.air_rounded; break;
      case 'tv': data = Icons.tv_rounded; break;
      case 'fan': data = Icons.mode_fan_off_rounded; break;
      case 'fridge': data = Icons.kitchen_rounded; break;
      case 'washer': data = Icons.local_laundry_service_rounded; break;
      case 'pc': data = Icons.computer_rounded; break;
      case 'router': data = Icons.router_rounded; break;
      default: data = Icons.device_unknown_rounded;
    }
    return Icon(data, color: active ? Colors.white : AppColors.textSecondary, size: 20);
  }
}
