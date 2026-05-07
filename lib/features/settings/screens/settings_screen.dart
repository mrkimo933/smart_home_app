// lib/features/settings/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../providers/devices_provider.dart';
import '../../../providers/esp_provider.dart';
import '../widgets/setting_tile.dart';
import '../../devices/widgets/device_edit_dialog.dart';
import '../../incidents/screens/incident_log_screen.dart';
import '../../simulation/simulation_screen.dart';
import '../../../services/ai_scenario_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _espIpController = TextEditingController();
  final _budgetController = TextEditingController();
  final _groqKeyController = TextEditingController();
  TimeOfDay _autoOffTime = const TimeOfDay(hour: 7, minute: 0);
  bool _isTesting = false;
  bool _isTestingGroq = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final espService = ref.read(httpEspServiceProvider);
    final savedIp = await espService.getEspIp();
    final savedGroqKey = await AiScenarioService().getApiKey();
    setState(() {
      _espIpController.text = savedIp ?? '';
      _budgetController.text =
          (prefs.getDouble('monthly_budget') ?? 500.0).toString();
      final hour = prefs.getInt('auto_off_hour') ?? 7;
      final minute = prefs.getInt('auto_off_minute') ?? 0;
      _autoOffTime = TimeOfDay(hour: hour, minute: minute);
      _groqKeyController.text = savedGroqKey ?? '';
    });
  }

  Future<void> _saveEspIp() async {
    final ip = _espIpController.text.trim();
    if (ip.isEmpty) {
      _showSnackbar('ESP32 IP cannot be empty', isError: true);
      return;
    }
    await ref.read(httpEspServiceProvider).setEspIp(ip);
    _showSnackbar('Saved!', isError: false);
  }

  Future<void> _testConnection() async {
    final ip = _espIpController.text.trim();
    if (ip.isEmpty) {
      _showSnackbar('Enter an IP address first', isError: true);
      return;
    }
    setState(() => _isTesting = true);
    final ok = await ref.read(httpEspServiceProvider).testConnection(ip);
    setState(() => _isTesting = false);
    if (ok) {
      _showSnackbar('Connected to ESP32!', isError: false);
    } else {
      _showSnackbar('Cannot reach ESP32', isError: true);
    }
  }

  @override
  void dispose() {
    _espIpController.dispose();
    _budgetController.dispose();
    _groqKeyController.dispose();
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
                  controller: _espIpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ESP32 IP Address',
                    hintText: '192.168.1.25',
                    helperText: 'Enter the IP shown in Arduino Serial Monitor',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    helperStyle: TextStyle(color: AppColors.textSecondary),
                  ),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Polling every 2s',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isTesting ? null : _testConnection,
                        icon: _isTesting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.wifi_find),
                        label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue.withAlpha(180),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saveEspIp,
                        icon: const Icon(Icons.save),
                        label: const Text('Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SettingTile(
                  icon: Icons.wifi,
                  title: 'ESP32 Status',
                  subtitle: isConnected ? 'Connected' : 'Disconnected',
                  trailing: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isConnected
                          ? AppColors.connectedGreen
                          : AppColors.disconnectedRed,
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
                  subtitle:
                      'Turn off all non-essentials at ${_autoOffTime.format(context)}',
                  onTap: () => _selectTime(context),
                ),
              ],
            ),
            _buildSection(
              'My Devices',
              devices
                  .map((device) => SettingTile(
                        icon: Icons.devices_other_rounded,
                        title: device.name,
                        subtitle:
                            '${device.wattage} W - ${device.priority.toString().split('.').last}',
                        onTap: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => DeviceEditDialog(device: device),
                        ),
                      ))
                  .toList(),
            ),
            _buildSection(
              'الذكاء الاصطناعي',
              [
                TextField(
                  controller: _groqKeyController,
                  obscureText: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Groq API Key',
                    hintText: 'gsk_...',
                    helperText: 'احصل على API Key مجاني من console.groq.com',
                    labelStyle:
                        const TextStyle(color: AppColors.textSecondary),
                    helperStyle:
                        const TextStyle(color: AppColors.textSecondary),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.save,
                          color: AppColors.primaryBlue),
                      onPressed: () async {
                        await AiScenarioService()
                            .saveApiKey(_groqKeyController.text.trim());
                        if (mounted) {
                          _showSnackbar('Groq API Key Saved!',
                              isError: false);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isTestingGroq
                            ? null
                            : () async {
                                setState(
                                    () => _isTestingGroq = true);
                                final key =
                                    _groqKeyController.text.trim();
                                final ok = await AiScenarioService()
                                    .testApiKey(key);
                                if (mounted) {
                                  setState(
                                      () => _isTestingGroq = false);
                                  _showSnackbar(
                                    ok
                                        ? '✅ Groq API متصل!'
                                        : '❌ API Key غلط أو مفيش إنترنت',
                                    isError: !ok,
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppColors.primaryBlue.withAlpha(180),
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _isTestingGroq
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Test Connection'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await AiScenarioService()
                              .saveApiKey(_groqKeyController.text.trim());
                          if (mounted) {
                            _showSnackbar('Groq API Key Saved!',
                                isError: false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
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
                      border: Border.all(color: Colors.orange.withAlpha(80)),
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
                        language == AppLanguage.en
                            ? AppLanguage.ar
                            : AppLanguage.en;
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
