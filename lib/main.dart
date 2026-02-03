import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'pages/splash_page.dart';
import 'services/app_locale.dart';
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
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: AppLocaleController.locale,
      builder: (context, locale, _) {
        return MaterialApp(
          title: 'Momentum',
          debugShowCheckedModeBanner: false, // 去掉右上角那个 Debug 条幅
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
          theme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: const Color(0xFFBB86FC),
            scaffoldBackgroundColor: const Color(0xFF121212),
            useMaterial3: true,
            textTheme: GoogleFonts.interTextTheme(
              Theme.of(context).textTheme,
            ),
          ),
          // --- 修改这里 ---
          home: const SplashPage(), // 启动时先进入 SplashPage
        );
      },
    );
  }
}