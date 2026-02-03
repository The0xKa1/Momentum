import 'package:flutter/material.dart';
import '../models/workout_model.dart'; // 引入刚才建的模型
import 'dart:convert'; // 用于解析 JSON
import 'package:shared_preferences/shared_preferences.dart'; // 用于读取硬盘
import '../models/exercise_library.dart'; // 引入刚才建的库
import 'dart:async'; // 引入计时器库


class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key});

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> with AutomaticKeepAliveClientMixin {
  // 1. 默认标题
  @override
  bool get wantKeepAlive => true;

  String _planTitle = "Rest Day"; 
  List<Exercise> exercises = []; // 暂时置空，后续根据计划生成动作
  // --- 计时器相关状态 ---
  Timer? _restTimer;
  int _restSeconds = 0; // 剩余秒数
  int _totalRestSeconds = 90; // 默认休息时间 (例如 90秒)
  bool _isResting = false;

  // 格式化时间显示 (01:30)
  String get _timerString {
    int min = _restSeconds ~/ 60;
    int sec = _restSeconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  // 开始休息
  void _startRestTimer({int seconds = 90}) {
    _stopRestTimer();

    setState(() {
      _totalRestSeconds = seconds;
      _restSeconds = seconds;
      _isResting = true;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_restSeconds > 0) {
          _restSeconds--;
        } else {
          _stopRestTimer();
          // --- 新增：触发弹窗提醒 ---
          _showRestFinishedDialog(); 
        }
      });
    });
  }
    void _showRestFinishedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // 用户必须点击按钮才能关闭，防止错过提醒
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            "Rest Finished!",
            style: TextStyle(color: Color(0xFFBB86FC), fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Time to start your next set. Let's go!",
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "GOT IT",
                style: TextStyle(color: Color(0xFFBB86FC), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
  // 停止休息
  void _stopRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _isResting = false;
    });
  }

  // 增加/减少时间
  void _adjustTime(int seconds) {
    setState(() {
      _restSeconds += seconds;
      if (_restSeconds < 0) _restSeconds = 0;
      // 如果加时间超过了总时间，把总时间也撑大，保证进度条好看
      if (_restSeconds > _totalRestSeconds) _totalRestSeconds = _restSeconds;
    });
  }

  @override
  void dispose() {
    _restTimer?.cancel(); // 记得销毁防止内存泄漏
    _nameController.dispose();
    _weightController.dispose();
    _repsController.dispose();
    _setsController.dispose();
    super.dispose();
  }
  // --- 新增：动作输入控制器 ---
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _setsController = TextEditingController(text: "3"); // 默认3组

  @override
  void initState() {
    super.initState();
    _loadTodayPlan(); // 页面一启动，就去读计划
  }

  void _showAddExerciseDialog() {
    // 清空上次的输入
    _nameController.clear();
    _weightController.clear();
    _repsController.clear();
    _setsController.text = "3";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
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
              Text(
                "ADD EXERCISE",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // 1. 动作名称
              _buildInputJson("Exercise Name", _nameController),
              const SizedBox(height: 16),

              // 2. 详细参数 (一行三个：重量、次数、组数)
              Row(
                children: [
                  Expanded(child: _buildInputJson("Weight (kg)", _weightController, isNumber: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildInputJson("Reps", _repsController, isNumber: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildInputJson("Sets", _setsController, isNumber: true)),
                ],
              ),

              const SizedBox(height: 24),
              
              // 3. 确认按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _addCustomExercise,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBB86FC),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("ADD TO WORKOUT", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 辅助函数：快速构建输入框
  Widget _buildInputJson(String label, TextEditingController controller, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  // 专门用于给某个动作"加一组"的弹窗
  void _showAddSingleSetDialog(Exercise exercise) {
    // 1. 智能预填充：获取上一组的数据作为默认值，方便用户修改
    double lastWeight = 0;
    int lastReps = 0;
    if (exercise.sets.isNotEmpty) {
      lastWeight = exercise.sets.last.weight;
      lastReps = exercise.sets.last.reps;
    }

    // 填入控制器
    // endsWith(".0") 是为了把 60.0 显示成 60，看起来更简洁
    _weightController.text = lastWeight == 0 ? "" : lastWeight.toString().replaceAll(RegExp(r'\.0$'), '');
    _repsController.text = lastReps == 0 ? "" : lastReps.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 让弹窗高度自适应键盘
      backgroundColor: const Color(0xFF1E1E1E),
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
              // 标题：显示当前是在给哪个动作加组
              Text(
                "ADD SET TO ${exercise.name.toUpperCase()}",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // 输入区域：重量 和 次数 并排显示
              Row(
                children: [
                  Expanded(
                    child: _buildInputJson("Weight (kg)", _weightController, isNumber: true)
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInputJson("Reps", _repsController, isNumber: true)
                  ),
                ],
              ),

              const SizedBox(height: 24),
              
              // 确认按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // 保存逻辑
                    final double w = double.tryParse(_weightController.text) ?? lastWeight;
                    final int r = int.tryParse(_repsController.text) ?? lastReps;

                    setState(() {
                      exercise.sets.add(
                        WorkoutSet(weight: w, reps: r, isCompleted: false)
                      );
                    });
                    Navigator.pop(context); // 关闭弹窗
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBB86FC),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("CONFIRM ADD", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 核心逻辑：添加动作到列表
  void _addCustomExercise() {
    if (_nameController.text.isEmpty) return;

    final String name = _nameController.text;
    final double weight = double.tryParse(_weightController.text) ?? 0;
    final int reps = int.tryParse(_repsController.text) ?? 0;
    final int setsCount = int.tryParse(_setsController.text) ?? 3;

    // 生成组数数据
    List<WorkoutSet> newSets = List.generate(
      setsCount, 
      (index) => WorkoutSet(weight: weight, reps: reps)
    );

    setState(() {
      exercises.add(Exercise(name: name, sets: newSets));
    });

    Navigator.pop(context);
  }

  // 2. 辅助函数：标准化日期（必须和 PlanPage 里的逻辑一模一样！）
  DateTime _normalizeDate(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  // 3. 核心逻辑：读取今天的计划
  Future<void> _loadTodayPlan() async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString('events_data');
    
    // 默认重置
    setState(() {
      _planTitle = "Rest Day";
      exercises = [];
    });
    
    if (jsonString == null) return;

    Map<String, dynamic> decodedMap = json.decode(jsonString);
    DateTime today = _normalizeDate(DateTime.now());
    String key = today.toIso8601String();

    if (decodedMap.containsKey(key)) {
      List<dynamic> plans = decodedMap[key];
      if (plans.isNotEmpty) {
        setState(() {
          List<String> allTags = [];
          for (var p in plans) {
            allTags.addAll(p.toString().split(' & '));
          }
          _planTitle = allTags.toSet().join(" & ");
          exercises = ExerciseLibrary.getExercisesForList(allTags);
        });
      }
    }
  }

  // 辅助方法：生成简约的时间调整按钮
  Widget _buildTimeButton(String label, int seconds) {
    return InkWell(
      onTap: () => _adjustTime(seconds),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3), // 深黑色背景，体现层次感
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildRestTimerPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C), // 深灰背景
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // 1. 左侧：时间显示
              const Icon(Icons.timer_outlined, color: Color(0xFFBB86FC)),
              const SizedBox(width: 12),
              Text(
                "REST  $_timerString",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
              
              const Spacer(), // 把按钮推到右边
              
              // 2. 右侧：控制按钮组
              
              // 减时间 (-10s)
              _buildTimeButton("-10s", -10),
              
              const SizedBox(width: 8),

              // 加时间 (+30s)
              _buildTimeButton("+30s", 30),
              
              const SizedBox(width: 12),

              // 跳过按钮 (改为图标更节省空间)
              InkWell(
                onTap: _stopRestTimer,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.skip_next, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // 3. 底部：进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              // 分母加个保护，防止除以0
              value: _restSeconds / (_totalRestSeconds <= 0 ? 1 : _totalRestSeconds),
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFBB86FC)),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 因为用了 AutomaticKeepAliveClientMixin
    return Scaffold(
      // FAB 逻辑：休息时不显示按钮，保持界面纯净，防止误触
      floatingActionButton: _isResting
          ? null
          : FloatingActionButton(
              onPressed: _showAddExerciseDialog,
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.add, color: Colors.black),
            ),
      
      body: SafeArea(
        // 使用 Stack 是为了让计时器面板悬浮在最上层
        child: Stack(
          children: [
            // --- 底层：内容滚动区域 ---
            Padding(
              // 关键点：如果计时器显示中，给底部增加额外的 Padding
              // 这样列表最后的内容就不会被计时器挡住
              padding: EdgeInsets.only(bottom: _isResting ? 100 : 0),
              child: CustomScrollView(
                slivers: [
                  // 1. 顶部标题区域
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "TODAY'S SESSION",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 动态显示今天的计划名称
                          Text(
                            _planTitle,
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. 根据状态显示不同内容 (核心逻辑分支)
                  
                  // 分支 A: 休息日
                  if (_planTitle == "Rest Day")
                    SliverToBoxAdapter(
                      child: Container(
                        height: 300,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bedtime,
                                size: 64, color: Colors.white.withOpacity(0.2)),
                            const SizedBox(height: 16),
                            Text(
                              "Rest & Recover",
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.5)),
                            )
                          ],
                        ),
                      ),
                    )
                  
                  // 分支 B: 有计划名称，但还没添加动作 (自定义计划初始状态)
                  else if (exercises.isEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        height: 300,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit_note,
                                size: 64, color: Colors.white.withOpacity(0.2)),
                            const SizedBox(height: 16),
                            Text(
                              "Custom Plan: $_planTitle",
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.5)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Tap '+' to add exercises",
                              style: TextStyle(
                                  color: Theme.of(context).primaryColor),
                            ),
                          ],
                        ),
                      ),
                    )
                  
                  // 分支 C: 正常的动作列表
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          // 找到 SliverList -> SliverChildBuilderDelegate 里面的这一段
                        return ExerciseCard(
                          exercise: exercises[index],
                          
                          // 1. 原有的打钩逻辑
                          // lib/pages/workout_page.dart

                          onSetToggle: (setIndex) {
                            // --- 优化后的逻辑 ---
                            var set = exercises[index].sets[setIndex];
                            
                            // 如果正在休息，禁止任何操作（或者弹出提示）
                            if (_isResting) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Resting... Please wait"), duration: Duration(milliseconds: 500))
                              );
                              return; 
                            }

                            setState(() {
                              bool isFinishing = !set.isCompleted;
                              set.isCompleted = isFinishing;
                              
                              // 只有在点击“完成”时才触发计时
                              if (isFinishing) {
                                _startRestTimer(seconds: 90);
                              }
                            });
},

                          // 2. 新增：添加组的逻辑
                          onAddSet: () {
                            setState(() {
                              _showAddSingleSetDialog(exercises[index]);
                            });
                          },
                        );
                        },
                        childCount: exercises.length,
                      ),
                    ),

                  // 3. 底部占位 (确保滚动到底部时有一点留白)
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),

            // --- 顶层：悬浮计时器面板 ---
            if (_isResting)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                // 调用之前定义的面板构建方法
                child: _buildRestTimerPanel(),
              ),
          ],
        ),
      ),
    );
  }

}

