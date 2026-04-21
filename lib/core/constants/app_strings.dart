// lib/core/constants/app_strings.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

enum AppLanguage { en, ar }

final languageProvider = StateProvider<AppLanguage>((ref) => AppLanguage.en);

class AppStrings {
  static String get(BuildContext context, String key) {
    // This is a simple helper if not using standard localization delegates
    // But for this task, I will provide a static class with getters that check a provider
    return ""; 
  }

  static const Map<AppLanguage, Map<String, String>> _localizedValues = {
    AppLanguage.en: {
      'appName': 'Energy Monitor',
      'dashboard': 'Dashboard',
      'devices': 'Devices',
      'analytics': 'Analytics',
      'energySaving': 'Energy Saving',
      'settings': 'Settings',
      'voltage': 'Voltage',
      'current': 'Current',
      'power': 'Power',
      'consumption': 'Consumption',
      'connected': 'Connected',
      'disconnected': 'Disconnected',
      'loading': 'Loading...',
      'error': 'Error connecting to broker',
      'relay1': 'Relay 1',
      'relay2': 'Relay 2',
      'relay3': 'Relay 3',
      'relay4': 'Relay 4',
      'on': 'ON',
      'off': 'OFF',
    },
    AppLanguage.ar: {
      'appName': 'مراقب الطاقة',
      'dashboard': 'لوحة التحكم',
      'devices': 'الأجهزة',
      'analytics': 'التحليلات',
      'energySaving': 'توفير الطاقة',
      'settings': 'الإعدادات',
      'voltage': 'الجهد',
      'current': 'التيار',
      'power': 'الطاقة',
      'consumption': 'الاستهلاك',
      'connected': 'متصل',
      'disconnected': 'غير متصل',
      'loading': 'جاري التحميل...',
      'error': 'خطأ في الاتصال بالخادم',
      'relay1': 'مفتاح 1',
      'relay2': 'مفتاح 2',
      'relay3': 'مفتاح 3',
      'relay4': 'مفتاح 4',
      'on': 'تشغيل',
      'off': 'إيقاف',
    },
  };

  static String getString(AppLanguage lang, String key) {
    return _localizedValues[lang]?[key] ?? key;
  }
}
