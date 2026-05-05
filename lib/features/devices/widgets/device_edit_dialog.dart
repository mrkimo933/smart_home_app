// lib/features/devices/widgets/device_edit_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/device.dart';
import '../../../providers/devices_provider.dart';

class DeviceEditDialog extends ConsumerStatefulWidget {
  final Device? device;

  const DeviceEditDialog({super.key, this.device});

  @override
  ConsumerState<DeviceEditDialog> createState() => _DeviceEditDialogState();
}

class _DeviceEditDialogState extends ConsumerState<DeviceEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _wattageController;
  late TextEditingController _budgetController;
  late TextEditingController _maxCurrentController;
  String _selectedIcon = 'lamp';
  DevicePriority _priority = DevicePriority.normal;
  int _selectedRelay = 1;
  bool _hasBudget = false;
  bool _autoOffOnBudget = false;

  final List<String> _icons = [
    'lamp', 'ac', 'tv', 'fan', 'fridge', 'washer', 'pc', 'router',
    'heater', 'microwave', 'water_heater', 'coffee_maker'
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.device;
    _nameController = TextEditingController(text: d?.name ?? '');
    _wattageController = TextEditingController(text: d?.wattage.toString() ?? '');
    _budgetController = TextEditingController(
        text: d?.monthlyBudgetEGP?.toStringAsFixed(0) ?? '');
    _maxCurrentController = TextEditingController(
        text: d?.maxCurrentAmps.toStringAsFixed(1) ?? '');
    _selectedIcon = d?.icon ?? 'lamp';
    _priority = d?.priority ?? DevicePriority.normal;
    _selectedRelay = d?.relayId ?? 1;
    _hasBudget = d?.monthlyBudgetEGP != null;
    _autoOffOnBudget = d?.autoOffOnBudget ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _wattageController.dispose();
    _budgetController.dispose();
    _maxCurrentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.device == null ? 'Add New Device' : 'Edit Device',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                if (widget.device != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _handleDelete(context),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            _buildTextField(
              controller: _nameController,
              label: 'Device Name',
              icon: Icons.label_important_outline_rounded,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _wattageController,
              label: 'Wattage (W)',
              icon: Icons.bolt_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _maxCurrentController,
              label: 'Max Safe Current (A)',
              icon: Icons.electrical_services_rounded,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 32),
            // ── Icon picker ─────────────────────────────────────────────────
            const Text('Select Icon',
                style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: _icons.length,
                itemBuilder: (context, index) {
                  final icon = _icons[index];
                  final isSelected = _selectedIcon == icon;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedIcon = icon;
                      // Update max current default when icon changes
                      if (_maxCurrentController.text.isEmpty) {
                        _maxCurrentController.text =
                            Device.defaultMaxCurrentForIcon(icon).toStringAsFixed(1);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryBlue
                            : Colors.white.withAlpha((0.05 * 255).toInt()),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: isSelected
                                ? Colors.white30
                                : Colors.transparent),
                      ),
                      child: _buildIcon(icon, isSelected),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            // ── Priority ────────────────────────────────────────────────────
            const Text('Priority Level',
                style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            Row(
              children: [
                _priorityChip(DevicePriority.essential, 'Essential', Icons.priority_high_rounded),
                const SizedBox(width: 12),
                _priorityChip(DevicePriority.normal, 'Normal', Icons.check_circle_outline_rounded),
                const SizedBox(width: 12),
                _priorityChip(DevicePriority.nonEssential, 'Low', Icons.low_priority_rounded),
              ],
            ),
            const SizedBox(height: 32),
            // ── Relay ID ────────────────────────────────────────────────────
            const Text('Relay ID (1-8)',
                style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: GridView.count(
                crossAxisCount: 2,
                scrollDirection: Axis.horizontal,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [1, 2, 3, 4, 5, 6, 7, 8].map((id) {
                  final isSelected = _selectedRelay == id;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedRelay = id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryBlue
                            : Colors.white.withAlpha((0.05 * 255).toInt()),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: isSelected
                                ? Colors.white30
                                : Colors.transparent),
                      ),
                      child: Center(
                        child: Text(
                          id.toString(),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white38,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 32),
            // ── Feature 3: Per-Device Budget Section ────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((0.04 * 255).toInt()),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: _hasBudget
                        ? AppColors.primaryBlue.withAlpha((0.5 * 255).toInt())
                        : Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Monthly Device Budget',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            fontWeight: FontWeight.w500),
                      ),
                      Switch(
                        value: _hasBudget,
                        onChanged: (val) => setState(() {
                          _hasBudget = val;
                          if (!val) _autoOffOnBudget = false;
                        }),
                        activeThumbColor: AppColors.primaryBlue,
                        activeTrackColor:
                            AppColors.primaryBlue.withAlpha((0.3 * 255).toInt()),
                      ),
                    ],
                  ),
                  if (_hasBudget) ...[
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _budgetController,
                      label: 'Budget (EGP / month)',
                      icon: Icons.account_balance_wallet_rounded,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Auto turn off when reached',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                        Switch(
                          value: _autoOffOnBudget,
                          onChanged: (val) =>
                              setState(() => _autoOffOnBudget = val),
                          activeThumbColor: Colors.orange,
                          activeTrackColor:
                              Colors.orange.withAlpha((0.3 * 255).toInt()),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 48),
            // ── Save / Delete ────────────────────────────────────────────────
            Row(
              children: [
                if (widget.device != null) ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleDelete(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.redAccent.withAlpha((0.1 * 255).toInt()),
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        side: const BorderSide(color: Colors.redAccent),
                      ),
                      child: const Text('Delete'),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      elevation: 8,
                      shadowColor:
                          AppColors.primaryBlue.withAlpha((0.5 * 255).toInt()),
                    ),
                    child: Text(
                      widget.device == null ? 'Add Device' : 'Save Changes',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: AppColors.primaryBlue, size: 22),
        fillColor: Colors.white.withAlpha((0.05 * 255).toInt()),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1),
        ),
      ),
    );
  }

  void _handleSave() {
    if (_nameController.text.isEmpty || _wattageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    final double wattage = double.tryParse(_wattageController.text) ?? 0;
    final double? budget =
        _hasBudget ? double.tryParse(_budgetController.text) : null;
    final double? maxCurrent =
        double.tryParse(_maxCurrentController.text);

    if (widget.device == null) {
      final newDevice = Device(
        id: DateTime.now().millisecondsSinceEpoch,
        name: _nameController.text,
        wattage: wattage,
        icon: _selectedIcon,
        isOn: false,
        priority: _priority,
        totalOnMinutesToday: 0,
        relayId: _selectedRelay,
        monthlyBudgetEGP: budget,
        autoOffOnBudget: _autoOffOnBudget,
        maxCurrentAmps: maxCurrent,
      );
      ref.read(devicesProvider.notifier).addDevice(newDevice);
    } else {
      final updated = widget.device!.copyWith(
        name: _nameController.text,
        wattage: wattage,
        icon: _selectedIcon,
        priority: _priority,
        relayId: _selectedRelay,
        monthlyBudgetEGP: budget,
        autoOffOnBudget: _autoOffOnBudget,
        maxCurrentAmps: maxCurrent,
      );
      ref.read(devicesProvider.notifier).updateDevice(updated);
    }
    Navigator.pop(context);
  }

  Future<void> _handleDelete(BuildContext context) async {
    final navigator = Navigator.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardColor,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Device?',
            style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this device?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      ref.read(devicesProvider.notifier).deleteDevice(widget.device!.id);
      navigator.pop();
    }
  }

  Widget _priorityChip(DevicePriority priority, String label, IconData icon) {
    final isSelected = _priority == priority;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _priority = priority),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryBlue.withAlpha((0.2 * 255).toInt())
                : Colors.white.withAlpha((0.05 * 255).toInt()),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isSelected ? AppColors.primaryBlue : Colors.transparent),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected
                      ? AppColors.primaryBlue
                      : Colors.white38,
                  size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(String iconName, bool isSelected) {
    IconData data;
    switch (iconName) {
      case 'lamp':
        data = Icons.lightbulb_outline_rounded;
        break;
      case 'ac':
        data = Icons.ac_unit_rounded;
        break;
      case 'tv':
        data = Icons.tv_rounded;
        break;
      case 'fan':
        data = Icons.air_rounded;
        break;
      case 'fridge':
        data = Icons.kitchen_rounded;
        break;
      case 'washer':
        data = Icons.local_laundry_service_rounded;
        break;
      case 'pc':
        data = Icons.computer_rounded;
        break;
      case 'router':
        data = Icons.router_rounded;
        break;
      case 'heater':
        data = Icons.waves_rounded;
        break;
      case 'water_heater':
        data = Icons.hot_tub_rounded;
        break;
      case 'microwave':
        data = Icons.microwave_rounded;
        break;
      case 'coffee_maker':
        data = Icons.coffee_maker_rounded;
        break;
      default:
        data = Icons.device_unknown_rounded;
    }
    return Icon(data, color: isSelected ? Colors.white : Colors.white38, size: 28);
  }
}
