// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/utils/platform/platform_io.dart' as platform_io;

import 'core/localization/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'services/notification_service.dart';
import 'core/constants/app_strings.dart';
import 'providers/system_provider.dart';
import 'providers/consumption_provider.dart';
import 'core/utils/app_lifecycle_handler.dart';
import 'core/utils/relay_sync_listener.dart';
import 'core/utils/smart_morning_checker.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/devices/screens/devices_screen.dart';
import 'features/analytics/screens/analytics_screen.dart';
import 'features/energy_saving/screens/energy_saving_screen.dart';
import 'features/schedules/screens/schedules_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/splash/splash_screen.dart';

// Navigation State Provider
final navigationIndexProvider = StateProvider<int>((ref) => 0);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only initialize sqflite on non-web platforms
  // sqflite_common_ffi_web causes a WebAssembly crash on Chrome
  if (!kIsWeb) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    platform_io.isDesktop;

    // flutter_local_notifications is not supported on web
    try {
      await NotificationService().init();
    } catch (_) {}
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // Register all background providers once — safe to do in initState
    Future.microtask(() {
      if (!mounted) return;
      try { ref.read(relaySyncListenerProvider); } catch (_) {}
      try { ref.read(houseBudgetAlertProvider); } catch (_) {}
      try { ref.read(systemProvider); } catch (_) {}
      try { ref.read(appLifecycleProvider(ref)); } catch (_) {}
      if (!kIsWeb) {
        try { ref.read(smartMorningProvider); } catch (_) {}
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
      const SchedulesScreen(),
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
            icon: const Icon(Icons.schedule_rounded),
            label: AppStrings.getString(language, 'schedules'),
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
