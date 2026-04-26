import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/workout_model.dart';
import 'plan_settings_page.dart';
import '../services/app_data_repository.dart';
import '../services/app_strings.dart';
import '../services/app_theme.dart';
import '../services/weight_unit_settings.dart';
import '../widgets/premium_widgets.dart';

class PlanPage extends StatefulWidget {
  const PlanPage({super.key});

  @override
  State<PlanPage> createState() => PlanPageState();
}

class PlanPageState extends State<PlanPage> {
  final AppDataRepository _appDataRepository = AppDataRepository();

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // 模拟数据：未来的训练计划
  // 真实开发中，这里的数据会从数据库读取
  final Map<DateTime, List<String>> _events = {
    DateTime.utc(2024, 2, 14): ['Chest Day', '30min Cardio'],
    DateTime.utc(2024, 2, 15): ['Back & Biceps'],
    DateTime.utc(2024, 2, 16): ['Leg Day (Heavy)'],
  };
  final Map<DateTime, Set<String>> _completedByDate = {};
  List<String> _templateNames = [];
  List<Exercise> _selectedDayExercises = [];

  @override
  void dispose() {
    super.dispose();
  }

  void refreshData() {
    _loadEventsFromPrefs();
    _loadCompletedFromPrefs();
    _loadTemplatesFromPrefs();
    _loadSelectedDayDetails();
  }

