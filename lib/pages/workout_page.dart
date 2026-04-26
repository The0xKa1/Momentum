import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

// 引入模型和库
import '../models/workout_model.dart';
import '../services/app_data_repository.dart';
import '../services/rest_timer_alarm.dart';
import '../services/app_strings.dart';
import '../services/app_theme.dart';
import '../services/rest_sound_settings.dart';
import '../services/weight_unit_settings.dart';

// 引入拆分出的组件模块
import '../widgets/exercise_card.dart';
import '../widgets/rest_timer_panel.dart';
import '../widgets/premium_widgets.dart';

class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key});

  @override
  State<WorkoutPage> createState() => WorkoutPageState();
}

class WorkoutPageState extends State<WorkoutPage> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  // 保持页面状态，切换标签不销毁
  @override
  bool get wantKeepAlive => true;

  final AppDataRepository _appDataRepository = AppDataRepository();

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

  void refreshData() {
    _loadTodayPlan();
  }

  WeightUnit get _weightUnit => WeightUnitController.unit.value;

  int get _totalSetCount => exercises.fold<int>(0, (sum, exercise) => sum + exercise.sets.length);

  int get _completedSetCount => exercises.fold<int>(
        0,
        (sum, exercise) => sum + exercise.sets.where((set) => set.isCompleted).length,
      );

  double get _completionProgress {
    final total = _totalSetCount;
    if (total == 0) return 0;
    return _completedSetCount / total;
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
    await _audioPlayer.setLoopMode(LoopMode.one);
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
    final androidDetails = await buildRestTimerFinishedAndroidDetails();
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    
    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    // 在指定时间后显示通知
    if (!mounted) return;
    final strings = AppStrings.of(context);
    await restTimerNotificationsPlugin.zonedSchedule(
      id: restTimerNotificationId,
      title: strings.restTimeOverTitle,
      body: strings.restTimeOverBody,
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
    if (!mounted) return;
    final strings = AppStrings.of(context);

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
      title: strings.restingTitle,
      body: strings.countdownInProgress,
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
      final customPath = await RestSoundController.getSavedSoundPath();
      if (customPath != null && customPath.isNotEmpty) {
        // 尝试播放用户自定义铃声（循环播放）
        await _audioPlayer.setFilePath(customPath);
      } else {
        // 播放默认提醒音（循环播放）
        await _audioPlayer.setAsset('assets/sounds/alarm.mp3');
      }
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('播放提醒音失败: $e，尝试使用默认或在线提示音');
      // 如果自定义失败，回退到默认音频
      try {
        await _audioPlayer.setAsset('assets/sounds/alarm.mp3');
        await _audioPlayer.play();
      } catch (e2) {
        debugPrint('播放默认提醒音失败: $e2，尝试在线提示音');
        try {
          await _audioPlayer.setUrl(
            'https://actions.google.com/sounds/v1/alarms/beep_short.ogg',
          );
          await _audioPlayer.play();
        } catch (e3) {
          debugPrint('播放在线提醒音也失败: $e3');
          _isAlarmPlaying = false;
        }
      }
    }
  }

  Future<void> _stopAlarm() async {
    if (!_isAlarmPlaying) return;
    
    try {
      await _audioPlayer.stop();
      _isAlarmPlaying = false;
    } catch (e) {
      debugPrint('停止提醒音失败: $e');
    }
  }

  Future<void> _promptRestTimeAndStart() async {
    final strings = AppStrings.of(context);
    final colors = context.appColors;
    final theme = Theme.of(context);
    const options = [30, 60, 90, 120, 180];
    final customController = TextEditingController();

    final selectedSeconds = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          strings.selectRestTime,
          style: TextStyle(color: theme.colorScheme.primary, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((seconds) {
                return ElevatedButton(
                  onPressed: () => Navigator.pop(context, seconds),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: colors.accentForeground,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(strings.restSeconds(seconds), style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: customController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: strings.restSeconds(60),
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: strings.restSeconds(75),
                hintStyle: const TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 0),
            child: Text(strings.skipRest, style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              final seconds = int.tryParse(customController.text);
              if (seconds == null || seconds <= 0) {
                return;
              }
              Navigator.pop(context, seconds);
            },
            child: Text(strings.save, style: TextStyle(color: theme.colorScheme.primary)),
          ),
        ],
      ),
    );

    customController.dispose();
    if (selectedSeconds != null && selectedSeconds > 0) {
      _startRestTimer(seconds: selectedSeconds);
    }
  }

  void _showRestFinishedDialog() {
    final colors = context.appColors;
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          AppStrings.of(context).restFinished,
          style: TextStyle(color: theme.colorScheme.primary, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: Text(AppStrings.of(context).timeForNextSet, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () {
              _stopAlarm();
              Navigator.pop(context);
            },
            child: Text(
              AppStrings.of(context).gotIt,
              style: TextStyle(color: theme.colorScheme.primary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _persistCompletionState() async {
    await _appDataRepository.persistWorkoutCompletionState(DateTime.now(), exercises);
  }

  Future<void> _persistDailyWorkoutSnapshot() async {
    await _appDataRepository.persistWorkoutSnapshot(
      DateTime.now(),
      planTitle: _planTitle,
      planCount: _planCount,
      exercises: exercises,
    );
  }

  // --- 数据加载 ---
  Future<void> _loadTodayPlan() async {
    setState(() {
      _planTitle = "Rest Day";
      exercises = [];
      _planCount = 0;
    });
    final state = await _appDataRepository.loadWorkoutDayState(DateTime.now());

    setState(() {
      _planTitle = state.planTitle;
      _planCount = state.planCount;
      exercises = state.exercises;
    });
    if (state.planTitle != "Rest Day") {
      await _persistDailyWorkoutSnapshot();
    }
  }

  Future<void> _appendDailyExtraExercises(List<Exercise> extras) async {
    await _appDataRepository.appendDailyExtraExercises(DateTime.now(), extras);
    setState(() {
      exercises = [...exercises, ...extras];
    });
    await _persistDailyWorkoutSnapshot();
  }

  Future<void> _saveExtraExerciseAt(int extraIndex, Exercise updated) async {
    await _appDataRepository.saveDailyExtraExerciseAt(DateTime.now(), extraIndex, updated);
    await _persistDailyWorkoutSnapshot();
  }

  /// 从今日训练中移除计划动作（仅隐藏，不删模板）
  Future<void> _removePlanExerciseFromToday(String exerciseName) async {
    await _appDataRepository.hidePlanExerciseForDay(DateTime.now(), exerciseName);
    int planIndex = -1;
    for (int i = 0; i < _planCount && i < exercises.length; i++) {
      if (exercises[i].name == exerciseName) {
        planIndex = i;
        break;
      }
    }
    if (planIndex >= 0) {
      setState(() {
        exercises.removeAt(planIndex);
        _planCount = (_planCount - 1).clamp(0, exercises.length).toInt();
      });
      await _persistCompletionState();
      await _persistDailyWorkoutSnapshot();
    } else {
      await _loadTodayPlan();
    }
  }

  /// 删除当日额外动作中的某一项
  Future<void> _removeExtraExercise(int extraIndex) async {
    await _appDataRepository.removeDailyExtraExerciseAt(DateTime.now(), extraIndex);
    final exerciseIndex = _planCount + extraIndex;
    if (exerciseIndex >= 0 && exerciseIndex < exercises.length) {
      setState(() {
        exercises.removeAt(exerciseIndex);
      });
      await _persistCompletionState();
      await _persistDailyWorkoutSnapshot();
    } else {
      await _loadTodayPlan();
    }
  }

  /// 编辑当日额外动作中的某一项
  void _showEditExtraExerciseDialog(int extraIndex) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    if (extraIndex < 0 || extraIndex >= exercises.length - _planCount) return;
    final exercise = exercises[_planCount + extraIndex];
    final draft = _ExerciseDraft.fromExercise(exercise, _weightUnit);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
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
                            strings.editExtraExercise,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
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
                    _ExerciseDraftForm(
                      draft: draft,
                      unit: _weightUnit,
                      strings: strings,
                      onChanged: () => setModalState(() {}),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final newExercise = draft.toExercise();
                          if (newExercise == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(strings.completeExerciseFields),
                                duration: const Duration(seconds: 1),
                              )
                            );
                            return;
                          }
                          await _appDataRepository.saveDailyExtraExerciseAt(
                            DateTime.now(),
                            extraIndex,
                            newExercise,
                          );
                          await _loadTodayPlan();
                          if (!mounted) return;
                          Navigator.pop(this.context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: colors.accentForeground,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(AppStrings.of(context).save, style: const TextStyle(fontWeight: FontWeight.bold)),
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
  Future<void> _handleSetToggle(int exIndex, int setIndex) async {
    if (_isResting) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(context).restingWait),
          duration: const Duration(milliseconds: 500),
        )
      );
      return;
    }

    bool isFinishing = false;
    setState(() {
      var set = exercises[exIndex].sets[setIndex];
      isFinishing = !set.isCompleted;
      set.isCompleted = isFinishing;
    });
    _persistCompletionState();
    if (isFinishing) {
      await _promptRestTimeAndStart();
    }
  }

  void _showAddSetDialog(int exIndex) {
    final seed = exercises[exIndex].sets.isNotEmpty ? exercises[exIndex].sets.last.copy() : null;
    _showSetEditorDialog(exIndex: exIndex, initialSet: seed);
  }

  void _showEditSetDialog(int exIndex, int setIndex) {
    if (exIndex < 0 || exIndex >= exercises.length) return;
    if (setIndex < 0 || setIndex >= exercises[exIndex].sets.length) return;
    _showSetEditorDialog(
      exIndex: exIndex,
      setIndex: setIndex,
      initialSet: exercises[exIndex].sets[setIndex].copy(),
    );
  }

  void _showSetEditorDialog({
    required int exIndex,
    int? setIndex,
    WorkoutSet? initialSet,
  }) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final exercise = exercises[exIndex];
    final seed = initialSet ?? WorkoutSet();
    final weightController = TextEditingController(
      text: seed.weight == null
          ? ""
          : WeightUnitController.formatNumber(
              WeightUnitController.fromKg(seed.weight!, _weightUnit),
            ),
    );
    final repsController = TextEditingController(text: seed.reps?.toString() ?? "");
    final durationController = TextEditingController(text: seed.duration?.toString() ?? "");
    final customControllers = <String, TextEditingController>{
      for (final field in exercise.customFields)
        field: TextEditingController(text: seed.customValues[field] ?? ""),
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          setIndex == null ? strings.addSet : strings.editSet,
          style: TextStyle(color: theme.colorScheme.primary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (exercise.type == ExerciseType.weighted)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: 180,
                      child: TextField(
                        controller: weightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: strings.weightLabel(WeightUnitController.shortLabel(_weightUnit)),
                          labelStyle: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: repsController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: strings.reps,
                          labelStyle: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (exercise.type == ExerciseType.timed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: durationController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: strings.duration,
                    labelStyle: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            if (exercise.type == ExerciseType.free)
              ...exercise.customFields.map((field) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: customControllers[field],
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: field,
                      labelStyle: const TextStyle(color: Colors.white70),
                    ),
                  ),
                );
              }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.cancel, style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              final nextSet = WorkoutSet(isCompleted: seed.isCompleted);
              if (exercise.type == ExerciseType.weighted) {
                final value = double.tryParse(weightController.text);
                final reps = int.tryParse(repsController.text);
                if (value == null || value < 0 || reps == null || reps <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(strings.pleaseEnterValidNumbers),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                  return;
                }
                nextSet.weight = WeightUnitController.toKg(value, _weightUnit);
                nextSet.reps = reps;
              } else if (exercise.type == ExerciseType.timed) {
                final value = int.tryParse(durationController.text);
                if (value == null || value <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(strings.pleaseEnterValidNumbers),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                  return;
                }
                nextSet.duration = value;
              } else {
                for (final field in exercise.customFields) {
                  final value = customControllers[field]!.text.trim();
                  if (value.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(strings.completeExerciseFields),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                    return;
                  }
                  nextSet.customValues[field] = value;
                }
              }

              setState(() {
                if (setIndex == null) {
                  exercises[exIndex].sets.add(nextSet);
                } else {
                  exercises[exIndex].sets[setIndex] = nextSet;
                }
              });
              if (exIndex >= _planCount) {
                _saveExtraExerciseAt(exIndex - _planCount, exercises[exIndex]);
              }
              _persistCompletionState();
              _persistDailyWorkoutSnapshot();
              Navigator.pop(context);
            },
            child: Text(
              setIndex == null ? strings.add : strings.save,
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    ).whenComplete(() {
      weightController.dispose();
      repsController.dispose();
      durationController.dispose();
      for (final controller in customControllers.values) {
        controller.dispose();
      }
    });
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
    _persistDailyWorkoutSnapshot();
  }

  void _showAddExtraExerciseDialog() {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    if (_planTitle == "Rest Day") {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.pleaseSelectPlanFirst),
          duration: const Duration(seconds: 1),
        )
      );
      return;
    }
    final _ExerciseDraft draft = _ExerciseDraft(unit: _weightUnit);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
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
                            strings.addExtraExercise,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
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
                    _ExerciseDraftForm(
                      draft: draft,
                      unit: _weightUnit,
                      strings: strings,
                      onChanged: () => setModalState(() {}),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final exercise = draft.toExercise();
                          if (exercise == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(strings.completeExerciseFields),
                                duration: const Duration(seconds: 1),
                              )
                            );
                            return;
                          }
                          await _appendDailyExtraExercises([exercise]);
                          await _loadTodayPlan();
                          if (!mounted) return;
                          Navigator.pop(this.context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: colors.accentForeground,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(AppStrings.of(context).add, style: const TextStyle(fontWeight: FontWeight.bold)),
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
    
    final colors = context.appColors;
    return Scaffold(
      floatingActionButton: _isResting ? null : FloatingActionButton(
        onPressed: _showAddExtraExerciseDialog,
        backgroundColor: Theme.of(context).primaryColor,
        child: Icon(Icons.add, color: context.appColors.accentForeground),
      ),
      body: SafeArea(
        child: PremiumPageShell(
          padding: EdgeInsets.zero,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: _isResting ? 112 : 0),
                child: CustomScrollView(
                  slivers: [
                    _buildHeaderSection(),
                    _buildMainContent(),
                    const SliverToBoxAdapter(child: SizedBox(height: 92)),
                  ],
                ),
              ),
              if (_isResting)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colors.background.withValues(alpha: 0.0),
                          colors.background.withValues(alpha: 0.88),
                        ],
                      ),
                    ),
                    child: RestTimerPanel(
                      timerString: _timerString,
                      progress: _restSeconds / (_totalRestSeconds <= 0 ? 1 : _totalRestSeconds),
                      onSkip: _stopRestTimer,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    final strings = AppStrings.of(context);
    final planTitle = _planTitle == "Rest Day" ? strings.restDay : _planTitle;
    final completionPercent = (_completionProgress * 100).round();
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: PremiumSurface(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          radius: 30,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionEyebrow(strings.todaysSession),
                        const SizedBox(height: 10),
                        Text(
                          planTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 34,
                            height: 0.98,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  PremiumProgressRing(
                    progress: _completionProgress,
                    label: '$completionPercent%',
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  PremiumStatPill(
                    label: strings.exercise,
                    value: exercises.length.toString(),
                    icon: Icons.fitness_center,
                  ),
                  PremiumStatPill(
                    label: strings.sets,
                    value: '$_completedSetCount/$_totalSetCount',
                    icon: Icons.done_all,
                  ),
                  PremiumStatPill(
                    label: strings.restLabel,
                    value: _isResting ? _timerString : '90s',
                    icon: Icons.timer_outlined,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_planTitle == "Rest Day") {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: PremiumSurface(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 46),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bedtime, size: 58, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 18),
                Text(
                  AppStrings.of(context).restRecover,
                  style: TextStyle(
                    color: context.appColors.mutedText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => ValueListenableBuilder<WeightUnit>(
          valueListenable: WeightUnitController.unit,
          builder: (context, unit, _) => ExerciseCard(
            exercise: exercises[index],
            unit: unit,
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
        ),
        childCount: exercises.length,
      ),
    );
  }

}

class _ExerciseDraftForm extends StatelessWidget {
  const _ExerciseDraftForm({
    required this.draft,
    required this.unit,
    required this.strings,
    required this.onChanged,
  });

  final _ExerciseDraft draft;
  final WeightUnit unit;
  final AppStrings strings;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: draft.nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: strings.exerciseName,
            labelStyle: const TextStyle(color: Colors.white70),
          ),
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<ExerciseType>(
          initialValue: draft.type,
          decoration: InputDecoration(
            labelText: strings.exerciseType,
            labelStyle: const TextStyle(color: Colors.white70),
          ),
          dropdownColor: Theme.of(context).colorScheme.surface,
          items: [
            DropdownMenuItem(value: ExerciseType.free, child: Text(strings.freeExercise)),
            DropdownMenuItem(value: ExerciseType.weighted, child: Text(strings.weightedExercise)),
            DropdownMenuItem(value: ExerciseType.timed, child: Text(strings.timedExercise)),
          ],
          onChanged: (value) {
            if (value == null) return;
            draft.setType(value);
            onChanged();
          },
        ),
        if (draft.type == ExerciseType.free) ...[
          const SizedBox(height: 10),
          Text(
            strings.customFields,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
          ),
          const SizedBox(height: 8),
          ...List.generate(draft.customFields.length, (index) {
            final field = draft.customFields[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: field.nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: strings.fieldName,
                        labelStyle: const TextStyle(color: Colors.white70),
                      ),
                      onChanged: (_) => onChanged(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: field.valueController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: strings.fieldValue,
                        labelStyle: const TextStyle(color: Colors.white70),
                      ),
                      onChanged: (_) => onChanged(),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      draft.removeCustomFieldAt(index);
                      onChanged();
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  ),
                ],
              ),
            );
          }),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                draft.addCustomField();
                onChanged();
              },
              icon: const Icon(Icons.add, size: 16),
              label: Text(strings.addField),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 160,
              child: TextField(
                controller: draft.setsController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: strings.sets,
                  labelStyle: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
            ...draft.visibleFixedFields(strings, unit),
          ],
        ),
      ],
    );
  }
}