// --- 下面是独立的组件，负责渲染每个动作卡片 ---

class ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final Function(int setIndex) onSetToggle; // 回调函数
  final VoidCallback onAddSet;

  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.onSetToggle,
    required this.onAddSet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // 卡片背景色
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 动作名称
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                exercise.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz, color: Colors.grey),
                onPressed: () {}, // 更多选项（如删除动作）
              )
            ],
          ),
          const SizedBox(height: 16),
          
          // 表头 (Set | Previous | Weight | Reps | Done)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                _buildHeader("SET", width: 40),
                _buildHeader("KG", flex: 1),
                _buildHeader("REPS", flex: 1),
                const SizedBox(width: 40), // Checkbox 占位
              ],
            ),
          ),

          // 组数列表
          ...List.generate(exercise.sets.length, (index) {
            final set = exercise.sets[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              height: 44, // 每一行的高度
              decoration: set.isCompleted
                  ? BoxDecoration(
                      color: Colors.green.withOpacity(0.1), // 完成后微微发绿
                      borderRadius: BorderRadius.circular(8),
                    )
                  : null,
              child: Row(
                children: [
                  // 1. 组号
                  SizedBox(
                    width: 40,
                    child: Center(
                      child: Text(
                        "${index + 1}",
                        style: TextStyle(
                          color: set.isCompleted ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
                  // 2. 重量
                  Expanded(
                    child: Center(
                      child: Text(
                        "${set.weight}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  // 3. 次数
                  Expanded(
                    child: Center(
                      child: Text(
                        "${set.reps}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  // 4. 复选框 (核心交互)
                  SizedBox(
                    width: 40,
                    child: Checkbox(
                      value: set.isCompleted,
                      activeColor: const Color(0xFFBB86FC), // 选中后的紫色
                      checkColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (val) {
                        onSetToggle(index); // 触发父组件更新
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
          
          // 添加组数按钮
          Center(
            child: TextButton(
              onPressed: onAddSet,
              child: const Text(
                "+ Add Set",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHeader(String text, {double? width, int? flex}) {
    Widget child = Center(
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    
    if (flex != null) return Expanded(flex: flex, child: child);
    return SizedBox(width: width, child: child);
  }
}