// lib/features/dashboard/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../providers/mqtt_provider.dart';
import '../../../providers/devices_provider.dart';
import '../../../models/device.dart';
// import '../../../core/utils/electricity_calculator.dart';
import '../widgets/power_gauge.dart';
import '../widgets/sensor_card.dart';
import '../widgets/bill_prediction_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sensorDataAsync = ref.watch(sensorDataProvider);
    final isConnectedAsync = ref.watch(connectionStatusProvider);
    final language = ref.watch(languageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.getString(language, 'dashboard')),
        actions: [
          isConnectedAsync.when(
            data: (isConnected) => _ConnectionBadge(isConnected: isConnected),
            loading: () => const _ConnectionBadge(isConnected: false, isConnecting: true),
            error: (_, __) => const _ConnectionBadge(isConnected: false),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          if (isConnectedAsync.hasValue && isConnectedAsync.value == false)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.redAccent,
              child: const Text(
                'Offline - showing last known data. Connect to control.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: sensorDataAsync.when(
              data: (data) => _buildContent(context, data),
              loading: () => _buildLoadingState(context),
              error: (err, stack) => _buildErrorState(context, err.toString(), ref),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, dynamic data) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Consumer(
        builder: (context, ref, child) {
          final devices = ref.watch(devicesProvider);
          // final activeDevices = devices.where((d) => d.isOn).toList();
          final isConnected = ref.watch(connectionStatusProvider).value ?? false;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Good Morning, Kareem 👋',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              StreamBuilder(
                stream: Stream.periodic(const Duration(seconds: 1)),
                builder: (context, snapshot) {
                  return Text(
                    DateFormat('EEEE, MMMM d • hh:mm:ss a').format(DateTime.now()),
                    style: TextStyle(
                      color: Colors.white.withAlpha((0.6 * 255).toInt()),
                      fontSize: 14,
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              _buildTodaysSummaryCard(devices),
              const SizedBox(height: 24),
              Center(child: PowerGauge(watts: data.power)),
              const SizedBox(height: 30),
              Row(
                children: [
                  SensorCard(
                    title: 'Voltage',
                    value: data.voltage.toStringAsFixed(1),
                    unit: 'V',
                    icon: Icons.bolt_rounded,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  SensorCard(
                    title: 'Current',
                    value: data.current.toStringAsFixed(2),
                    unit: 'A',
                    icon: Icons.electric_meter_rounded,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  SensorCard(
                    title: 'Power',
                    value: data.power.toStringAsFixed(1),
                    unit: 'W',
                    icon: Icons.speed_rounded,
                    color: AppColors.primaryBlue,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              BillPredictionCard(currentKwh: data.kwh),
              const SizedBox(height: 24),
              _buildQuickActions(context, ref, isConnected),
              const SizedBox(height: 24),
              _buildQuickDeviceToggles(devices, ref, isConnected),
              const SizedBox(height: 30),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.errorRed, size: 64),
          const SizedBox(height: 16),
          const Text(
            'System Offline',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Last updated few moments ago', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => ref.read(mqttServiceProvider).connect(),
            child: const Text('Retry Connection'),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysSummaryCard(List<Device> devices) {
    final activeCount = devices.where((d) => d.isOn).length;
    // final cost = ElectricityCalculator.calculateCost(kwh);
    
    // ignore: unused_local_variable
    dynamic mostUsedDevice;
    int maxMinutes = -1;
    for (final device in devices) {
      if (device.totalOnMinutesToday > maxMinutes) {
        maxMinutes = device.totalOnMinutesToday;
        mostUsedDevice = device;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.2 * 255).toInt()),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Summary",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryHeaderStat(
                '${devices.length}',
                'Devices',
                Icons.devices_other_rounded,
              ),
              _buildSummaryHeaderStat(
                '$activeCount',
                'Active',
                Icons.power_rounded,
              ),
              _buildSummaryHeaderStat(
                '2.4', // Mocked total kWh for today
                'kWh',
                Icons.bolt_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeaderStat(String value, String label, IconData icon) {
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

  Widget _buildQuickActions(BuildContext context, WidgetRef ref, bool isConnected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Quick Actions",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildQuickActionBtn(
              'Turn Off All', 
              Icons.power_settings_new, 
              Colors.redAccent, 
              () => _confirmAction(context, "Turn off all devices?", () {
                final devices = ref.read(devicesProvider);
                for (var d in devices) {
                  if (d.isOn) {
                    ref.read(mqttControllerProvider).toggleRelay(d.relayId, false);
                    ref.read(devicesProvider.notifier).toggleDevice(d.relayId, false);
                  }
                }
              }),
              isConnected,
            ),
             _buildQuickActionBtn(
              'Essential Only', 
              Icons.priority_high, 
              AppColors.primaryBlue, 
              () => _confirmAction(context, "Turn off non-essential devices?", () {
                final devices = ref.read(devicesProvider);
                for (var d in devices) {
                  if (d.isOn && d.priority != DevicePriority.essential) {
                    ref.read(mqttControllerProvider).toggleRelay(d.relayId, false);
                    ref.read(devicesProvider.notifier).toggleDevice(d.relayId, false);
                  }
                }
              }),
              isConnected,
            ),
             _buildQuickActionBtn(
              'Night Mode', 
              Icons.nightlight_round, 
              Colors.indigoAccent, 
              () => _confirmAction(context, "Activate night mode? (Turns off non-essential + normal)", () {
                final devices = ref.read(devicesProvider);
                for (var d in devices) {
                  if (d.isOn && d.priority != DevicePriority.essential) {
                    ref.read(mqttControllerProvider).toggleRelay(d.relayId, false);
                    ref.read(devicesProvider.notifier).toggleDevice(d.relayId, false);
                  }
                }
              }),
              isConnected,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionBtn(String title, IconData icon, Color color, VoidCallback onTap, bool isEnabled) {
    return Expanded(
      child: GestureDetector(
        onTap: isEnabled ? onTap : null,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isEnabled ? color.withAlpha((0.2 * 255).toInt()) : Colors.grey.withAlpha((0.1 * 255).toInt()),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isEnabled ? color : Colors.transparent),
          ),
          child: Column(
            children: [
              Icon(icon, color: isEnabled ? color : Colors.grey, size: 24),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isEnabled ? Colors.white : Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _confirmAction(BuildContext context, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Action', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
            }, 
            child: const Text('Yes', style: TextStyle(color: AppColors.primaryBlue)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDeviceToggles(List<dynamic> devices, WidgetRef ref, bool isConnected) {
    if (devices.isEmpty) return const SizedBox.shrink();
    
    final topDevices = devices.take(4).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Quick Controls",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.5,
          ),
          itemCount: topDevices.length,
          itemBuilder: (context, index) {
            final device = topDevices[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: device.isOn ? AppColors.primaryBlue : Colors.transparent),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      device.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Switch(
                    value: device.isOn,
                    activeThumbColor: AppColors.primaryBlue,
                    onChanged: isConnected ? (val) {
                      ref.read(mqttControllerProvider).toggleRelay(device.relayId, val);
                      ref.read(devicesProvider.notifier).toggleDevice(device.relayId, val);
                    } : null,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  final bool isConnected;
  final bool isConnecting;

  const _ConnectionBadge({
    required this.isConnected,
    this.isConnecting = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isConnecting 
            ? Colors.orange.withAlpha((0.1 * 255).toInt())
            : (isConnected ? AppColors.connectedGreen.withAlpha((0.1 * 255).toInt()) : AppColors.disconnectedRed.withAlpha((0.1 * 255).toInt())),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isConnecting
              ? Colors.orange
              : (isConnected ? AppColors.connectedGreen : AppColors.disconnectedRed),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isConnecting
                  ? Colors.orange
                  : (isConnected ? AppColors.connectedGreen : AppColors.disconnectedRed),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isConnecting ? 'Connecting...' : (isConnected ? 'Connected' : 'Disconnected'),
            style: TextStyle(
              color: isConnecting
                  ? Colors.orange
                  : (isConnected ? AppColors.connectedGreen : AppColors.disconnectedRed),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
