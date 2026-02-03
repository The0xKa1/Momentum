import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocaleController {
  static const String _prefsLocaleKey = 'app_locale';
  static final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsLocaleKey);
    locale.value = _parseLocale(stored);
  }

  static Future<Locale?> getSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsLocaleKey);
    return _parseLocale(stored);
  }

  static Future<void> setLocale(Locale? newLocale) async {
    final prefs = await SharedPreferences.getInstance();
    if (newLocale == null) {
      await prefs.remove(_prefsLocaleKey);
      locale.value = null;
      return;
    }

    final value = newLocale.countryCode == null
        ? newLocale.languageCode
        : '${newLocale.languageCode}_${newLocale.countryCode}';
    await prefs.setString(_prefsLocaleKey, value);
    locale.value = newLocale;
  }

  static Locale? _parseLocale(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parts = value.split('_');
    if (parts.isEmpty) return null;
    if (parts.length == 1) return Locale(parts[0]);
    return Locale(parts[0], parts[1]);
  }
}
