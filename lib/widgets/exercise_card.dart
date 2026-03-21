import 'package:flutter/material.dart';

import '../models/workout_model.dart';
import '../services/app_strings.dart';
import '../services/app_theme.dart';
import '../services/weight_unit_settings.dart';

class ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final WeightUnit unit;
  final Function(int setIndex) onSetToggle;
  final VoidCallback onAddSet;
  final VoidCallback? onRemove;
  final VoidCallback? onEdit;
  final Function(int setIndex)? onEditSet;
  final Function(int setIndex)? onDeleteSet;
  final bool isExtra;

  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.unit,
    required this.onSetToggle,
    required this.onAddSet,
    this.onRemove,
    this.onEdit,
    this.onEditSet,
    this.onDeleteSet,
    this.isExtra = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final totalSets = exercise.sets.length;
    final completedSets = exercise.sets.where((s) => s.isCompleted).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(
                      exercise.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    _buildTag(_typeLabel(strings), theme.colorScheme.primary, colors.accentForeground),
                    if (isExtra)
                      _buildTag("EXTRA", colors.accentSoft, theme.colorScheme.primary),
                  ],
                ),
              ),
              (onRemove != null || onEdit != null)
                  ? PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz, color: Colors.grey),
                      color: colors.surfaceElevated,
                      onSelected: (value) {
                        if (value == 'remove') onRemove?.call();
                        if (value == 'edit') onEdit?.call();
                      },
                      itemBuilder: (context) => [
                        if (onRemove != null)
                          const PopupMenuItem(
                            value: 'remove',
                            child: Text('从今日训练中移除', style: TextStyle(color: Colors.white70)),
                          ),
                        if (onEdit != null)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('编辑', style: TextStyle(color: Colors.white70)),
                          ),
                      ],
                    )
                  : const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatChip(strings.sets, "$completedSets/$totalSets"),
              if (exercise.type == ExerciseType.weighted)
                _buildStatChip(
                  strings.weightLabel(WeightUnitController.shortLabel(unit)),
                  _sumWeight(),
                ),
              if (exercise.type == ExerciseType.timed)
                _buildStatChip(strings.duration, _sumDuration()),
              if (exercise.type == ExerciseType.free && exercise.customFields.isNotEmpty)
                _buildStatChip(strings.customFields, exercise.customFields.join(" / ")),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: colors.border),
          const SizedBox(height: 8),
          ...List.generate(exercise.sets.length, (index) {
            final set = exercise.sets[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: set.isCompleted
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${index + 1}",
                      style: TextStyle(
                        color: set.isCompleted ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _buildSetMetricPills(strings, set),
                    ),
                  ),
                  if (onEditSet != null || onDeleteSet != null)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: Colors.white.withValues(alpha: 0.4), size: 18),
                      color: colors.surfaceElevated,
                      onSelected: (value) {
                        if (value == 'edit') onEditSet?.call(index);
                        if (value == 'delete') onDeleteSet?.call(index);
                      },
                      itemBuilder: (context) => [
                        if (onEditSet != null)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('编辑此组', style: TextStyle(color: Colors.white70)),
                          ),
                        if (onDeleteSet != null)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('删除此组', style: TextStyle(color: Colors.white70)),
                          ),
                      ],
                    ),
                  SizedBox(
                    width: 40,
                    child: Checkbox(
                      value: set.isCompleted,
                      activeColor: theme.colorScheme.primary,
                      checkColor: colors.accentForeground,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      onChanged: (_) => onSetToggle(index),
                    ),
                  ),
                ],
              ),
            );
          }),
          Center(
            child: TextButton.icon(
              onPressed: onAddSet,
              icon: const Icon(Icons.add, size: 16, color: Colors.grey),
              label: const Text(
                "Add Set",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: foreground, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        "$label $value",
        style: TextStyle(
          fontSize: 11,
          color: Colors.white.withValues(alpha: 0.7),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  List<Widget> _buildSetMetricPills(AppStrings strings, WorkoutSet set) {
    final pills = <Widget>[];
    if (exercise.type == ExerciseType.weighted && set.weight != null) {
      pills.add(_buildValuePill(WeightUnitController.formatWeight(set.weight!, unit)));
    }
    if (exercise.type == ExerciseType.timed && set.duration != null) {
      pills.add(_buildValuePill('${set.duration}s'));
    }
    if (exercise.type == ExerciseType.free) {
      for (final field in exercise.customFields) {
        final value = set.customValues[field];
        if (value == null || value.trim().isEmpty) continue;
        pills.add(_buildValuePill('$field $value'));
      }
    }
    return pills;
  }

  Widget _buildValuePill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  String _typeLabel(AppStrings strings) {
    switch (exercise.type) {
      case ExerciseType.weighted:
        return strings.weightedExercise;
      case ExerciseType.timed:
        return strings.timedExercise;
      case ExerciseType.free:
        return strings.freeExercise;
    }
  }

  String _sumWeight() {
    final totalKg = exercise.sets.fold<double>(0, (sum, set) => sum + (set.weight ?? 0));
    return WeightUnitController.formatNumber(
      WeightUnitController.fromKg(totalKg, unit),
    );
  }

  String _sumDuration() {
    final total = exercise.sets.fold<int>(0, (sum, set) => sum + (set.duration ?? 0));
    return '${total}s';
  }
}
