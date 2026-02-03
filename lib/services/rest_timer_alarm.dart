import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'app_locale.dart';

const String restTimerFinishChannelId = 'rest_timer_finish_v3';
const String restTimerOngoingChannelId = 'rest_timer_ongoing';
const int restTimerNotificationId = 1001;
const int restTimerOngoingNotificationId = 1002;
const int restTimerAlarmManagerId = 9101;

final FlutterLocalNotificationsPlugin restTimerNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

AndroidFlutterLocalNotificationsPlugin? _androidNotifications;

Future<void> initRestTimerNotifications({
  DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  bool requestPermissions = true,
}) async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await restTimerNotificationsPlugin.initialize(
    settings: initSettings,
    onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
  );

  if (defaultTargetPlatform != TargetPlatform.android) return;

  _androidNotifications = restTimerNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  if (requestPermissions) {
    await _androidNotifications?.requestNotificationsPermission();
  }

  await _androidNotifications?.createNotificationChannel(
    const AndroidNotificationChannel(
      restTimerFinishChannelId,
      'Rest Timer Finish',
      description: 'Notifications when rest timer finishes',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('alarm'),
    ),
  );
  await _androidNotifications?.createNotificationChannel(
    const AndroidNotificationChannel(
      restTimerOngoingChannelId,
      'Rest Timer Ongoing',
      description: 'Ongoing rest timer countdown',
      importance: Importance.low,
      enableVibration: false,
    ),
  );

  if (requestPermissions && _androidNotifications != null) {
    try {
      final dynamic android = _androidNotifications;
      await android.requestExactAlarmsPermission();
    } catch (_) {
      // 忽略：当前插件版本可能不支持该方法
    }
  }
}

Future<void> showRestTimerFinishedNotification() async {
  final locale = await AppLocaleController.getSavedLocale();
  final isZh = locale?.languageCode == 'zh';
  final title = isZh ? '休息结束！🏋️' : 'Rest Time Over! 🏋️';
  final body = isZh ? '该进行下一组了！' : 'Time for your next set!';

  const androidDetails = AndroidNotificationDetails(
    restTimerFinishChannelId,
    'Rest Timer',
    channelDescription: 'Notifications for rest timer completion',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('alarm'),
    audioAttributesUsage: AudioAttributesUsage.alarm,
    enableVibration: true,
    ongoing: false,
    autoCancel: true,
  );
  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    interruptionLevel: InterruptionLevel.timeSensitive,
  );
  const notificationDetails = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );

  await restTimerNotificationsPlugin.show(
    id: restTimerNotificationId,
    title: title,
    body: body,
    notificationDetails: notificationDetails,
  );
}

@pragma('vm:entry-point')
Future<void> restTimerAlarmCallback() async {
  DartPluginRegistrant.ensureInitialized();
  await initRestTimerNotifications(requestPermissions: false);
  await showRestTimerFinishedNotification();
}

Future<void> scheduleRestTimerAlarm(DateTime endTime) async {
  if (defaultTargetPlatform != TargetPlatform.android) return;

  await AndroidAlarmManager.oneShotAt(
    endTime,
    restTimerAlarmManagerId,
    restTimerAlarmCallback,
    wakeup: true,
    exact: true,
    rescheduleOnReboot: true,
  );
}

Future<void> cancelRestTimerAlarm() async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  await AndroidAlarmManager.cancel(restTimerAlarmManagerId);
}
