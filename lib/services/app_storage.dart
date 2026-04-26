import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_background.dart';
import 'ai_settings.dart';
import 'app_locale.dart';
import 'app_theme.dart';
import 'rest_sound_settings.dart';
import 'weight_unit_settings.dart';

class AppStorageController {
  static const int backupVersion = 1;

  static const Map<String, String> _keyTypes = {
    'events_data': 'string',
    'completed_plans': 'string',
    'plan_templates': 'string',
    'daily_extra_workout_data': 'string',
    'hidden_plan_today': 'string',
    'daily_completion_state': 'string',
    'daily_workout_snapshot': 'string',
    'diet_entries': 'string',
    'ai_provider_settings': 'string',
    'app_locale': 'string',
    'weight_unit': 'string',
    'rest_sound_path': 'string',
    'app_theme_preset_id': 'string',
    'app_background_image_path': 'string',
    'app_background_overlay_opacity': 'double',
    'app_background_blur_sigma': 'double',
    'app_theme_custom_primary': 'int',
    'app_theme_custom_background': 'int',
    'app_theme_custom_surface': 'int',
  };

  static Future<String> exportBackupJson() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};

    for (final entry in _keyTypes.entries) {
      final key = entry.key;
      switch (entry.value) {
        case 'double': {
          final value = prefs.getDouble(key);
          if (value != null) data[key] = value;
          break;
        }
        case 'int': {
          final value = prefs.getInt(key);
          if (value != null) data[key] = value;
          break;
        }
        case 'string': {
          final value = prefs.getString(key);
          if (value != null) data[key] = value;
          break;
        }
      }
    }

    return const JsonEncoder.withIndent('  ').convert({
      'meta': {
        'app': 'fitflow',
        'version': backupVersion,
        'exportedAt': DateTime.now().toIso8601String(),
      },
      'prefs': data,
    });
  }

  static Future<void> importBackupJson(String raw) async {
    final decoded = json.decode(raw);
    if (decoded is! Map) {
      throw const FormatException('Backup payload must be a JSON object.');
    }

    final payload = Map<String, dynamic>.from(decoded);
    final rawPrefs = payload['prefs'];
    if (rawPrefs is! Map) {
      throw const FormatException('Backup payload is missing prefs.');
    }

    final backupPrefs = Map<String, dynamic>.from(rawPrefs);
    final prefs = await SharedPreferences.getInstance();

    for (final entry in _keyTypes.entries) {
      final key = entry.key;
      if (!backupPrefs.containsKey(key)) {
        await prefs.remove(key);
        continue;
      }

      final value = backupPrefs[key];
      switch (entry.value) {
        case 'double': {
          if (value is! num) {
            throw FormatException('Invalid value for $key');
          }
          await prefs.setDouble(key, value.toDouble());
          break;
        }
        case 'int': {
          if (value is! num) {
            throw FormatException('Invalid value for $key');
          }
          await prefs.setInt(key, value.toInt());
          break;
        }
        case 'string': {
          if (value is! String) {
            throw FormatException('Invalid value for $key');
          }
          await prefs.setString(key, value);
          break;
        }
      }
    }

    await reloadControllers();
  }

  static Future<void> reloadControllers() async {
    await AppLocaleController.load();
    await AppBackgroundController.load();
    await AiSettingsController.load();
    await AppThemeController.load();
    await WeightUnitController.load();
    await RestSoundController.load();
  }

  static String buildBackupFileName(DateTime now) {
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return 'fitflow-backup-${now.year}-$month-$day.json';
  }
}
