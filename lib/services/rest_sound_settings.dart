import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RestSoundController {
  static const String _prefsRestSoundKey = 'rest_sound_path';
  static final ValueNotifier<String?> restSoundPath =
      ValueNotifier<String?>(null);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    restSoundPath.value = prefs.getString(_prefsRestSoundKey);
  }

  static Future<String?> getSavedSoundPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsRestSoundKey);
  }

  static Future<void> setSoundPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null || path.isEmpty) {
      await prefs.remove(_prefsRestSoundKey);
      restSoundPath.value = null;
      return;
    }
    await prefs.setString(_prefsRestSoundKey, path);
    restSoundPath.value = path;
  }
}
