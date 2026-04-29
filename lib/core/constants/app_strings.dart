import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_ar.dart';
import '../../l10n/app_en.dart';

enum AppLanguage { en, ar }

final languageProvider = StateProvider<AppLanguage>((ref) => AppLanguage.en);

class AppStrings {
  static const Map<AppLanguage, Map<String, String>> _localizedValues = {
    AppLanguage.en: appEn,
    AppLanguage.ar: appAr,
  };

  static String getString(AppLanguage lang, String key) {
    return _localizedValues[lang]?[key] ?? key;
  }
}
