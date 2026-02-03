import 'package:flutter/material.dart';
import 'home_entry.dart'; // 确保引用了你的主入口文件
import '../services/app_strings.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  // 定义四个动画：三根柱子 + 一行文字
  late Animation<double> _bar1Height;
  late Animation<double> _bar2Height;
  late Animation<double> _bar3Height;
  late Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();

    // 1. 初始化控制器，总时长 2 秒
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // 2. 定义交错动画 (Staggered Animation)
    // 这种写法可以让动画按顺序发生，而不是同时发生
    
    // 柱子 1: 0~600ms 生长
    _bar1Height = Tween<double>(begin: 0, end: 60).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOutBack),
      ),
    );

    // 柱子 2: 200ms~800ms 生长 (比第一个稍微晚一点)
    _bar2Height = Tween<double>(begin: 0, end: 90).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.4, curve: Curves.easeOutBack),
      ),
    );

    // 柱子 3: 400ms~1000ms 生长
    _bar3Height = Tween<double>(begin: 0, end: 120).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOutBack),
      ),
    );

    // 文字: 1000ms~1600ms 淡入
    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 0.8, curve: Curves.easeIn),
      ),
    );

    // 3. 启动动画
    _controller.forward();

    // 4. 监听状态：动画结束后跳转
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // 停顿一下再跳转，给用户看一眼完整形态
        Future.delayed(const Duration(milliseconds: 500), () {
          _navigateToHome();
        });
      }
    });
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const HomeEntryPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // 页面切换动画：淡入淡出 (Fade)
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // 极深的背景色
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. Logo 图形部分
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end, // 底部对齐
                  children: [
                    _buildBar(_bar1Height.value, 0.6),
                    const SizedBox(width: 12),
                    _buildBar(_bar2Height.value, 0.8),
                    const SizedBox(width: 12),
                    _buildBar(_bar3Height.value, 1.0),
                  ],
                ),
                
                const SizedBox(height: 40),

                // 2. 文字部分
                Opacity(
                  opacity: _textOpacity.value,
                  child: Column(
                    children: [
                      const Text(
                        "MOMENTUM",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900, // 特粗
                          letterSpacing: 4.0, // 宽间距
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppStrings.of(context).splashSubtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 10,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // 辅助方法：画柱子
  Widget _buildBar(double height, double opacity) {
    return Container(
      width: 20, // 柱子宽度
      height: height, // 高度是动态的
      decoration: BoxDecoration(
        color: const Color(0xFFBB86FC).withOpacity(opacity),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFBB86FC).withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ],
      ),
    );
  }
}