class _ExerciseDraft {
  _ExerciseDraft({
    required this.unit,
    ExerciseType? type,
    String name = "",
    String sets = "3",
    String weight = "",
    String reps = "",
    String duration = "",
    List<_CustomFieldDraft>? customFields,
  })  : type = type ?? ExerciseType.free,
        nameController = TextEditingController(text: name),
        setsController = TextEditingController(text: sets),
        weightController = TextEditingController(text: weight),
        repsController = TextEditingController(text: reps),
        durationController = TextEditingController(text: duration),
        customFields = customFields ?? [_CustomFieldDraft()];

  final WeightUnit unit;
  ExerciseType type;
  final TextEditingController nameController;
  final TextEditingController setsController;
  final TextEditingController weightController;
  final TextEditingController repsController;
  final TextEditingController durationController;
  final List<_CustomFieldDraft> customFields;

  factory _ExerciseDraft.fromExercise(Exercise exercise, WeightUnit unit) {
    final firstSet = exercise.sets.isNotEmpty ? exercise.sets.first : WorkoutSet();
    return _ExerciseDraft(
      unit: unit,
      type: exercise.type,
      name: exercise.name,
      sets: exercise.sets.isEmpty ? "1" : exercise.sets.length.toString(),
      weight: firstSet.weight == null
          ? ""
          : WeightUnitController.formatNumber(
              WeightUnitController.fromKg(firstSet.weight!, unit),
            ),
      reps: firstSet.reps?.toString() ?? "",
      duration: firstSet.duration?.toString() ?? "",
      customFields: exercise.type == ExerciseType.free
          ? exercise.customFields
              .map(
                (field) => _CustomFieldDraft(
                  name: field,
                  value: firstSet.customValues[field] ?? "",
                ),
              )
              .toList()
          : [],
    );
  }

