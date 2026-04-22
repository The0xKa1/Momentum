// lib/widgets/rest_timer_panel.dart
import 'package:flutter/material.dart';
import '../services/app_strings.dart';
import '../services/app_theme.dart';
import 'premium_widgets.dart';

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
    return PremiumSurface(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      radius: 24,
      color: colors.surfaceElevated.withValues(alpha: 0.94),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.timer_outlined, color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "${AppStrings.of(context).restLabel} $timerString",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: onSkip,
                icon: Icon(Icons.skip_next, color: theme.colorScheme.onSurface, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.07),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

}
