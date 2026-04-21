// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/devices/screens/devices_screen.dart';
import 'features/analytics/screens/analytics_screen.dart';
import 'features/energy_saving/screens/energy_saving_screen.dart';
import 'features/settings/screens/settings_screen.dart';

// Navigation State Provider
final navigationIndexProvider = StateProvider<int>((ref) => 0);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    
    return MaterialApp(
      title: AppStrings.getString(language, 'appName'),
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      
      // Localization setup
      locale: Locale(language == AppLanguage.en ? 'en' : 'ar'),
      supportedLocales: const [
        Locale('en', ''),
        Locale('ar', ''),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: const MainScreen(),
    );
  }
}

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final language = ref.watch(languageProvider);

    final List<Widget> screens = [
      const DashboardScreen(),
      const DevicesScreen(),
      const AnalyticsScreen(),
      const EnergySavingScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => ref.read(navigationIndexProvider.notifier).state = index,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard_rounded),
            label: AppStrings.getString(language, 'dashboard'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.devices_other_rounded),
            label: AppStrings.getString(language, 'devices'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bar_chart_rounded),
            label: AppStrings.getString(language, 'analytics'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.eco_rounded),
            label: AppStrings.getString(language, 'energySaving'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_rounded),
            label: AppStrings.getString(language, 'settings'),
          ),
        ],
      ),
    );
  }
}
