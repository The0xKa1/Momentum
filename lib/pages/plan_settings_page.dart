import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout_model.dart';
import '../services/app_strings.dart';
import '../services/app_theme.dart';
import '../services/weight_unit_settings.dart';
import '../widgets/premium_widgets.dart';

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
    final templates = <String, List<Exercise>>{};
    decoded.forEach((key, value) {
      templates[key] = parseExercises(List<dynamic>.from(value));
    });

    if (!mounted) return;
    setState(() {
      _templates = templates;
    });
  }

  Future<void> _saveTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = <String, dynamic>{};
    _templates.forEach((key, value) {
      encoded[key] = serializeExercises(value);
    });
    await prefs.setString(_prefsPlanTemplatesKey, json.encode(encoded));
  }

  void _openEditPlan({String? existingName, List<Exercise>? existingExercises}) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final unit = WeightUnitController.unit.value;
    final strings = AppStrings.of(context);
    final nameController = TextEditingController(text: existingName ?? "");
    final drafts = (existingExercises ?? []).map((e) => _ExerciseDraft.fromExercise(e, unit)).toList();
    if (drafts.isEmpty) drafts.add(_ExerciseDraft(unit: unit));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: InputDecoration(labelText: strings.planName),
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
                            _ExerciseDraftForm(
                              draft: draft,
                              unit: unit,
                              strings: strings,
                              onChanged: () => setModalState(() {}),
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
                          final planName = nameController.text.trim();
                          if (planName.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(strings.pleaseEnterPlanName),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                            return;
                          }

                          final planExercises = <Exercise>[];
                          for (final draft in drafts) {
                            final exercise = draft.toExercise();
                            if (exercise == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(strings.completeExerciseFields),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                              return;
                            }
                            planExercises.add(exercise);
                          }

                          setState(() {
                            _templates[planName] = planExercises;
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

  Future<void> _deletePlan(String name) async {
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
      body: PremiumPageShell(
        padding: EdgeInsets.zero,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
          children: [
            if (_templates.isEmpty)
              PremiumSurface(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
                radius: 26,
                child: Column(
                  children: [
                    Icon(Icons.playlist_add, color: theme.colorScheme.primary, size: 46),
                    const SizedBox(height: 14),
                    Text(
                      AppStrings.of(context).noPlansYet,
                      style: TextStyle(color: colors.mutedText, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ..._templates.entries.map((entry) {
                return PremiumSurface(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  radius: 22,
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.event_note, color: theme.colorScheme.primary, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit, color: colors.mutedText),
                        onPressed: () => _openEditPlan(
                          existingName: entry.key,
                          existingExercises: entry.value,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: colors.mutedText),
                        onPressed: () => _deletePlan(entry.key),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _ExerciseDraftForm extends StatelessWidget {
  const _ExerciseDraftForm({
    required this.draft,
    required this.unit,
    required this.strings,
    required this.onChanged,
  });

  final _ExerciseDraft draft;
  final WeightUnit unit;
  final AppStrings strings;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: draft.nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(labelText: strings.exerciseName),
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<ExerciseType>(
          initialValue: draft.type,
          decoration: InputDecoration(labelText: strings.exerciseType),
          dropdownColor: Theme.of(context).colorScheme.surface,
          items: [
            DropdownMenuItem(value: ExerciseType.free, child: Text(strings.freeExercise)),
            DropdownMenuItem(value: ExerciseType.weighted, child: Text(strings.weightedExercise)),
            DropdownMenuItem(value: ExerciseType.timed, child: Text(strings.timedExercise)),
          ],
          onChanged: (value) {
            if (value == null) return;
            draft.setType(value);
            onChanged();
          },
        ),
        if (draft.type == ExerciseType.free) ...[
          const SizedBox(height: 10),
          Text(
            strings.customFields,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
          ),
          const SizedBox(height: 8),
          ...List.generate(draft.customFields.length, (index) {
            final field = draft.customFields[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: field.nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(labelText: strings.fieldName),
                      onChanged: (_) => onChanged(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: field.valueController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(labelText: strings.fieldValue),
                      onChanged: (_) => onChanged(),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      draft.removeCustomFieldAt(index);
                      onChanged();
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  ),
                ],
              ),
            );
          }),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                draft.addCustomField();
                onChanged();
              },
              icon: const Icon(Icons.add, size: 16),
              label: Text(strings.addField),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 160,
              child: TextField(
                controller: draft.setsController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(labelText: strings.sets),
              ),
            ),
            ...draft.visibleFixedFields(strings, unit),
          ],
        ),
      ],
    );
  }
}

class _ExerciseDraft {
  _ExerciseDraft({
    required this.unit,
    ExerciseType? type,
    String name = "",
    String sets = "3",
    String weight = "",
    String reps = "",
    String duration = "",
    List<_CustomFieldDraft>? customFields,
  })  : type = type ?? ExerciseType.free,
        nameController = TextEditingController(text: name),
        setsController = TextEditingController(text: sets),
        weightController = TextEditingController(text: weight),
        repsController = TextEditingController(text: reps),
        durationController = TextEditingController(text: duration),
        customFields = customFields ?? [_CustomFieldDraft()];

  final WeightUnit unit;
  ExerciseType type;
  final TextEditingController nameController;
  final TextEditingController setsController;
  final TextEditingController weightController;
  final TextEditingController repsController;
  final TextEditingController durationController;
  final List<_CustomFieldDraft> customFields;

  factory _ExerciseDraft.fromExercise(Exercise exercise, WeightUnit unit) {
    final firstSet = exercise.sets.isNotEmpty ? exercise.sets.first : WorkoutSet();
    return _ExerciseDraft(
      unit: unit,
      type: exercise.type,
      name: exercise.name,
      sets: exercise.sets.isEmpty ? "1" : exercise.sets.length.toString(),
      weight: firstSet.weight == null
          ? ""
          : WeightUnitController.formatNumber(
              WeightUnitController.fromKg(firstSet.weight!, unit),
            ),
      reps: firstSet.reps?.toString() ?? "",
      duration: firstSet.duration?.toString() ?? "",
      customFields: exercise.type == ExerciseType.free
          ? exercise.customFields
              .map(
                (field) => _CustomFieldDraft(
                  name: field,
                  value: firstSet.customValues[field] ?? "",
                ),
              )
              .toList()
          : [],
    );
  }

  void setType(ExerciseType value) {
    type = value;
    if (value == ExerciseType.free && customFields.isEmpty) {
      customFields.add(_CustomFieldDraft());
    }
  }

  void addCustomField() {
    customFields.add(_CustomFieldDraft());
  }

  void removeCustomFieldAt(int index) {
    if (index < 0 || index >= customFields.length) return;
    final field = customFields.removeAt(index);
    field.dispose();
    if (customFields.isEmpty) {
      customFields.add(_CustomFieldDraft());
    }
  }

  List<Widget> visibleFixedFields(AppStrings strings, WeightUnit unit) {
    if (type == ExerciseType.weighted) {
      return [
        SizedBox(
          width: 160,
          child: TextField(
            controller: weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: strings.weightLabel(WeightUnitController.shortLabel(unit)),
            ),
          ),
        ),
        SizedBox(
          width: 160,
          child: TextField(
            controller: repsController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(labelText: strings.reps),
          ),
        ),
      ];
    }
    if (type == ExerciseType.timed) {
      return [
        SizedBox(
          width: 160,
          child: TextField(
            controller: durationController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(labelText: strings.duration),
          ),
        ),
      ];
    }
    return const [];
  }

  Exercise? toExercise() {
    final name = nameController.text.trim();
    final setCount = int.tryParse(setsController.text);
    if (name.isEmpty || setCount == null || setCount <= 0) {
      return null;
    }

    final set = WorkoutSet();
    if (type == ExerciseType.weighted) {
      final value = double.tryParse(weightController.text);
      final reps = int.tryParse(repsController.text);
      if (value == null || value < 0 || reps == null || reps <= 0) return null;
      set.weight = WeightUnitController.toKg(value, unit);
      set.reps = reps;
      return Exercise(name: name, type: type, sets: List.generate(setCount, (_) => set.copy()));
    }

    if (type == ExerciseType.timed) {
      final value = int.tryParse(durationController.text);
      if (value == null || value <= 0) return null;
      set.duration = value;
      return Exercise(name: name, type: type, sets: List.generate(setCount, (_) => set.copy()));
    }

    final fields = <String>[];
    final values = <String, String>{};
    for (final fieldDraft in customFields) {
      final fieldName = fieldDraft.nameController.text.trim();
      final fieldValue = fieldDraft.valueController.text.trim();
      if (fieldName.isEmpty || fieldValue.isEmpty) continue;
      fields.add(fieldName);
      values[fieldName] = fieldValue;
    }
    if (fields.isEmpty) return null;
    set.customValues = values;
    return Exercise(
      name: name,
      type: type,
      customFields: fields,
      sets: List.generate(setCount, (_) => set.copy()),
    );
  }

  void dispose() {
    nameController.dispose();
    setsController.dispose();
    weightController.dispose();
    repsController.dispose();
    durationController.dispose();
    for (final field in customFields) {
      field.dispose();
    }
  }
}

class _CustomFieldDraft {
  _CustomFieldDraft({
    String name = "",
    String value = "",
  })  : nameController = TextEditingController(text: name),
        valueController = TextEditingController(text: value);

  final TextEditingController nameController;
  final TextEditingController valueController;

  void dispose() {
    nameController.dispose();
    valueController.dispose();
  }
}
