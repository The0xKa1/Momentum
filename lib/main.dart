import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'pages/splash_page.dart';
import 'services/app_background.dart';
import 'services/app_locale.dart';
import 'services/app_theme.dart';
import 'services/rest_timer_alarm.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化时区
  tz.initializeTimeZones();
  // 使用本地时区（自动检测）
  tz.setLocalLocation(tz.getLocation(tz.local.name));

  if (!kIsWeb) {
    await initRestTimerNotifications();
    await AndroidAlarmManager.initialize();
  }

  await AppLocaleController.load();
  await AppBackgroundController.load();
  await AppThemeController.load();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: AppLocaleController.locale,
      builder: (context, locale, _) {
        return ValueListenableBuilder<AppThemeConfig>(
          valueListenable: AppThemeController.theme,
          builder: (context, themeConfig, _) {
            final baseTheme = AppThemeController.buildTheme(themeConfig);
            return MaterialApp(
              title: 'Momentum',
              debugShowCheckedModeBanner: false,
              locale: locale,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('zh', 'CN'),
                Locale('en', 'US'),
              ],
              theme: baseTheme.copyWith(
                textTheme: GoogleFonts.interTextTheme(baseTheme.textTheme),
              ),
              builder: (context, child) {
                return ValueListenableBuilder<AppBackgroundConfig>(
                  valueListenable: AppBackgroundController.background,
                  builder: (context, backgroundConfig, _) {
                    final backgroundColor = themeConfig.background;
                    final imagePath = backgroundConfig.imagePath;
                    final hasImage = !kIsWeb &&
                        imagePath != null &&
                        imagePath.isNotEmpty &&
                        File(imagePath).existsSync();

                    Widget background = ColoredBox(color: backgroundColor);
                    if (hasImage) {
                      background = Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(color: backgroundColor),
                          if (backgroundConfig.blurSigma > 0)
                            ImageFiltered(
                              imageFilter: ImageFilter.blur(
                                sigmaX: backgroundConfig.blurSigma,
                                sigmaY: backgroundConfig.blurSigma,
                              ),
                              child: Image.file(
                                File(imagePath),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                              ),
                            )
                          else
                            Image.file(
                              File(imagePath),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ColoredBox(
                            color: Colors.black.withValues(
                              alpha: backgroundConfig.overlayOpacity.clamp(0.0, 1.0),
                            ),
                          ),
                        ],
                      );
                    }

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        background,
                        if (child != null) child,
                      ],
                    );
                  },
                );
              },
              home: const SplashPage(),
            );
          },
        );
      },
    );
  }
}
