import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

// 引入模型和库
import '../models/workout_model.dart';
import '../models/exercise_library.dart';
import '../services/rest_timer_alarm.dart';

// 引入拆分出的组件模块
import '../widgets/exercise_card.dart';
import '../widgets/rest_timer_panel.dart';

class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key});

  @override
  State<WorkoutPage> createState() => WorkoutPageState();
}

class WorkoutPageState extends State<WorkoutPage> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  // 保持页面状态，切换标签不销毁
  @override
  bool get wantKeepAlive => true;

  static const String _prefsPlanTemplatesKey = "plan_templates";
  static const String _prefsDailyExtrasKey = "daily_extra_workout_data";
  static const String _prefsHiddenPlanKey = "hidden_plan_today";
  static const String _prefsCompletionKey = "daily_completion_state";

  // --- 状态变量 ---
  String _planTitle = "Rest Day";
  List<Exercise> exercises = [];
  /// 前 _planCount 个是计划模板动作，之后是当日额外动作
  int _planCount = 0;
  
  // 计时器相关
  Timer? _restTimer;
  int _restSeconds = 0;
  int _totalRestSeconds = 90;
  bool _isResting = false;
  DateTime? _restEndTime; // 休息结束时间，用于后台计时
  int _restNotificationToken = 0;
  
  // 音频播放器
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAlarmPlaying = false;
  
  // 本地通知
  late final Future<void> _notificationsInit;

  // 控制器
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();

  void refreshData() {
    print("Refreshing workout data...");
    _loadTodayPlan();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTodayPlan();
    _initAudioPlayer();
    _notificationsInit = _initNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restTimer?.cancel();
    _stopAlarm();
    _audioPlayer.dispose();
    _weightController.dispose();
    _repsController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed && _isResting && _restEndTime != null) {
      // 应用从后台恢复，重新计算剩余时间
      _recalculateRestTime();
    }
  }

  void _initAudioPlayer() async {
    // 设置音频播放模式为循环
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    
    // 确保 AudioContext 设置允许在静音模式以外播放
    await _audioPlayer.setAudioContext(AudioContext(
      android: const AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: true,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.alarm,
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: const {AVAudioSessionOptions.duckOthers, AVAudioSessionOptions.mixWithOthers},
      ),
    ));
  }

  Future<void> _initNotifications() async {
    await initRestTimerNotifications(
      onDidReceiveNotificationResponse: (details) {
        // 用户点击通知时的处理
        if (mounted) {
          _handleNotificationTap();
        }
      },
    );
  }

  void _handleNotificationTap() {
    // 用户点击通知后，如果时间到了，显示弹窗
    if (_isResting && _restEndTime != null) {
      _recalculateRestTime();
    }
  }

  void _requestRestNotificationSchedule() {
    if (_restEndTime == null) return;
    _restNotificationToken += 1;
    final token = _restNotificationToken;
    _scheduleRestNotification(_restEndTime!, token);
  }

  Future<void> _scheduleRestNotification(DateTime endTime, int token) async {
    await _notificationsInit;
    if (token != _restNotificationToken) return;
    // 取消之前的通知
    await restTimerNotificationsPlugin.cancel(id: restTimerNotificationId);
    await cancelRestTimerAlarm();
    if (token != _restNotificationToken) return;

    if (defaultTargetPlatform == TargetPlatform.android) {
      await scheduleRestTimerAlarm(endTime);
      return;
    }
    
    // 设置通知在指定秒数后触发
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
    
    // 在指定时间后显示通知
    await restTimerNotificationsPlugin.zonedSchedule(
      id: restTimerNotificationId,
      title: 'Rest Time Over! 🏋️',
      body: 'Time for your next set!',
      scheduledDate: tz.TZDateTime.from(endTime, tz.local),
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> _cancelRestNotification() async {
    await restTimerNotificationsPlugin.cancel(id: restTimerNotificationId);
    await cancelRestTimerAlarm();
  }

  Future<void> _showOngoingRestNotification() async {
    if (defaultTargetPlatform != TargetPlatform.android || _restEndTime == null) return;
    await _notificationsInit;

    final androidDetails = AndroidNotificationDetails(
      restTimerOngoingChannelId,
      'Rest Timer (Ongoing)',
      channelDescription: 'Ongoing rest timer countdown',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: true,
      when: _restEndTime!.millisecondsSinceEpoch,
      usesChronometer: true,
      chronometerCountDown: true,
      timeoutAfter: _restEndTime!
          .difference(DateTime.now())
          .inMilliseconds
          .clamp(0, 1 << 31)
          .toInt(),
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await restTimerNotificationsPlugin.show(
      id: restTimerOngoingNotificationId,
      title: 'Resting...',
      body: '倒计时进行中',
      notificationDetails: notificationDetails,
    );
  }

  Future<void> _cancelOngoingRestNotification() async {
    await restTimerNotificationsPlugin.cancel(id: restTimerOngoingNotificationId);
  }

  void _recalculateRestTime() {
    if (_restEndTime == null) return;

    final now = DateTime.now();
    final remaining = _restEndTime!.difference(now).inSeconds;

    if (remaining <= 0) {
      // 时间已到或已过
      _restSeconds = 0;
      _stopRestTimer();
      _playAlarm();
      _showRestFinishedDialog();
    } else {
      // 更新剩余时间
      setState(() {
        _restSeconds = remaining;
      });
    }
  }

  // --- 计时器逻辑 ---
  String get _timerString {
    int min = _restSeconds ~/ 60;
    int sec = _restSeconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  void _startRestTimer({int seconds = 90}) {
    _stopRestTimer();
    _restEndTime = DateTime.now().add(Duration(seconds: seconds));
    
    setState(() {
      _totalRestSeconds = seconds;
      _restSeconds = seconds;
      _isResting = true;
    });

    // 启用屏幕常亮（可选）
    WakelockPlus.enable();
    
    // 设置后台通知
    _requestRestNotificationSchedule();
    // 在状态栏显示倒计时（Android）
    _showOngoingRestNotification();

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restEndTime == null) return;
      final remaining = _restEndTime!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        _restSeconds = 0;
        _stopRestTimer();
        _playAlarm();
        _showRestFinishedDialog();
      } else {
        setState(() {
          _restSeconds = remaining;
        });
      }
    });
  }

  void _stopRestTimer() {
    _restNotificationToken += 1;
    _restTimer?.cancel();
    _restEndTime = null;
    _stopAlarm(); // 停止提醒音
    _cancelRestNotification(); // 取消通知
    _cancelOngoingRestNotification(); // 取消状态栏倒计时
    WakelockPlus.disable();
    setState(() {
      _isResting = false;
    });
  }

  Future<void> _playAlarm() async {
    if (_isAlarmPlaying) return;
    
    try {
      _isAlarmPlaying = true;
      // 尝试播放自定义提醒音（循环播放）
      await _audioPlayer.play(AssetSource('sounds/alarm.mp3'));
    } catch (e) {
      print('播放自定义提醒音失败: $e，使用URL音频作为备选');
      // 如果音频文件不存在，使用在线提示音作为备选
      try {
        await _audioPlayer.play(UrlSource(
          'https://actions.google.com/sounds/v1/alarms/beep_short.ogg'
        ));
      } catch (e2) {
        print('播放在线提醒音也失败: $e2');
        _isAlarmPlaying = false;
      }
    }
  }

  Future<void> _stopAlarm() async {
    if (!_isAlarmPlaying) return;
    
    try {
      await _audioPlayer.stop();
      _isAlarmPlaying = false;
    } catch (e) {
      print('停止提醒音失败: $e');
    }
  }

  void _adjustTime(int seconds) {
    setState(() {
      _restSeconds += seconds;
      if (_restSeconds < 0) _restSeconds = 0;
      if (_restSeconds > _totalRestSeconds) {
        _totalRestSeconds = _restSeconds;
      }
    });

    if (_restEndTime != null) {
      final updatedEnd = _restEndTime!.add(Duration(seconds: seconds));
      _restEndTime = updatedEnd.isBefore(DateTime.now()) ? DateTime.now() : updatedEnd;
    }
    
    // 重新设置通知时间
    if (_isResting && _restSeconds > 0) {
      _requestRestNotificationSchedule();
      _showOngoingRestNotification();
    }
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  void _showRestFinishedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Rest Finished!", style: TextStyle(color: Color(0xFFBB86FC), fontSize: 24, fontWeight: FontWeight.bold)),
        content: const Text("Time for the next set!", style: TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () {
              _stopAlarm();
              Navigator.pop(context);
            },
            child: const Text("GOT IT", style: TextStyle(color: Color(0xFFBB86FC), fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _persistCompletionState() async {
    final prefs = await SharedPreferences.getInstance();
    final completionString = prefs.getString(_prefsCompletionKey);
    Map<String, dynamic> completionMap = {};
    if (completionString != null) {
      completionMap = json.decode(completionString);
    }

    final key = _normalizeDate(DateTime.now()).toIso8601String();
    final completionState = exercises
        .map((exercise) => exercise.sets.map((set) => set.isCompleted).toList())
        .toList();
    completionMap[key] = completionState;
    await prefs.setString(_prefsCompletionKey, json.encode(completionMap));
  }

  // --- 数据加载 ---
  Future<void> _loadTodayPlan() async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString('events_data');
    String? templatesString = prefs.getString(_prefsPlanTemplatesKey);
    String? extrasString = prefs.getString(_prefsDailyExtrasKey);
    
    setState(() {
      _planTitle = "Rest Day";
      exercises = [];
      _planCount = 0;
    });
    
    if (jsonString == null) return;

    Map<String, dynamic> decodedMap = json.decode(jsonString);
    DateTime today = _normalizeDate(DateTime.now());
    String key = today.toIso8601String();

    List<dynamic> plans = decodedMap[key] ?? [];
    String? planName = plans.isNotEmpty ? plans.first.toString() : null;
    if (planName == null || planName.isEmpty) return;

    List<Exercise> planExercises = [];
    if (templatesString != null) {
      final Map<String, dynamic> templates = json.decode(templatesString);
      if (templates.containsKey(planName)) {
        final List<dynamic> rawExercises = templates[planName] ?? [];
        planExercises = _parseExercises(rawExercises);
      }
    } else {
      // 兼容旧标签模板
      planExercises = ExerciseLibrary.getExercisesForList([planName]);
    }

    // 今日被隐藏的计划动作（仅今日不显示，不改变模板）
    Set<String> hiddenToday = {};
    final hiddenString = prefs.getString(_prefsHiddenPlanKey);
    if (hiddenString != null) {
      final Map<String, dynamic> hiddenMap = json.decode(hiddenString);
      final list = hiddenMap[key];
      if (list != null) {
        hiddenToday = (list as List<dynamic>).map((e) => e.toString()).toSet();
      }
    }
    planExercises = planExercises.where((e) => !hiddenToday.contains(e.name)).toList();

    List<Exercise> extraExercises = [];
    if (extrasString != null) {
      final Map<String, dynamic> extras = json.decode(extrasString);
      if (extras.containsKey(key)) {
        final List<dynamic> rawExtras = extras[key] ?? [];
        extraExercises = _parseExercises(rawExtras);
      }
    }

    final combinedExercises = [...planExercises, ...extraExercises];
    final completionString = prefs.getString(_prefsCompletionKey);
    if (completionString != null) {
      final completionMap = json.decode(completionString);
      final completionForToday = completionMap[key];
      if (completionForToday is List) {
        for (int i = 0; i < combinedExercises.length && i < completionForToday.length; i++) {
          final setFlags = completionForToday[i];
          if (setFlags is List) {
            final sets = combinedExercises[i].sets;
            for (int j = 0; j < sets.length && j < setFlags.length; j++) {
              final flag = setFlags[j];
              if (flag is bool) {
                sets[j].isCompleted = flag;
              }
            }
          }
        }
      }
    }

    setState(() {
      _planTitle = planName;
      _planCount = planExercises.length;
      exercises = combinedExercises;
    });
  }

  List<Exercise> _parseExercises(List<dynamic> rawExercises) {
    return rawExercises.map((raw) {
      final data = Map<String, dynamic>.from(raw as Map);
      final String name = (data['name'] ?? '').toString();
      final List<dynamic> rawSets = data['sets'] ?? [];
      final sets = rawSets.map((rawSet) {
        final setData = Map<String, dynamic>.from(rawSet as Map);
        final double weight = (setData['weight'] ?? 0).toDouble();
        final int reps = (setData['reps'] ?? 0).toInt();
        return WorkoutSet(weight: weight, reps: reps);
      }).toList();
      return Exercise(name: name, sets: sets);
    }).toList();
  }

  List<Map<String, dynamic>> _serializeExercises(List<Exercise> list) {
    return list.map((e) {
      return {
        "name": e.name,
        "sets": e.sets.map((s) => {"weight": s.weight, "reps": s.reps}).toList(),
      };
    }).toList();
  }

  Future<void> _appendDailyExtraExercises(List<Exercise> extras) async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString(_prefsDailyExtrasKey);
    Map<String, dynamic> decodedMap = {};

    if (jsonString != null) {
      decodedMap = json.decode(jsonString);
    }

    DateTime today = _normalizeDate(DateTime.now());
    String key = today.toIso8601String();
    List<dynamic> existing = decodedMap[key] ?? [];
    existing.addAll(_serializeExercises(extras));
    decodedMap[key] = existing;

    await prefs.setString(_prefsDailyExtrasKey, json.encode(decodedMap));
  }

  Future<void> _saveExtraExerciseAt(int extraIndex, Exercise updated) async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString(_prefsDailyExtrasKey);
    if (jsonString == null) return;

    Map<String, dynamic> decodedMap = json.decode(jsonString);
    DateTime today = _normalizeDate(DateTime.now());
    String key = today.toIso8601String();
    List<dynamic> list = List<dynamic>.from(decodedMap[key] ?? []);
    if (extraIndex < 0 || extraIndex >= list.length) return;
    list[extraIndex] = _serializeExercises([updated]).first;
    decodedMap[key] = list;
    await prefs.setString(_prefsDailyExtrasKey, json.encode(decodedMap));
  }

  /// 从今日训练中移除计划动作（仅隐藏，不删模板）
  Future<void> _removePlanExerciseFromToday(String exerciseName) async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString(_prefsHiddenPlanKey);
    Map<String, dynamic> decodedMap = {};
    if (jsonString != null) decodedMap = json.decode(jsonString);

    DateTime today = _normalizeDate(DateTime.now());
    String key = today.toIso8601String();
    List<dynamic> list = List<dynamic>.from(decodedMap[key] ?? []);
    if (!list.contains(exerciseName)) list.add(exerciseName);
    decodedMap[key] = list;

    await prefs.setString(_prefsHiddenPlanKey, json.encode(decodedMap));
    await _loadTodayPlan();
  }

  /// 删除当日额外动作中的某一项
  Future<void> _removeExtraExercise(int extraIndex) async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString(_prefsDailyExtrasKey);
    if (jsonString == null) return;

    Map<String, dynamic> decodedMap = json.decode(jsonString);
    DateTime today = _normalizeDate(DateTime.now());
    String key = today.toIso8601String();
    List<dynamic> list = List<dynamic>.from(decodedMap[key] ?? []);
    if (extraIndex < 0 || extraIndex >= list.length) return;
    list.removeAt(extraIndex);
    decodedMap[key] = list;

    await prefs.setString(_prefsDailyExtrasKey, json.encode(decodedMap));
    await _loadTodayPlan();
  }

  /// 编辑当日额外动作中的某一项
  void _showEditExtraExerciseDialog(int extraIndex) {
    if (extraIndex < 0 || extraIndex >= exercises.length - _planCount) return;
    final exercise = exercises[_planCount + extraIndex];
    final draft = _ExerciseDraft(
      name: exercise.name,
      weight: exercise.sets.isNotEmpty ? exercise.sets.first.weight.toString() : "0",
      reps: exercise.sets.isNotEmpty ? exercise.sets.first.reps.toString() : "10",
      sets: exercise.sets.length.toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "EDIT EXTRA EXERCISE",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: draft.nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "Exercise name"),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: draft.weightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: "Weight (kg)"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: draft.repsController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: "Reps"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: draft.setsController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: "Sets"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final newExercise = draft.toExercise();
                          if (newExercise == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Please complete all fields"), duration: Duration(seconds: 1))
                            );
                            return;
                          }
                          final prefs = await SharedPreferences.getInstance();
                          String? jsonString = prefs.getString(_prefsDailyExtrasKey);
                          Map<String, dynamic> decodedMap = jsonString != null ? json.decode(jsonString) : {};
                          DateTime today = _normalizeDate(DateTime.now());
                          String key = today.toIso8601String();
                          List<dynamic> list = List<dynamic>.from(decodedMap[key] ?? []);
                          if (extraIndex < list.length) {
                            list[extraIndex] = _serializeExercises([newExercise]).first;
                            decodedMap[key] = list;
                            await prefs.setString(_prefsDailyExtrasKey, json.encode(decodedMap));
                            await _loadTodayPlan();
                          }
                          if (mounted) Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFBB86FC),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("SAVE", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() => draft.dispose());
  }

  // --- 交互逻辑 ---
  void _handleSetToggle(int exIndex, int setIndex) {
    if (_isResting) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Resting... Please wait"), duration: Duration(milliseconds: 500))
      );
      return;
    }

    setState(() {
      var set = exercises[exIndex].sets[setIndex];
      bool isFinishing = !set.isCompleted;
      set.isCompleted = isFinishing;
      if (isFinishing) {
        _startRestTimer(seconds: 90);
      }
    });
    _persistCompletionState();
  }

  void _showAddSetDialog(int exIndex) {
    final lastSet = exercises[exIndex].sets.isNotEmpty ? exercises[exIndex].sets.last : null;
    _weightController.text = lastSet?.weight.toString() ?? "0";
    _repsController.text = lastSet?.reps.toString() ?? "10";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Add Set", style: TextStyle(color: Color(0xFFBB86FC))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: "Weight (kg)"),
            ),
            TextField(
              controller: _repsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Reps"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              final weight = double.tryParse(_weightController.text);
              final reps = int.tryParse(_repsController.text);
              if (weight == null || reps == null || reps <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter valid numbers"), duration: Duration(seconds: 1))
                );
                return;
              }
              setState(() {
                exercises[exIndex].sets.add(WorkoutSet(weight: weight, reps: reps));
              });
              if (exIndex >= _planCount) {
                _saveExtraExerciseAt(exIndex - _planCount, exercises[exIndex]);
              }
              _persistCompletionState();
              Navigator.pop(context);
            },
            child: const Text("ADD", style: TextStyle(color: Color(0xFFBB86FC))),
          ),
        ],
      ),
    );
  }

  void _showEditSetDialog(int exIndex, int setIndex) {
    if (exIndex < 0 || exIndex >= exercises.length) return;
    if (setIndex < 0 || setIndex >= exercises[exIndex].sets.length) return;
    final set = exercises[exIndex].sets[setIndex];
    _weightController.text = set.weight.toString();
    _repsController.text = set.reps.toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Edit Set", style: TextStyle(color: Color(0xFFBB86FC))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: "Weight (kg)"),
            ),
            TextField(
              controller: _repsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Reps"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              final weight = double.tryParse(_weightController.text);
              final reps = int.tryParse(_repsController.text);
              if (weight == null || reps == null || reps <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter valid numbers"), duration: Duration(seconds: 1))
                );
                return;
              }
              setState(() {
                exercises[exIndex].sets[setIndex].weight = weight;
                exercises[exIndex].sets[setIndex].reps = reps;
              });
              if (exIndex >= _planCount) {
                _saveExtraExerciseAt(exIndex - _planCount, exercises[exIndex]);
              }
              Navigator.pop(context);
            },
            child: const Text("SAVE", style: TextStyle(color: Color(0xFFBB86FC))),
          ),
        ],
      ),
    );
  }

  void _deleteSet(int exIndex, int setIndex) {
    if (exIndex < 0 || exIndex >= exercises.length) return;
    if (setIndex < 0 || setIndex >= exercises[exIndex].sets.length) return;
    setState(() {
      exercises[exIndex].sets.removeAt(setIndex);
    });
    if (exIndex >= _planCount) {
      _saveExtraExerciseAt(exIndex - _planCount, exercises[exIndex]);
    }
    _persistCompletionState();
  }

  void _showAddExtraExerciseDialog() {
    if (_planTitle == "Rest Day") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a plan for today first"), duration: Duration(seconds: 1))
      );
      return;
    }
    final _ExerciseDraft draft = _ExerciseDraft();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "ADD EXTRA EXERCISE",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: draft.nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "Exercise name"),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: draft.weightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: "Weight (kg)"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: draft.repsController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: "Reps"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: draft.setsController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: "Sets"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final exercise = draft.toExercise();
                          if (exercise == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Please complete all fields"), duration: Duration(seconds: 1))
                            );
                            return;
                          }
                          await _appendDailyExtraExercises([exercise]);
                          await _loadTodayPlan();
                          if (mounted) Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFBB86FC),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("ADD", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      draft.dispose();
    });
  }

  // --- 页面构建 ---
  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 要求
    
    return Scaffold(
      floatingActionButton: _isResting ? null : FloatingActionButton(
        onPressed: _showAddExtraExerciseDialog,
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: _isResting ? 100 : 0),
              child: CustomScrollView(
                slivers: [
                  _buildHeaderSection(),
                  _buildMainContent(),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
            if (_isResting)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: RestTimerPanel(
                  timerString: _timerString,
                  progress: _restSeconds / (_totalRestSeconds <= 0 ? 1 : _totalRestSeconds),
                  onSkip: _stopRestTimer,
                  onAdjust: _adjustTime,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("TODAY'S SESSION", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(_planTitle, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: -1.0)),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_planTitle == "Rest Day") {
      return SliverToBoxAdapter(
        child: Container(
          height: 300, alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bedtime, size: 64, color: Colors.white.withOpacity(0.2)),
              const SizedBox(height: 16),
              Text("Rest & Recover", style: TextStyle(color: Colors.white.withOpacity(0.5))),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => ExerciseCard(
          exercise: exercises[index],
          onSetToggle: (setIndex) => _handleSetToggle(index, setIndex),
          onAddSet: () => _showAddSetDialog(index),
          onEditSet: (setIndex) => _showEditSetDialog(index, setIndex),
          onDeleteSet: (setIndex) => _deleteSet(index, setIndex),
          onRemove: () {
            if (index < _planCount) {
              _removePlanExerciseFromToday(exercises[index].name);
            } else {
              _removeExtraExercise(index - _planCount);
            }
          },
          onEdit: index >= _planCount ? () => _showEditExtraExerciseDialog(index - _planCount) : null,
          isExtra: index >= _planCount,
        ),
        childCount: exercises.length,
      ),
    );
  }
}

class _ExerciseDraft {
  final TextEditingController nameController;
  final TextEditingController weightController;
  final TextEditingController repsController;
  final TextEditingController setsController;

  _ExerciseDraft({
    String name = "",
    String weight = "0",
    String reps = "10",
    String sets = "3",
  })  : nameController = TextEditingController(text: name),
        weightController = TextEditingController(text: weight),
        repsController = TextEditingController(text: reps),
        setsController = TextEditingController(text: sets);

  Exercise? toExercise() {
    final name = nameController.text.trim();
    final weight = double.tryParse(weightController.text);
    final reps = int.tryParse(repsController.text);
    final sets = int.tryParse(setsController.text);

    if (name.isEmpty || weight == null || reps == null || sets == null) {
      return null;
    }
    if (reps <= 0 || sets <= 0 || weight < 0) return null;

    return Exercise(
      name: name,
      sets: List.generate(sets, (_) => WorkoutSet(weight: weight, reps: reps)),
    );
  }

  void dispose() {
    nameController.dispose();
    weightController.dispose();
    repsController.dispose();
    setsController.dispose();
  }
}