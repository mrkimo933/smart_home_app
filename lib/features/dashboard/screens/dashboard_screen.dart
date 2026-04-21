// lib/features/dashboard/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../providers/mqtt_provider.dart';
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
      body: sensorDataAsync.when(
        data: (data) => _buildContent(context, data),
        loading: () => _buildLoadingState(context),
        error: (err, stack) => _buildErrorState(context, err.toString()),
      ),
    );
  }

  Widget _buildContent(BuildContext context, dynamic data) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          const SizedBox(height: 20),
          PowerGauge(watts: data.power),
          const SizedBox(height: 30),
          Row(
            children: [
              SensorCard(
                title: 'Voltage',
                value: data.voltage.toString(),
                unit: 'V',
                icon: Icons.bolt_rounded,
                color: Colors.blue,
              ),
              const SizedBox(width: 12),
              SensorCard(
                title: 'Current',
                value: data.current.toString(),
                unit: 'A',
                icon: Icons.electric_meter_rounded,
                color: Colors.orange,
              ),
              const SizedBox(width: 12),
              SensorCard(
                title: 'Power',
                value: data.power.toString(),
                unit: 'W',
                icon: Icons.speed_rounded,
                color: AppColors.primaryBlue,
              ),
            ],
          ),
          const SizedBox(height: 24),
          BillPredictionCard(currentKwh: data.kwh),
          const SizedBox(height: 30),
        ],
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

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.errorRed, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Connection Error',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(error, style: const TextStyle(color: AppColors.textSecondary)),
        ],
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
            ? Colors.orange.withOpacity(0.1)
            : (isConnected ? AppColors.connectedGreen.withOpacity(0.1) : AppColors.disconnectedRed.withOpacity(0.1)),
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
