import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pages/home_entry.dart';

void main() {
  runApp(const FitFlowApp());
}

class FitFlowApp extends StatelessWidget {
  const FitFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitFlow',
      debugShowCheckedModeBanner: false, // 去掉右上角那个丑丑的 Debug 条
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark, // 强制深色模式
        scaffoldBackgroundColor: const Color(0xFF121212), // 高级黑背景
        primaryColor: const Color(0xFFBB86FC), // 强调色（赛博朋克紫）
        
        // 全局配置 Google 字体 (Inter 是非常通用的现代化无衬线字体)
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      home: const HomeEntryPage(), // 指向我们的主导航页
    );
  }
}