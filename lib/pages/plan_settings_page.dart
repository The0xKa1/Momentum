import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_strings.dart';
import '../services/app_theme.dart';
import '../services/weight_unit_settings.dart';
import '../models/workout_model.dart';

class PlanSettingsPage extends StatefulWidget {
  const PlanSettingsPage({super.key});

  @override
  State<PlanSettingsPage> createState() => _PlanSettingsPageState();
}

class _PlanSettingsPageState extends State<PlanSettingsPage> {
  static const String _prefsPlanTemplatesKey = "plan_templates";
  Map<String, List<Exercise>> _templates = {};

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefsPlanTemplatesKey);
    if (jsonString == null) return;

    final Map<String, dynamic> decoded = json.decode(jsonString);
    final Map<String, List<Exercise>> templates = {};
    decoded.forEach((key, value) {
      templates[key] = _parseExercises(List<dynamic>.from(value));
    });

    setState(() {
      _templates = templates;
    });
  }

  Future<void> _saveTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> encoded = {};
    _templates.forEach((key, value) {
      encoded[key] = _serializeExercises(value);
    });
    await prefs.setString(_prefsPlanTemplatesKey, json.encode(encoded));
  }

  List<Exercise> _parseExercises(List<dynamic> rawExercises) {
    return rawExercises.map((raw) {
      final data = Map<String, dynamic>.from(raw as Map);
      final String name = (data['name'] ?? '').toString();
      final List<dynamic> rawSets = data['sets'] ?? [];
      final sets = rawSets.map((rawSet) {
        final setData = Map<String, dynamic>.from(rawSet as Map);
        final double weight = (setData['weight'] ?? 0).toDouble();
        final int reps = (setData['reps'] ?? 0).toInt();
        return WorkoutSet(weight: weight, reps: reps);
      }).toList();
      return Exercise(name: name, sets: sets);
    }).toList();
  }

  List<Map<String, dynamic>> _serializeExercises(List<Exercise> list) {
    return list.map((e) {
      return {
        "name": e.name,
        "sets": e.sets.map((s) => {"weight": s.weight, "reps": s.reps}).toList(),
      };
    }).toList();
  }

  void _openEditPlan({String? existingName, List<Exercise>? existingExercises}) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final unit = WeightUnitController.unit.value;
    final TextEditingController nameController =
        TextEditingController(text: existingName ?? "");
    final List<_ExerciseDraft> drafts = (existingExercises ?? [])
        .map((e) => _ExerciseDraft.fromExercise(e, unit))
        .toList();
    if (drafts.isEmpty) drafts.add(_ExerciseDraft(unit: unit));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final strings = AppStrings.of(context);
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          existingName == null ? strings.newPlan : strings.editPlan,
                          style: TextStyle(
                            color: colors.subtleText,
                            fontSize: 12,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: InputDecoration(labelText: strings.planName),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(drafts.length, (index) {
                      final draft = drafts[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "${strings.exercise} ${index + 1}",
                                  style: TextStyle(
                                    color: colors.subtleText,
                                    fontSize: 12,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (drafts.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.grey),
                                    onPressed: () {
                                      setModalState(() {
                                        drafts.removeAt(index).dispose();
                                      });
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: draft.nameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(labelText: strings.exerciseName),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: draft.weightController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: strings.weightLabel(
                                        WeightUnitController.shortLabel(unit),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: draft.repsController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(labelText: strings.reps),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: draft.setsController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(labelText: strings.sets),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          setModalState(() {
                            drafts.add(_ExerciseDraft(unit: unit));
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                          side: BorderSide(color: theme.colorScheme.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(strings.addExercise),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(strings.pleaseEnterPlanName), duration: const Duration(seconds: 1))
                            );
                            return;
                          }

                          final List<Exercise> planExercises = [];
                          for (final draft in drafts) {
                            final exercise = draft.toExercise();
                            if (exercise == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(strings.completeExerciseFields), duration: const Duration(seconds: 1))
                              );
                              return;
                            }
                            planExercises.add(exercise);
                          }

                          setState(() {
                            _templates[name] = planExercises;
                          });
                          await _saveTemplates();
                          if (!mounted) return;
                          Navigator.pop(this.context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: colors.accentForeground,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(strings.savePlan, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      nameController.dispose();
      for (final draft in drafts) {
        draft.dispose();
      }
    });
  }

  void _deletePlan(String name) async {
    setState(() {
      _templates.remove(name);
    });
    await _saveTemplates();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context).planSettings),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditPlan(),
        backgroundColor: theme.colorScheme.primary,
        child: Icon(Icons.add, color: colors.accentForeground),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_templates.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                AppStrings.of(context).noPlansYet,
                style: TextStyle(color: colors.subtleText),
                textAlign: TextAlign.center,
              ),
            )
          else
            ..._templates.entries.map((entry) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.grey),
                      onPressed: () => _openEditPlan(
                        existingName: entry.key,
                        existingExercises: entry.value,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      onPressed: () => _deletePlan(entry.key),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ExerciseDraft {
  final WeightUnit unit;
  final TextEditingController nameController;
  final TextEditingController weightController;
  final TextEditingController repsController;
  final TextEditingController setsController;

  _ExerciseDraft({
    required this.unit,
    String name = "",
    String weight = "0",
    String reps = "10",
    String sets = "3",
  })  : nameController = TextEditingController(text: name),
        weightController = TextEditingController(text: weight),
        repsController = TextEditingController(text: reps),
        setsController = TextEditingController(text: sets);

  factory _ExerciseDraft.fromExercise(Exercise exercise, WeightUnit unit) {
    final set = exercise.sets.isNotEmpty ? exercise.sets.first : WorkoutSet(weight: 0, reps: 0);
    return _ExerciseDraft(
      unit: unit,
      name: exercise.name,
      weight: WeightUnitController.formatNumber(
        WeightUnitController.fromKg(set.weight, unit),
      ),
      reps: set.reps.toString(),
      sets: exercise.sets.length.toString(),
    );
  }

  Exercise? toExercise() {
    final name = nameController.text.trim();
    final weight = double.tryParse(weightController.text);
    final reps = int.tryParse(repsController.text);
    final sets = int.tryParse(setsController.text);

    if (name.isEmpty || weight == null || reps == null || sets == null) {
      return null;
    }
    if (reps <= 0 || sets <= 0 || weight < 0) return null;
    final weightInKg = WeightUnitController.toKg(weight, unit);

    return Exercise(
      name: name,
      sets: List.generate(sets, (_) => WorkoutSet(weight: weightInKg, reps: reps)),
    );
  }

  void dispose() {
    nameController.dispose();
    weightController.dispose();
    repsController.dispose();
    setsController.dispose();
  }
}