 @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEventsFromPrefs(); // <--- App 启动时加载数据
    _loadCompletedFromPrefs();
    _loadTemplatesFromPrefs();
    _loadSelectedDayDetails();
  }

  List<String> _getEventsForDay(DateTime day) {
    // 使用辅助函数统一时间格式
    final dateKey = _normalizeDate(day);
    return _events[dateKey] ?? [];
  }

  // 2. 辅助函数：标准化日期（去除时分秒，只保留年月日，确保Key一致）
  DateTime _normalizeDate(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  Set<String> _getCompletedForDay(DateTime day) {
    final dateKey = _normalizeDate(day);
    return _completedByDate[dateKey] ?? {};
  }

  bool _isDayCompleted(DateTime day) {
    final dateKey = _normalizeDate(day);
    final events = _events[dateKey] ?? [];
    if (events.isEmpty) return false;
    final completed = _completedByDate[dateKey] ?? {};
    return events.every(completed.contains);
  }

  bool _isEventCompleted(DateTime day, String planName) {
    final completed = _getCompletedForDay(day);
    return completed.contains(planName);
  }

  // 从硬盘读取数据
  Future<void> _loadEventsFromPrefs() async {
    final scheduledPlans = await _appDataRepository.loadScheduledPlans();
    setState(() {
      _events
        ..clear()
        ..addAll(scheduledPlans);
    });
    _loadSelectedDayDetails();
  }

  Future<void> _saveCompletedToPrefs() async {
    await _appDataRepository.saveCompletedPlans(_completedByDate);
  }

  Future<void> _loadCompletedFromPrefs() async {
    final completedPlans = await _appDataRepository.loadCompletedPlans();
    setState(() {
      _completedByDate
        ..clear()
        ..addAll(completedPlans);
    });
  }

  Future<void> _loadTemplatesFromPrefs() async {
    final templateNames = await _appDataRepository.loadTemplateNames();
    setState(() {
      _templateNames = templateNames;
    });
  }

  Future<void> _loadSelectedDayDetails() async {
    final day = _selectedDay ?? _focusedDay;
    final exercises = await _appDataRepository.loadExercisesForDay(day);

    if (!mounted) return;
    setState(() {
      _selectedDayExercises = exercises;
    });
  }
  void _showAddEventDialog() {
    final colors = context.appColors;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppStrings.of(context).selectPlan,
                          style: TextStyle(
                      color: colors.subtleText,
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
              if (_templateNames.isEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.of(context).noPlanTemplatesYet,
                      style: TextStyle(color: colors.mutedText),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PlanSettingsPage()),
                          );
                          _loadTemplatesFromPrefs();
                          _loadSelectedDayDetails();
                        },
                        child: Text(AppStrings.of(context).goToPlanSettings),
                      ),
                    ),
                  ],
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: _templateNames.map((planName) {
                      return ListTile(
                        title: Text(planName),
                        onTap: () async {
                          await _savePlanForSelectedDay(planName);
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // 4. 保存事件的逻辑
  Future<void> _savePlanForSelectedDay(String planName) async {
    if (planName.isEmpty) return;

    final dateKey = _normalizeDate(_selectedDay ?? _focusedDay);
    setState(() {
      _events[dateKey] = [planName];
      _completedByDate.remove(dateKey);
    });

    await _appDataRepository.savePlanForDay(dateKey, planName);
    await _saveCompletedToPrefs();
    await _loadSelectedDayDetails();
  }

  void _togglePlanCompleted(String planName) {
    final dateKey = _normalizeDate(_selectedDay ?? _focusedDay);
    final wasCompleted = _isDayCompleted(dateKey);
    setState(() {
      final completed = _completedByDate.putIfAbsent(dateKey, () => <String>{});
      if (completed.contains(planName)) {
        completed.remove(planName);
      } else {
        completed.add(planName);
      }
      if (completed.isEmpty) {
        _completedByDate.remove(dateKey);
      }
    });

    _saveCompletedToPrefs();

    final isCompletedNow = _isDayCompleted(dateKey);
    final todayKey = _normalizeDate(DateTime.now());
    if (!wasCompleted && isCompletedNow && dateKey == todayKey && mounted) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: context.appColors.surface,
            title: Text(
              AppStrings.of(context).greatJob,
              style: const TextStyle(color: Colors.white),
            ),
            content: Text(
              AppStrings.of(context).completedAllPlans,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppStrings.of(context).ok,
                  style: TextStyle(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  void _showPlanDetailsDialog() {
    final colors = context.appColors;
    final strings = AppStrings.of(context);
    final selectedDay = _selectedDay;
    final planName = selectedDay == null
        ? null
        : (_getEventsForDay(selectedDay).isEmpty ? null : _getEventsForDay(selectedDay).first);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.82,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.planDetails,
                              style: TextStyle(
                                color: colors.subtleText,
                                fontSize: 12,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (planName != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                planName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colors.border),
                      ),
                      child: _buildPlanDetailsBody(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: PremiumPageShell(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            children: [
              PremiumSurface(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
                radius: 30,
                child: _buildCalendar(),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: PremiumSurface(
                  padding: const EdgeInsets.all(20),
                  radius: 30,
                  color: colors.surface.withValues(alpha: 0.82),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SectionEyebrow(AppStrings.of(context).schedule),
                          PremiumIconButton(
                            icon: Icons.tune,
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const PlanSettingsPage()),
                              );
                              _loadTemplatesFromPrefs();
                              _loadSelectedDayDetails();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 720;
                            if (isNarrow) {
                              return _buildCompactSchedulePane();
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildEventList()),
                                const SizedBox(width: 16),
                                Expanded(child: _buildPlanDetails()),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // 添加计划的浮动按钮
      // ... Scaffold 的其他部分 ...
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEventDialog, // <--- 修改这里，调用新方法
        backgroundColor: theme.colorScheme.primary,
        child: Icon(Icons.add, color: colors.accentForeground),
      ),
    );
  }

  Widget _buildCompactSchedulePane() {
    final colors = context.appColors;
    final strings = AppStrings.of(context);
    final events = _getEventsForDay(_selectedDay!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (events.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showPlanDetailsDialog,
                icon: const Icon(Icons.open_in_full, size: 18),
                label: Text(strings.viewPlanDetails),
                style: OutlinedButton.styleFrom(
                  backgroundColor: colors.surfaceElevated,
                ),
              ),
            ),
          ),
        Expanded(child: _buildEventList()),
      ],
    );
  }

  Widget _buildCalendar() {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return TableCalendar(
      firstDay: DateTime.utc(2023, 10, 16),
      lastDay: DateTime.utc(2030, 3, 14),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,

      // --- 修正部分开始 ---
      // 这里的 textStyle 属性必须放在 CalendarStyle 里，而不是外面的 theme
      calendarStyle: CalendarStyle(
        // 1. 文字颜色设置
        defaultTextStyle: const TextStyle(color: Colors.white),
        weekendTextStyle: TextStyle(color: colors.mutedText),
        outsideTextStyle: TextStyle(color: Colors.white.withValues(alpha: 0.20)), // 非本月日期颜色

        // 2. 装饰样式
        todayDecoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: TextStyle(
          color: colors.accentForeground,
          fontWeight: FontWeight.bold,
        ),
        markerDecoration: const BoxDecoration(
          color: Colors.grey,
          shape: BoxShape.circle,
        ),
        cellMargin: const EdgeInsets.all(5),
      ),
      // --- 修正部分结束 ---

      // 头部样式 (2024 Feb)
      headerStyle: HeaderStyle(
        titleCentered: true,
        formatButtonVisible: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
        leftChevronIcon: Icon(Icons.chevron_left, color: colors.mutedText),
        rightChevronIcon: Icon(Icons.chevron_right, color: colors.mutedText),
      ),
      
      // 星期栏样式 (Mon, Tue, Wed...)
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(color: colors.subtleText, fontWeight: FontWeight.w700),
        weekendStyle: TextStyle(color: colors.subtleText, fontWeight: FontWeight.w700),
      ),

      // 交互逻辑
      selectedDayPredicate: (day) {
        return isSameDay(_selectedDay, day);
      },
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
        _loadSelectedDayDetails();
      },
      onFormatChanged: (format) {
        setState(() {
          _calendarFormat = format;
        });
      },
      
      eventLoader: _getEventsForDay,
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, day, events) {
          if (events.isEmpty) return null;
          final isCompleted = _isDayCompleted(day);
          final markerColor = isCompleted ? const Color(0xFF4CAF50) : colors.subtleText;
          final count = events.length > 3 ? 3 : events.length;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              count,
              (_) => Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: markerColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEventList() {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final events = _getEventsForDay(_selectedDay!);

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Icon(Icons.hotel_class, size: 48, color: theme.colorScheme.primary.withValues(alpha: 0.55)),
            const SizedBox(height: 16),
            Text(
              AppStrings.of(context).restDay,
              style: TextStyle(
                color: colors.mutedText,
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: events.length,
      itemBuilder: (context, index) {
        final eventText = events[index];
        final isCompleted = _isEventCompleted(_selectedDay!, eventText);
        
        // 使用 Dismissible 包裹内容，实现滑动删除
        return Dismissible(
          key: UniqueKey(), // 每个条目需要唯一的Key
          direction: DismissDirection.endToStart, // 只能从右向左滑
          
          // 红色背景 + 垃圾桶图标
          background: Container(
            alignment: Alignment.centerRight,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          
          // 当滑动发生时触发
          onDismissed: (direction) async {
            setState(() {
              // 1. 从内存列表中删除
              final dateKey = _normalizeDate(_selectedDay!);
              _events[dateKey]!.removeAt(index);
              _completedByDate[dateKey]?.remove(eventText);
              
              // 如果这天没计划了，把这天的 Key 也删掉（让日历上的小点消失）
              if (_events[dateKey]!.isEmpty) {
                _events.remove(dateKey);
                _completedByDate.remove(dateKey);
              } else if (_completedByDate[dateKey]?.isEmpty ?? false) {
                _completedByDate.remove(dateKey);
              }
            });
            
            // 2. 立即同步到硬盘
            await _appDataRepository.deletePlanForDay(_selectedDay!, index);
            await _saveCompletedToPrefs();
            await _loadSelectedDayDetails();
            if (!context.mounted) return;

            // 3. 提示用户
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppStrings.of(context).planDeleted),
                duration: const Duration(seconds: 1),
                backgroundColor: colors.surface,
              ),
            );
          },

          // 这里是原本的列表项 UI
          child: GestureDetector(
            onTap: () => _togglePlanCompleted(eventText),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isCompleted ? Colors.green.withValues(alpha: 0.28) : colors.border,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCompleted ? const Color(0xFF4CAF50) : theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      eventText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isCompleted ? Colors.white70 : Colors.white,
                        decoration: isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                      ),
                    ),
                  ),
                  Icon(
                    isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isCompleted ? const Color(0xFF4CAF50) : Colors.white.withValues(alpha: 0.2),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlanDetails() {
    final colors = context.appColors;
    final strings = AppStrings.of(context);
    final selectedDay = _selectedDay;
    final planName = selectedDay == null ? null : (_getEventsForDay(selectedDay).isEmpty ? null : _getEventsForDay(selectedDay).first);

    return PremiumSurface(
      padding: const EdgeInsets.all(16),
      radius: 22,
      color: colors.surfaceElevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionEyebrow(strings.planDetails),
          const SizedBox(height: 10),
          if (planName != null)
            Text(
              planName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (planName != null) const SizedBox(height: 12),
          Expanded(child: _buildPlanDetailsBody()),
        ],
      ),
    );
  }

  Widget _buildPlanDetailsBody() {
    final colors = context.appColors;
    final strings = AppStrings.of(context);
    final selectedDay = _selectedDay;
    final planName = selectedDay == null
        ? null
        : (_getEventsForDay(selectedDay).isEmpty ? null : _getEventsForDay(selectedDay).first);

    if (_selectedDayExercises.isEmpty) {
      return Center(
        child: Text(
          planName == null ? strings.restDay : strings.noPlanDetails,
          style: TextStyle(color: colors.subtleText),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ValueListenableBuilder<WeightUnit>(
      valueListenable: WeightUnitController.unit,
      builder: (context, unit, _) => ListView.separated(
        itemCount: _selectedDayExercises.length,
        separatorBuilder: (context, index) => Divider(color: colors.border, height: 20),
        itemBuilder: (context, index) {
          final exercise = _selectedDayExercises[index];
          final totalSets = exercise.sets.length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exercise.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_exerciseTypeText(strings, exercise)}  ${strings.sets}: $totalSets',
                style: TextStyle(color: colors.subtleText, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: exercise.sets.map((set) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.softFill,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _buildSetSummary(set, unit),
                      style: TextStyle(color: colors.mutedText, fontSize: 12),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  String _exerciseTypeText(AppStrings strings, Exercise exercise) {
    switch (exercise.type) {
      case ExerciseType.weighted:
        return strings.weightedExercise;
      case ExerciseType.timed:
        return strings.timedExercise;
      case ExerciseType.free:
        return strings.freeExercise;
    }
  }

  String _buildSetSummary(WorkoutSet set, WeightUnit unit) {
    if (set.customValues.isNotEmpty) {
      return set.customValues.entries.map((entry) => '${entry.key}: ${entry.value}').join(' · ');
    }
    final parts = <String>[];
    if (set.weight != null) {
      parts.add(WeightUnitController.formatWeight(set.weight!, unit));
    }
    if (set.reps != null) {
      parts.add('${set.reps} ${AppStrings.of(context).reps.toLowerCase()}');
    }
    if (set.duration != null) {
      parts.add('${set.duration}s');
    }
    return parts.join(' · ');
  }
}
