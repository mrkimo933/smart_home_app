// lib/features/splash/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../main.dart';
import '../../providers/esp_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  final TextEditingController _ipController = TextEditingController();
  bool _showIpDialog = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Minimum 1-second splash display
    final minSplash = Future.delayed(const Duration(seconds: 1));

    // Load saved IP via the ESP init provider
    final espService = ref.read(httpEspServiceProvider);
    final savedIp = await espService.getEspIp();

    await minSplash;

    if (!mounted) return;

    if (savedIp == null || savedIp.isEmpty) {
      // No IP saved — prompt the user
      setState(() => _showIpDialog = true);
    } else {
      // IP exists — navigate immediately (polling already started)
      _navigateToMain();
    }
  }

  void _navigateToMain() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
  }

  Future<void> _saveIpAndContinue() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) return;
    setState(() => _isSaving = true);
    await ref.read(httpEspServiceProvider).setEspIp(ip);
    setState(() => _isSaving = false);
    _navigateToMain();
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Main splash content
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bolt, size: 80, color: AppColors.primaryBlue),
                SizedBox(height: 20),
                Text(
                  'Smart Home Energy Monitor',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 40),
                CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                ),
              ],
            ),
          ),

          // IP entry overlay shown when no IP is saved
          if (_showIpDialog)
            Container(
              color: Colors.black.withAlpha(180),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.cardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enter ESP32 IP Address',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter the IP shown in the Arduino Serial Monitor to connect to your ESP32.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _ipController,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'ESP32 IP Address',
                          hintText: '192.168.1.25',
                          labelStyle:
                              TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: _navigateToMain,
                              child: const Text(
                                'Skip',
                                style:
                                    TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  _isSaving ? null : _saveIpAndContinue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                foregroundColor: Colors.white,
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Connect'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
