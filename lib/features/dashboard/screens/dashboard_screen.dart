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
import '../../../services/simulation_service.dart';
import '../widgets/power_gauge.dart';
import '../widgets/sensor_card.dart';
import '../widgets/bill_prediction_card.dart';
import '../widgets/peak_hours_banner.dart';
import '../widgets/quick_actions_bar.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sensorDataAsync = ref.watch(sensorDataProvider);
    final isConnectedAsync = ref.watch(connectionStatusProvider);
    final language = ref.watch(languageProvider);
    final voltageStatus = ref.watch(voltageStatusProvider);
    final voltage = sensorDataAsync.value?.voltage ?? 0.0;

    final isSimulating = ref.watch(isSimulatingProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.getString(language, 'dashboard')),
        actions: [
          if (isSimulating)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(40),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange, width: 1),
              ),
              child: const Text('SIM',
                  style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 11)),
            ),
          // Feature 5: voltage status indicator
          _VoltageIndicator(status: voltageStatus, voltage: voltage),
          const SizedBox(width: 8),
          isConnectedAsync.when(
            data: (isConnected) =>
                _ConnectionBadge(isConnected: isConnected),
            loading: () =>
                const _ConnectionBadge(isConnected: false, isConnecting: true),
            error: (_, __) => const _ConnectionBadge(isConnected: false),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Peak hours warning banner
          const PeakHoursBanner(),
          if (isConnectedAsync.hasValue &&
              isConnectedAsync.value == false)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.redAccent,
              child: const Text(
                'Offline - showing last known data. Connect to control.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          // Feature 5: voltage warning banner
          if (voltageStatus == VoltageStatus.high)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  vertical: 10, horizontal: 16),
              color: Colors.red.shade900,
              child: Row(
                children: [
                  const Icon(Icons.dangerous_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🚨 HIGH VOLTAGE: ${voltage.toStringAsFixed(0)}V — Non-essential devices disconnected.',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else if (voltageStatus == VoltageStatus.low)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  vertical: 10, horizontal: 16),
              color: Colors.orange.shade900,
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⚠️ LOW VOLTAGE: ${voltage.toStringAsFixed(0)}V — May damage sensitive devices.',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          // Simulation orange border indicator
          if (isSimulating)
            Container(
              width: double.infinity,
              height: 3,
              color: Colors.orange,
            ),
          Expanded(
            child: sensorDataAsync.when(
              data: (data) => _buildContent(context, data),
              loading: () => _buildLoadingState(context),
              error: (err, stack) =>
                  _buildErrorState(context, err.toString(), ref),
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
              const BillPredictionCard(),
              const SizedBox(height: 24),
              const QuickActionsBar(),
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

// Feature 5: Voltage status indicator in app bar
class _VoltageIndicator extends StatelessWidget {
  final VoltageStatus status;
  final double voltage;

  const _VoltageIndicator({required this.status, required this.voltage});

  @override
  Widget build(BuildContext context) {
    if (status == VoltageStatus.unknown || voltage == 0.0) {
      return const SizedBox.shrink();
    }
    Color color;
    String icon;
    switch (status) {
      case VoltageStatus.normal:
        color = Colors.green;
        icon = '✅';
        break;
      case VoltageStatus.low:
        color = Colors.orange;
        icon = '⚠️';
        break;
      case VoltageStatus.high:
        color = Colors.red;
        icon = '🚨';
        break;
      default:
        return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha((0.15 * 255).toInt()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        '$icon ${voltage.toStringAsFixed(0)}V',
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
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
