// lib/widgets/rest_timer_panel.dart
import 'package:flutter/material.dart';
import '../services/app_strings.dart';

class RestTimerPanel extends StatelessWidget {
  final String timerString;
  final double progress;
  final VoidCallback onSkip;

  const RestTimerPanel({
    super.key,
    required this.timerString,
    required this.progress,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: Color(0xFFBB86FC)),
              const SizedBox(width: 12),
              Text(
                "${AppStrings.of(context).restLabel} $timerString",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              const SizedBox(width: 12),
              IconButton(onPressed: onSkip, icon: const Icon(Icons.skip_next, color: Colors.white, size: 20)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: progress, backgroundColor: Colors.white.withOpacity(0.1), valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFBB86FC)), minHeight: 4),
        ],
      ),
    );
  }

}