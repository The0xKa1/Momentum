import 'package:flutter/material.dart';
import 'workout_page.dart'; // 引入训练页
import 'plan_page.dart';

class HomeEntryPage extends StatefulWidget {
  const HomeEntryPage({super.key});

  @override
  State<HomeEntryPage> createState() => _HomeEntryPageState();
}

final GlobalKey<WorkoutPageState> workoutKey = GlobalKey<WorkoutPageState>();

class _HomeEntryPageState extends State<HomeEntryPage> {
  int _currentIndex = 0; // 当前选中的是第几个图标

  // 页面列表：先把核心的 Workout 放进去，其他的先用占位符代替
  final List<Widget> _pages = [
    WorkoutPage(key: workoutKey),    // 0: 训练
    const PlanPage(),       // 1: 计划 (这里修改了！)
    const Center(child: Text("Diet Page (Coming Soon)")), // 2: 饮食
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      
      // 极简风格的底部导航栏
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          if (index == 0)
          {
            workoutKey.currentState?.refreshData();
          }
          setState(() {
            _currentIndex = index; // 刷新界面
          });
        },
        backgroundColor: const Color(0xFF1E1E1E), // 比背景稍亮一点
        indicatorColor: const Color(0xFFBB86FC),  // 选中时的气泡颜色
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center, color: Colors.black),
            label: 'Workout',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: Colors.black),
            label: 'Plan',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu, color: Colors.black),
            label: 'Diet',
          ),
        ],
      ),
    );
  }
}