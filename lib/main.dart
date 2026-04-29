// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/localization/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'services/notification_service.dart';
import 'core/constants/app_strings.dart';
import 'providers/mqtt_provider.dart';
import 'providers/system_provider.dart';
import 'core/utils/app_lifecycle_handler.dart';
import 'core/utils/relay_sync_listener.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/devices/screens/devices_screen.dart';
import 'features/analytics/screens/analytics_screen.dart';
import 'features/energy_saving/screens/energy_saving_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/splash/splash_screen.dart';

// Navigation State Provider
final navigationIndexProvider = StateProvider<int>((ref) => 0);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize notification service
  await NotificationService().init();

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
    // Ensure relay sync provider is read so it registers its listeners
    ref.read(relaySyncProvider);
    // Ensure relay search sync listener is active
    ref.read(relaySyncListenerProvider);
    // Ensure system provider is read so midnight reset and other tasks run
    ref.read(systemProvider);
    // Ensure lifecycle handler is active
    ref.read(appLifecycleProvider(ref));
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
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: const SplashScreen(),
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
