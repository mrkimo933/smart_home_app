// lib/features/devices/screens/devices_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../providers/devices_provider.dart';
import '../../../providers/mqtt_provider.dart';
import '../../../models/device.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppStrings.getString(language, 'devices'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.05 * 255).toInt()),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.add_rounded, color: AppColors.primaryBlue),
              onPressed: () => _showAddDeviceSheet(context),
            ),
          ),
        ],
      ),
      body: devicesAsync.isEmpty
          ? _buildEmptyState(context)
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _buildHeaderSummary(devicesAsync),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      childAspectRatio: 0.82,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => DeviceCard(
                        device: devicesAsync[index],
                        isMqttConnected: isConnectedAsync.value ?? false,
                      ),
                      childCount: devicesAsync.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
    );
  }

  void _showAddDeviceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DeviceEditDialog(),
    );
  }

  // void _showEditDeviceSheet(BuildContext context, Device device) {
  //   showModalBottomSheet(
  //     context: context,
  //     isScrollControlled: true,
  //     backgroundColor: Colors.transparent,
  //     builder: (context) => DeviceEditDialog(device: device),
  //   );
  // }

  Widget _buildHeaderSummary(List<Device> devices) {
    final activeCount = devices.where((d) => d.isOn).length;
    final totalPower = devices.where((d) => d.isOn).fold(0.0, (sum, d) => sum + d.wattage);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryBlue,
            AppColors.primaryBlue.withAlpha((0.7 * 255).toInt()),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withAlpha((0.3 * 255).toInt()),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryStat(
                '${devices.length}',
                'Devices',
                Icons.devices_other_rounded,
              ),
              _buildSummaryStat(
                '$activeCount',
                'Active',
                Icons.power_rounded,
              ),
              _buildSummaryStat(
                '${totalPower.toInt()}W',
                'Usage',
                Icons.bolt_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.device_hub_rounded,
            size: 80,
            color: Colors.white.withAlpha((0.1 * 255).toInt()),
          ),
          const SizedBox(height: 16),
          Text(
            'No devices added yet',
            style: TextStyle(
              color: Colors.white.withAlpha((0.5 * 255).toInt()),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => _showAddDeviceSheet(context),
            child: const Text('Add Your First Device'),
          ),
        ],
      ),
    );
  }
}
