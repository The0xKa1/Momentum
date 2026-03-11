// lib/widgets/rest_timer_panel.dart
import 'package:flutter/material.dart';
import '../services/app_strings.dart';
import '../services/app_theme.dart';

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
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                "${AppStrings.of(context).restLabel} $timerString",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
              ),
              const Spacer(),
              const SizedBox(width: 12),
              IconButton(onPressed: onSkip, icon: Icon(Icons.skip_next, color: theme.colorScheme.onSurface, size: 20)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            minHeight: 4,
          ),
        ],
      ),
    );
  }

}
