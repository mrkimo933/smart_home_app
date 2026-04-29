// lib/features/devices/screens/devices_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../providers/devices_provider.dart';
import '../../../providers/mqtt_provider.dart';
import '../widgets/device_card.dart';
import '../widgets/device_edit_dialog.dart';

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(devicesProvider);
    final isConnectedAsync = ref.watch(connectionStatusProvider);
    final language = ref.watch(languageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.getString(language, 'devices')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => showDialog(
              context: context,
              builder: (context) => const DeviceEditDialog()
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (context) => const DeviceEditDialog()
        ),
        backgroundColor: AppColors.primaryBlue,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: devicesAsync.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primaryBlue, AppColors.primaryBlue.withAlpha((0.7 * 255).toInt())],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryBlue.withAlpha((0.3 * 255).toInt()),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _buildSummaryItem('${devicesAsync.where((d) => d.isOn).length} / ${devicesAsync.length}', 'Active Devices'),
                        Container(height: 40, width: 1, color: Colors.white24),
                        _buildSummaryItem('${devicesAsync.where((d) => d.isOn).fold(0.0, (sum, d) => sum + d.wattage).toInt()} W', 'Total Load'),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: devicesAsync.length,
                    itemBuilder: (context, index) => DeviceCard(
                      device: devicesAsync[index],
                      isMqttConnected: isConnectedAsync.value ?? false,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
