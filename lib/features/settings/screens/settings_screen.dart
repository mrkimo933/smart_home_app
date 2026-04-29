// lib/features/settings/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../providers/devices_provider.dart';
import '../../../providers/mqtt_provider.dart';
import '../widgets/setting_tile.dart';
import '../../devices/widgets/device_edit_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _ipController = TextEditingController();
  final _budgetController = TextEditingController();
  TimeOfDay _autoOffTime = const TimeOfDay(hour: 7, minute: 0);
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ipController.text = prefs.getString('mqtt_broker_ip') ?? '192.168.1.100';
      _budgetController.text = (prefs.getDouble('monthly_budget') ?? 500.0).toString();
      final hour = prefs.getInt('auto_off_hour') ?? 7;
      final minute = prefs.getInt('auto_off_minute') ?? 0;
      _autoOffTime = TimeOfDay(hour: hour, minute: minute);
    });
  }

  Future<void> _updateBrokerIp() async {
    final ip = _ipController.text.trim();
    if (_isValidIp(ip)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mqtt_broker_ip', ip);
      
      // Trigger reconnect
      ref.read(mqttServiceProvider).connect();
      
      _showSnackbar('Broker IP updated', isError: false);
    } else {
      _showSnackbar('Invalid IP address format', isError: true);
    }
  }

  bool _isValidIp(String ip) {
    final regExp = RegExp(r'^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$');
    return regExp.hasMatch(ip);
  }

  Future<void> _updateBudget() async {
    final budget = double.tryParse(_budgetController.text) ?? 500.0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('monthly_budget', budget);
    _showSnackbar('Monthly budget saved', isError: false);
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _autoOffTime,
    );
    if (picked != null && picked != _autoOffTime) {
      setState(() => _autoOffTime = picked);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('auto_off_hour', picked.hour);
      await prefs.setInt('auto_off_minute', picked.minute);
      _showSnackbar('Auto-off time updated', isError: false);
    }
  }

  void _showSnackbar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.errorRed : AppColors.accentGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final isConnected = ref.watch(connectionStatusProvider).value ?? false;
    final devices = ref.watch(devicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.getString(language, 'settings')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildSection(
              'Connection',
              [
                TextField(
                  controller: _ipController,
                  decoration: InputDecoration(
                    labelText: 'Broker IP Address',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.save, color: AppColors.primaryBlue),
                      onPressed: _updateBrokerIp,
                    ),
                  ),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                SettingTile(
                  icon: Icons.wifi,
                  title: 'Broker Status',
                  subtitle: isConnected ? 'Connected' : 'Disconnected',
                  trailing: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isConnected ? AppColors.connectedGreen : AppColors.disconnectedRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            _buildSection(
              'Energy Settings',
              [
                TextField(
                  controller: _budgetController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Monthly Budget (EGP)',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.save, color: AppColors.primaryBlue),
                      onPressed: _updateBudget,
                    ),
                  ),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                SettingTile(
                  icon: Icons.wb_sunny_rounded,
                  title: 'Morning Auto-Off',
                  subtitle: 'Turn off all non-essentials at ${_autoOffTime.format(context)}',
                  onTap: () => _selectTime(context),
                ),
              ],
            ),
            _buildSection(
              'My Devices',
              devices.map((device) => SettingTile(
                icon: Icons.devices_other_rounded,
                title: device.name,
                subtitle: '${device.wattage} W - ${device.priority.toString().split('.').last}',
                onTap: () => showDialog(
                  context: context,
                  builder: (context) => DeviceEditDialog(device: device),
                ),
              )).toList(),
            ),
            _buildSection(
              'App Preferences',
              [
                SettingTile(
                  icon: Icons.language_rounded,
                  title: 'Language',
                  subtitle: language == AppLanguage.en ? 'English' : 'العربية',
                  onTap: () {
                    ref.read(languageProvider.notifier).state = 
                      language == AppLanguage.en ? AppLanguage.ar : AppLanguage.en;
                  },
                ),
                const SettingTile(
                  icon: Icons.info_outline_rounded,
                  title: 'App Version',
                  subtitle: '1.0.0 (Stable)',
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Designed with passion for Smart Homes',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.primaryBlue,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: children),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
