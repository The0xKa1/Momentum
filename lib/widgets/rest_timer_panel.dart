// lib/widgets/rest_timer_panel.dart
import 'package:flutter/material.dart';

class RestTimerPanel extends StatelessWidget {
  final String timerString;
  final double progress;
  final VoidCallback onSkip;
  final Function(int) onAdjust;

  const RestTimerPanel({
    super.key,
    required this.timerString,
    required this.progress,
    required this.onSkip,
    required this.onAdjust,
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
              Text("REST $timerString", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              const Spacer(),
              _buildTimeButton("-10s", -10),
              const SizedBox(width: 8),
              _buildTimeButton("+30s", 30),
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

  Widget _buildTimeButton(String label, int seconds) {
    return InkWell(
      onTap: () => onAdjust(seconds),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }
}