  void setType(ExerciseType value) {
    type = value;
    if (value == ExerciseType.free && customFields.isEmpty) {
      customFields.add(_CustomFieldDraft());
    }
  }

  void addCustomField() {
    customFields.add(_CustomFieldDraft());
  }

  void removeCustomFieldAt(int index) {
    if (index < 0 || index >= customFields.length) return;
    final field = customFields.removeAt(index);
    field.dispose();
    if (customFields.isEmpty) {
      customFields.add(_CustomFieldDraft());
    }
  }

  List<Widget> visibleFixedFields(AppStrings strings, WeightUnit unit) {
    if (type == ExerciseType.weighted) {
      return [
        SizedBox(
          width: 160,
          child: TextField(
            controller: weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: strings.weightLabel(WeightUnitController.shortLabel(unit)),
              labelStyle: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
        SizedBox(
          width: 160,
          child: TextField(
            controller: repsController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: strings.reps,
              labelStyle: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ];
    }
    if (type == ExerciseType.timed) {
      return [
        SizedBox(
          width: 160,
          child: TextField(
            controller: durationController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: strings.duration,
              labelStyle: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ];
    }
    return const [];
  }

  Exercise? toExercise() {
    final name = nameController.text.trim();
    final setCount = int.tryParse(setsController.text);
    if (name.isEmpty || setCount == null || setCount <= 0) {
      return null;
    }

    final set = WorkoutSet();
    if (type == ExerciseType.weighted) {
      final value = double.tryParse(weightController.text);
      final reps = int.tryParse(repsController.text);
      if (value == null || value < 0 || reps == null || reps <= 0) {
        return null;
      }
      set.weight = WeightUnitController.toKg(value, unit);
      set.reps = reps;
      return Exercise(
        name: name,
        type: type,
        sets: List.generate(setCount, (_) => set.copy()),
      );
    }

    if (type == ExerciseType.timed) {
      final value = int.tryParse(durationController.text);
      if (value == null || value <= 0) {
        return null;
      }
      set.duration = value;
      return Exercise(
        name: name,
        type: type,
        sets: List.generate(setCount, (_) => set.copy()),
      );
    }

    final fields = <String>[];
    final values = <String, String>{};
    for (final fieldDraft in customFields) {
      final fieldName = fieldDraft.nameController.text.trim();
      final fieldValue = fieldDraft.valueController.text.trim();
      if (fieldName.isEmpty || fieldValue.isEmpty) continue;
      fields.add(fieldName);
      values[fieldName] = fieldValue;
    }
    if (fields.isEmpty) return null;
    set.customValues = values;
    return Exercise(
      name: name,
      type: type,
      customFields: fields,
      sets: List.generate(setCount, (_) => set.copy()),
    );
  }

  void dispose() {
    nameController.dispose();
    setsController.dispose();
    weightController.dispose();
    repsController.dispose();
    durationController.dispose();
    for (final field in customFields) {
      field.dispose();
    }
  }
}

class _CustomFieldDraft {
  _CustomFieldDraft({
    String name = "",
    String value = "",
  })  : nameController = TextEditingController(text: name),
        valueController = TextEditingController(text: value);

  final TextEditingController nameController;
  final TextEditingController valueController;

  void dispose() {
    nameController.dispose();
    valueController.dispose();
  }
}
