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
import '../../incidents/screens/incident_log_screen.dart';
import '../../simulation/simulation_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
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
      final brokerIp = prefs.getString('mqtt_broker_ip') ?? 'broker.hivemq.com';
      _ipController.text = brokerIp;
      
      final savedPort = prefs.getInt('mqtt_broker_port');
      if (savedPort != null) {
        _portController.text = savedPort.toString();
      } else {
        _portController.text = '1883';
      }
      
      _usernameController.text = prefs.getString('mqtt_username') ?? '';
      _passwordController.text = prefs.getString('mqtt_password') ?? '';
      _budgetController.text = (prefs.getDouble('monthly_budget') ?? 500.0).toString();
      final hour = prefs.getInt('auto_off_hour') ?? 7;
      final minute = prefs.getInt('auto_off_minute') ?? 0;
      _autoOffTime = TimeOfDay(hour: hour, minute: minute);
    });
  }

  Future<void> _updateBrokerConfig() async {
    final host = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 1883;
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    
    if (host.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mqtt_broker_ip', host);
      await prefs.setInt('mqtt_broker_port', port);
      await prefs.setString('mqtt_username', username);
      await prefs.setString('mqtt_password', password);
      
      // Trigger reconnect
      ref.read(mqttServiceProvider).connect();
      
      _showSnackbar('MQTT Configuration updated', isError: false);
    } else {
      _showSnackbar('Broker Host/IP cannot be empty', isError: true);
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _budgetController.dispose();
    super.dispose();
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
                  decoration: const InputDecoration(
                    labelText: 'Broker Hostname / IP',
                    hintText: 'e.g. xxxxx.s1.eu.hivemq.cloud',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                  ),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _portController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Broker Port',
                    hintText: '8883 for SSL',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                  ),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'MQTT Username',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                  ),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'MQTT Password',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                  ),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _updateBrokerConfig,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Connection Settings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => DeviceEditDialog(device: device),
                ),
              )).toList(),
            ),
            _buildSection(
              'System',
              [
                SettingTile(
                  icon: Icons.warning_amber_rounded,
                  title: 'Incident Log',
                  subtitle: 'View overcurrent incidents',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const IncidentLogScreen()),
                  ),
                ),
              ],
            ),
            _buildSection(
              'وضع العرض التجريبي',
              [
                SettingTile(
                  icon: Icons.science_rounded,
                  title: 'وضع المحاكاة',
                  subtitle: 'وضع العرض التجريبي - للجنة فقط',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: Colors.orange.withAlpha(80)),
                    ),
                    child: const Text(
                      'تجريبي',
                      style: TextStyle(
                          color: Colors.orange,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SimulationScreen()),
                  ),
                ),
              ],
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
