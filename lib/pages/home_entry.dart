import 'package:flutter/material.dart';
import 'workout_page.dart'; // 引入训练页
import 'plan_page.dart';
import 'settings_page.dart';
import '../services/app_strings.dart';
import '../services/app_theme.dart';

class HomeEntryPage extends StatefulWidget {
  const HomeEntryPage({super.key});

  @override
  State<HomeEntryPage> createState() => _HomeEntryPageState();
}

final GlobalKey<WorkoutPageState> workoutKey = GlobalKey<WorkoutPageState>();

class _HomeEntryPageState extends State<HomeEntryPage> {
  int _currentIndex = 0; // 当前选中的是第几个图标

  // 页面列表：先把核心的 Workout 放进去，其他的先用占位符代替
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      WorkoutPage(key: workoutKey),    // 0: 训练
      const PlanPage(),       // 1: 计划 (这里修改了！)
      const SettingsPage(), // 2: 设置/关于
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      
      // 极简风格的底部导航栏
      bottomNavigationBar: SafeArea(
        child: Container(
          color: colors.surface,
          padding: const EdgeInsets.only(left: 8, right: 12, top: 6, bottom: 6),
          child: Row(
            children: [
              Expanded(
                child: NavigationBar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (int index) {
                    if (index == 0) {
                      workoutKey.currentState?.refreshData();
                    }
                    setState(() {
                      _currentIndex = index; // 刷新界面
                    });
                  },
                  backgroundColor: colors.surface,
                  indicatorColor: theme.colorScheme.primary,
                  destinations: [
                    NavigationDestination(
                      icon: Icon(Icons.fitness_center_outlined),
                      selectedIcon: Icon(Icons.fitness_center, color: colors.accentForeground),
                      label: AppStrings.of(context).workout,
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.calendar_month_outlined),
                      selectedIcon: Icon(Icons.calendar_month, color: colors.accentForeground),
                      label: AppStrings.of(context).plan,
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings, color: colors.accentForeground),
                      label: AppStrings.of(context).settings,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
