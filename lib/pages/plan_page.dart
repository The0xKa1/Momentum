import 'dart:convert'; // 用于把数据转换成 JSON 字符串
import 'package:shared_preferences/shared_preferences.dart'; // 硬盘存储工具
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/workout_model.dart';
import 'plan_settings_page.dart';
import '../services/app_strings.dart';
import '../services/app_theme.dart';
import '../services/weight_unit_settings.dart';

class PlanPage extends StatefulWidget {
  const PlanPage({super.key});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  static const String _prefsPlanTemplatesKey = "plan_templates";
  static const String _prefsDailyExtrasKey = "daily_extra_workout_data";
  static const String _prefsHiddenPlanKey = "hidden_plan_today";

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

  // 把数据存入硬盘
  Future<void> _saveEventsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. 因为 JSON 不支持 DateTime 对象做 Key，我们需要把 Key 转成 String
    // 目标格式: {"2024-02-14Z": ["Chest Day"], ...}
    Map<String, dynamic> encodeMap = {};
    
    _events.forEach((key, value) {
      encodeMap[key.toIso8601String()] = value;
    });

    // 2. 转成 JSON 字符串并保存
    String jsonString = json.encode(encodeMap);
    await prefs.setString('events_data', jsonString);
  }

  // 从硬盘读取数据
  Future<void> _loadEventsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. 获取字符串，如果没有数据就返回
    String? jsonString = prefs.getString('events_data');
    if (jsonString == null) return;

    // 2. 解析 JSON
    Map<String, dynamic> decodedMap = json.decode(jsonString);
    
    // 3. 把 String Key 还原回 DateTime，并更新状态
    setState(() {
      _events.clear(); // 清空默认的模拟数据
      decodedMap.forEach((key, value) {
        // value 是 dynamic (List<dynamic>)，需要强转成 List<String>
        DateTime dateKey = DateTime.parse(key);
        List<String> plans = List<String>.from(value);
        
        // 这里也要做一次标准化，确保时区不出错
        _events[_normalizeDate(dateKey)] = plans;
      });
    });
    _loadSelectedDayDetails();
  }

  Future<void> _saveCompletedToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> encoded = {};
    _completedByDate.forEach((key, value) {
      encoded[key.toIso8601String()] = value.toList();
    });
    await prefs.setString('completed_plans', json.encode(encoded));
  }

  Future<void> _loadCompletedFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('completed_plans');
    if (jsonString == null) return;

    final Map<String, dynamic> decoded = json.decode(jsonString);
    setState(() {
      _completedByDate.clear();
      decoded.forEach((key, value) {
        final dateKey = _normalizeDate(DateTime.parse(key));
        final plans = Set<String>.from(value as List);
        _completedByDate[dateKey] = plans;
      });
    });
  }

  Future<void> _loadTemplatesFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefsPlanTemplatesKey);
    if (jsonString == null) {
      setState(() {
        _templateNames = [];
      });
      return;
    }

    Map<String, dynamic> decodedMap = json.decode(jsonString);
    setState(() {
      _templateNames = decodedMap.keys.toList();
    });
  }

  List<Exercise> _parseExercises(List<dynamic> rawExercises) {
    return rawExercises.map((raw) {
      final data = Map<String, dynamic>.from(raw as Map);
      final name = (data['name'] ?? '').toString();
      final rawSets = List<dynamic>.from(data['sets'] ?? []);
      final sets = rawSets.map((rawSet) {
        final setData = Map<String, dynamic>.from(rawSet as Map);
        return WorkoutSet(
          weight: (setData['weight'] ?? 0).toDouble(),
          reps: (setData['reps'] ?? 0).toInt(),
        );
      }).toList();
      return Exercise(name: name, sets: sets);
    }).toList();
  }

  Future<void> _loadSelectedDayDetails() async {
    final day = _selectedDay ?? _focusedDay;
    final dateKey = _normalizeDate(day);
    final planNames = _events[dateKey] ?? [];
    if (planNames.isEmpty) {
      if (!mounted) return;
      setState(() {
        _selectedDayExercises = [];
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final templateString = prefs.getString(_prefsPlanTemplatesKey);
    final extrasString = prefs.getString(_prefsDailyExtrasKey);
    final hiddenString = prefs.getString(_prefsHiddenPlanKey);
    final key = dateKey.toIso8601String();
    final planName = planNames.first;

    List<Exercise> planExercises = [];
    if (templateString != null) {
      final templates = Map<String, dynamic>.from(json.decode(templateString));
      if (templates.containsKey(planName)) {
        planExercises = _parseExercises(List<dynamic>.from(templates[planName] ?? []));
      }
    }

    final hiddenNames = <String>{};
    if (hiddenString != null) {
      final hiddenMap = Map<String, dynamic>.from(json.decode(hiddenString));
      final hiddenList = hiddenMap[key];
      if (hiddenList is List) {
        hiddenNames.addAll(hiddenList.map((e) => e.toString()));
      }
    }
    planExercises = planExercises.where((exercise) => !hiddenNames.contains(exercise.name)).toList();

    List<Exercise> extraExercises = [];
    if (extrasString != null) {
      final extrasMap = Map<String, dynamic>.from(json.decode(extrasString));
      final rawExtras = extrasMap[key];
      if (rawExtras is List) {
        extraExercises = _parseExercises(List<dynamic>.from(rawExtras));
      }
    }

    if (!mounted) return;
    setState(() {
      _selectedDayExercises = [...planExercises, ...extraExercises];
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
                        onTap: () {
                          _savePlanForSelectedDay(planName);
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
  void _savePlanForSelectedDay(String planName) {
    if (planName.isEmpty) return;

    setState(() {
      final dateKey = _normalizeDate(_selectedDay ?? _focusedDay);
      _events[dateKey] = [planName];
      _completedByDate.remove(dateKey);
    });

    _saveEventsToPrefs();
    _saveCompletedToPrefs();
    _loadSelectedDayDetails();
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
        child: Column(
          children: [
            // 1. 日历组件
            _buildCalendar(),
            
            const SizedBox(height: 20),
            
            // 2. 选中日期的详细计划
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppStrings.of(context).schedule,
                          style: TextStyle(
                            color: colors.subtleText,
                            fontSize: 12,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.tune, color: Colors.grey, size: 20),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  foregroundColor: Colors.white,
                  side: BorderSide(color: colors.border),
                  backgroundColor: colors.surfaceElevated,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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
        weekendTextStyle: const TextStyle(color: Colors.grey),
        outsideTextStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)), // 非本月日期颜色
        
        // 2. 装饰样式
        todayDecoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
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
      ),
      // --- 修正部分结束 ---

      // 头部样式 (2024 Feb)
      headerStyle: HeaderStyle(
        titleCentered: true,
        formatButtonVisible: false,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.white),
        rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.white),
      ),
      
      // 星期栏样式 (Mon, Tue, Wed...)
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(color: Colors.white70),
        weekendStyle: TextStyle(color: Colors.grey),
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
            Icon(Icons.hotel_class, size: 48, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
                Text(
                  AppStrings.of(context).restDay,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
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
          onDismissed: (direction) {
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
            _saveEventsToPrefs();
            _saveCompletedToPrefs();
            _loadSelectedDayDetails();

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
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
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
          final totalReps = exercise.sets.fold<int>(0, (sum, set) => sum + set.reps);
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
                '${strings.sets}: $totalSets  ${strings.reps}: $totalReps',
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
                      '${WeightUnitController.formatWeight(set.weight, unit)} x ${set.reps}',
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
}
