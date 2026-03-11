import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppBackgroundConfig {
  const AppBackgroundConfig({
    this.imagePath,
    this.overlayOpacity = 0.58,
    this.blurSigma = 0,
  });

  final String? imagePath;
  final double overlayOpacity;
  final double blurSigma;

  AppBackgroundConfig copyWith({
    String? imagePath,
    bool clearImagePath = false,
    double? overlayOpacity,
    double? blurSigma,
  }) {
    return AppBackgroundConfig(
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      overlayOpacity: overlayOpacity ?? this.overlayOpacity,
      blurSigma: blurSigma ?? this.blurSigma,
    );
  }
}

class AppBackgroundController {
  static const String _imagePathKey = 'app_background_image_path';
  static const String _overlayOpacityKey = 'app_background_overlay_opacity';
  static const String _blurSigmaKey = 'app_background_blur_sigma';

  static final ValueNotifier<AppBackgroundConfig> background =
      ValueNotifier<AppBackgroundConfig>(const AppBackgroundConfig());

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    background.value = AppBackgroundConfig(
      imagePath: prefs.getString(_imagePathKey),
      overlayOpacity: prefs.getDouble(_overlayOpacityKey) ?? 0.58,
      blurSigma: prefs.getDouble(_blurSigmaKey) ?? 0,
    );
  }

  static Future<void> setImagePath(String? imagePath) async {
    final prefs = await SharedPreferences.getInstance();
    if (imagePath == null || imagePath.isEmpty) {
      await prefs.remove(_imagePathKey);
      background.value = background.value.copyWith(clearImagePath: true);
      return;
    }
    await prefs.setString(_imagePathKey, imagePath);
    background.value = background.value.copyWith(imagePath: imagePath);
  }

  static Future<void> setOverlayOpacity(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_overlayOpacityKey, value);
    background.value = background.value.copyWith(overlayOpacity: value);
  }

  static Future<void> setBlurSigma(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_blurSigmaKey, value);
    background.value = background.value.copyWith(blurSigma: value);
  }
}
