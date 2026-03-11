import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String defaultThemePresetId = 'midnight_orchid';

@immutable
class AppThemeConfig {
  const AppThemeConfig({
    required this.id,
    required this.primary,
    required this.background,
    required this.surface,
    this.isCustom = false,
  });

  final String id;
  final Color primary;
  final Color background;
  final Color surface;
  final bool isCustom;

  Color get surfaceElevated => Color.alphaBlend(Colors.white.withValues(alpha: 0.06), surface);
  Color get accentForeground => primary.computeLuminance() > 0.45 ? Colors.black : Colors.white;
  Color get mutedText => Colors.white.withValues(alpha: 0.68);
  Color get subtleText => Colors.white.withValues(alpha: 0.5);
  Color get border => Colors.white.withValues(alpha: 0.08);
  Color get softFill => Colors.white.withValues(alpha: 0.05);
  Color get accentSoft => primary.withValues(alpha: 0.2);

  AppThemeConfig copyWith({
    String? id,
    Color? primary,
    Color? background,
    Color? surface,
    bool? isCustom,
  }) {
    return AppThemeConfig(
      id: id ?? this.id,
      primary: primary ?? this.primary,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      isCustom: isCustom ?? this.isCustom,
    );
  }
}

class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.softFill,
    required this.mutedText,
    required this.subtleText,
    required this.accentSoft,
    required this.accentForeground,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color softFill;
  final Color mutedText;
  final Color subtleText;
  final Color accentSoft;
  final Color accentForeground;

  @override
  ThemeExtension<AppThemeColors> copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? border,
    Color? softFill,
    Color? mutedText,
    Color? subtleText,
    Color? accentSoft,
    Color? accentForeground,
  }) {
    return AppThemeColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      softFill: softFill ?? this.softFill,
      mutedText: mutedText ?? this.mutedText,
      subtleText: subtleText ?? this.subtleText,
      accentSoft: accentSoft ?? this.accentSoft,
      accentForeground: accentForeground ?? this.accentForeground,
    );
  }

  @override
  ThemeExtension<AppThemeColors> lerp(
    covariant ThemeExtension<AppThemeColors>? other,
    double t,
  ) {
    if (other is! AppThemeColors) {
      return this;
    }
    return AppThemeColors(
      background: Color.lerp(background, other.background, t) ?? background,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t) ?? surfaceElevated,
      border: Color.lerp(border, other.border, t) ?? border,
      softFill: Color.lerp(softFill, other.softFill, t) ?? softFill,
      mutedText: Color.lerp(mutedText, other.mutedText, t) ?? mutedText,
      subtleText: Color.lerp(subtleText, other.subtleText, t) ?? subtleText,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t) ?? accentSoft,
      accentForeground: Color.lerp(accentForeground, other.accentForeground, t) ?? accentForeground,
    );
  }
}

class AppThemeController {
  static const String _presetKey = 'app_theme_preset_id';
  static const String _customPrimaryKey = 'app_theme_custom_primary';
  static const String _customBackgroundKey = 'app_theme_custom_background';
  static const String _customSurfaceKey = 'app_theme_custom_surface';

  static const List<AppThemeConfig> presets = [
    AppThemeConfig(
      id: 'midnight_orchid',
      primary: Color(0xFFBB86FC),
      background: Color(0xFF121212),
      surface: Color(0xFF1E1E1E),
    ),
    AppThemeConfig(
      id: 'ember_core',
      primary: Color(0xFFFF7A59),
      background: Color(0xFF181310),
      surface: Color(0xFF261B17),
    ),
    AppThemeConfig(
      id: 'glacier_mint',
      primary: Color(0xFF5EEAD4),
      background: Color(0xFF071A1D),
      surface: Color(0xFF103036),
    ),
    AppThemeConfig(
      id: 'volt_lime',
      primary: Color(0xFFC6FF4D),
      background: Color(0xFF11140B),
      surface: Color(0xFF1E2612),
    ),
  ];

  static final ValueNotifier<AppThemeConfig> theme =
      ValueNotifier<AppThemeConfig>(_presetById(defaultThemePresetId));

  static AppThemeConfig _presetById(String id) {
    return presets.firstWhere(
      (preset) => preset.id == id,
      orElse: () => presets.first,
    );
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final presetId = prefs.getString(_presetKey) ?? defaultThemePresetId;
    if (presetId == 'custom') {
      final fallback = _presetById(defaultThemePresetId);
      theme.value = AppThemeConfig(
        id: 'custom',
        primary: Color(prefs.getInt(_customPrimaryKey) ?? fallback.primary.toARGB32()),
        background: Color(prefs.getInt(_customBackgroundKey) ?? fallback.background.toARGB32()),
        surface: Color(prefs.getInt(_customSurfaceKey) ?? fallback.surface.toARGB32()),
        isCustom: true,
      );
      return;
    }
    theme.value = _presetById(presetId);
  }

  static Future<void> setPreset(String presetId) async {
    final prefs = await SharedPreferences.getInstance();
    final config = _presetById(presetId);
    await prefs.setString(_presetKey, config.id);
    theme.value = config;
  }

  static Future<void> setCustomColors({
    required Color primary,
    required Color background,
    required Color surface,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_presetKey, 'custom');
    await prefs.setInt(_customPrimaryKey, primary.toARGB32());
    await prefs.setInt(_customBackgroundKey, background.toARGB32());
    await prefs.setInt(_customSurfaceKey, surface.toARGB32());
    theme.value = AppThemeConfig(
      id: 'custom',
      primary: primary,
      background: background,
      surface: surface,
      isCustom: true,
    );
  }

  static ThemeData buildTheme(AppThemeConfig config) {
    final colorScheme = ColorScheme.dark(
      primary: config.primary,
      onPrimary: config.accentForeground,
      surface: config.surface,
      onSurface: Colors.white,
      secondary: config.primary,
      onSecondary: config.accentForeground,
      error: const Color(0xFFEF5350),
    );

    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: colorScheme,
      primaryColor: config.primary,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: config.background,
      cardColor: config.surface,
      dialogTheme: DialogThemeData(backgroundColor: config.surface),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: config.surface,
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: config.primary,
        foregroundColor: config.accentForeground,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: config.surface,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: config.primary),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: config.primary,
          side: BorderSide(color: config.primary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: config.primary),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return config.primary;
          }
          return null;
        }),
        checkColor: WidgetStateProperty.all(config.accentForeground),
      ),
      extensions: [
        AppThemeColors(
          background: config.background,
          surface: config.surface,
          surfaceElevated: config.surfaceElevated,
          border: config.border,
          softFill: config.softFill,
          mutedText: config.mutedText,
          subtleText: config.subtleText,
          accentSoft: config.accentSoft,
          accentForeground: config.accentForeground,
        ),
      ],
    );
  }
}

extension AppThemeBuildContext on BuildContext {
  AppThemeColors get appColors => Theme.of(this).extension<AppThemeColors>()!;
}
