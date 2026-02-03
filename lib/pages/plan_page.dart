import 'dart:convert'; // 用于把数据转换成 JSON 字符串
import 'package:shared_preferences/shared_preferences.dart'; // 硬盘存储工具
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class PlanPage extends StatefulWidget {
  const PlanPage({super.key});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
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

  // 预设的快捷选项
  final List<String> _presets = [
    "Chest", "Back", "Legs", 
    "Shoulders", "Arms", "Cardio", "Rest"
  ];

  @override
  void dispose() {
    _eventController.dispose();
    super.dispose();
  }

 @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEventsFromPrefs(); // <--- App 启动时加载数据
  }

  List<String> _getEventsForDay(DateTime day) {
    // 使用辅助函数统一时间格式
    final dateKey = _normalizeDate(day);
    return _events[dateKey] ?? [];
  }

  // 1. 用于获取用户输入的控制器
  final TextEditingController _eventController = TextEditingController();

  // 2. 辅助函数：标准化日期（去除时分秒，只保留年月日，确保Key一致）
  DateTime _normalizeDate(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
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
  }
void _showAddEventDialog() {
    // 清空之前的输入，或者保留？通常新建计划应该是空的
    _eventController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        // --- 关键修改点 1: 使用 StatefulBuilder ---
        // 这样我们才能在弹窗内部刷新 Chip 的选中颜色，而不影响外面的页面
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            
            // 获取当前输入框里的所有部分 (用 " & " 分割)
            List<String> currentParts = _eventController.text.isEmpty
                ? []
                : _eventController.text.split(' & ');

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
                  // 顶部标题栏
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "EDIT PLAN",
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

                  // --- 关键修改点 2: 使用 FilterChip 实现叠加逻辑 ---
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _presets.map((plan) {
                      // 判断当前这个标签是否已经被选在输入框里了
                      final isSelected = currentParts.contains(plan);

                      return FilterChip(
                        label: Text(plan),
                        // 选中状态样式
                        selected: isSelected,
                        selectedColor: const Color(0xFFBB86FC), // 选中变紫色
                        checkmarkColor: Colors.black, // 勾勾变成黑色
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        // 未选中状态背景
                        backgroundColor: Colors.white.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide.none,
                        ),
                        
                        // --- 关键修改点 3: 叠加/移除逻辑 ---
                        onSelected: (bool selected) {
                          setModalState(() { // 刷新弹窗界面
                            if (selected) {
                              // 如果选中，追加到列表
                              if (!currentParts.contains(plan)) {
                                currentParts.add(plan);
                              }
                            } else {
                              // 如果取消，从列表移除
                              currentParts.remove(plan);
                            }
                            // 重新组合成字符串，赋值给输入框
                            _eventController.text = currentParts.join(' & ');
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),
                  
                  // 输入框 (允许用户在标签基础上继续手动修改)
                  TextField(
                    controller: _eventController,
                    // 注意：这里去掉了 autofocus，因为用户可能想先点标签，不想键盘弹出来挡住标签
                    // 如果你希望键盘一直弹起，可以设为 true
                    autofocus: false, 
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    decoration: InputDecoration(
                      hintText: "Select tags or type...",
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    // 当用户手动打字时，我们需要刷新状态，以便 Chip 也能正确响应（可选）
                    onChanged: (text) {
                      setModalState(() {}); 
                    },
                    onSubmitted: (_) => _saveEvent(),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 保存按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveEvent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBB86FC),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("SAVE PLAN", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 4. 保存事件的逻辑
void _saveEvent() {
    if (_eventController.text.isEmpty) return;

    setState(() {
      final dateKey = _normalizeDate(_selectedDay ?? _focusedDay);
      if (_events[dateKey] != null) {
        _events[dateKey]!.add(_eventController.text);
      } else {
        _events[dateKey] = [_eventController.text];
      }
    });
    
    _saveEventsToPrefs(); // <--- 新增：每次修改后立即存盘！

    _eventController.clear();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
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
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E), // 底部深灰色背景
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "SCHEDULE",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildEventList(),
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
        backgroundColor: const Color(0xFFBB86FC),
        child: const Icon(Icons.add, color: Colors.black), // 图标改成 + 号更合适
      ),
    );
  }
Widget _buildCalendar() {
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
        outsideTextStyle: TextStyle(color: Colors.white.withOpacity(0.2)), // 非本月日期颜色
        
        // 2. 装饰样式
        todayDecoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        selectedDecoration: const BoxDecoration(
          color: Color(0xFFBB86FC), // 你的强调色
          shape: BoxShape.circle,
        ),
        selectedTextStyle: const TextStyle(
          color: Colors.black, 
          fontWeight: FontWeight.bold
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
      },
      onFormatChanged: (format) {
        setState(() {
          _calendarFormat = format;
        });
      },
      
      eventLoader: _getEventsForDay,
    );
  }

  Widget _buildEventList() {
    final events = _getEventsForDay(_selectedDay!);

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Icon(Icons.hotel_class, size: 48, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(
              "Rest Day",
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
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
              color: Colors.red.withOpacity(0.8),
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
              
              // 如果这天没计划了，把这天的 Key 也删掉（让日历上的小点消失）
              if (_events[dateKey]!.isEmpty) {
                _events.remove(dateKey);
              }
            });
            
            // 2. 立即同步到硬盘
            _saveEventsToPrefs();

            // 3. 提示用户
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Plan deleted"), 
                duration: Duration(seconds: 1),
                backgroundColor: Color(0xFF1E1E1E),
              ),
            );
          },

          // 这里是原本的列表项 UI
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFBB86FC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    eventText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
                // 加一个小箭头提示可以互动
                Icon(Icons.chevron_left, color: Colors.white.withOpacity(0.1), size: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}