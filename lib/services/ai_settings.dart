import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_provider_settings.dart';

class AiSettingsController {
  static const String prefsKey = 'ai_provider_settings';

  static final ValueNotifier<AiProviderSettings> settings =
      ValueNotifier<AiProviderSettings>(AiProviderSettings.empty);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) {
      settings.value = AiProviderSettings.empty;
      return;
    }

    final decoded = json.decode(raw);
    if (decoded is! Map) {
      settings.value = AiProviderSettings.empty;
      return;
    }

    settings.value = AiProviderSettings.fromJson(Map<String, dynamic>.from(decoded));
  }

  static Future<AiProviderSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) return AiProviderSettings.empty;
    final decoded = json.decode(raw);
    if (decoded is! Map) return AiProviderSettings.empty;
    return AiProviderSettings.fromJson(Map<String, dynamic>.from(decoded));
  }

  static Future<void> save(AiProviderSettings next) async {
    final normalized = next.hasRequiredFields ? next : next.copyWith(enabled: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, json.encode(normalized.toJson()));
    settings.value = normalized;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
    settings.value = AiProviderSettings.empty;
  }
}
