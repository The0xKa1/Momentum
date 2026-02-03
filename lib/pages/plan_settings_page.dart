import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    final TextEditingController nameController =
        TextEditingController(text: existingName ?? "");
    final List<_ExerciseDraft> drafts = (existingExercises ?? [])
        .map((e) => _ExerciseDraft.fromExercise(e))
        .toList();
    if (drafts.isEmpty) drafts.add(_ExerciseDraft());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
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
                          existingName == null ? "NEW PLAN" : "EDIT PLAN",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
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
                      decoration: const InputDecoration(labelText: "Plan name"),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(drafts.length, (index) {
                      final draft = drafts[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "EXERCISE ${index + 1}",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
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
                              decoration: const InputDecoration(labelText: "Exercise name"),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: draft.weightController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(labelText: "Weight (kg)"),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: draft.repsController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(labelText: "Reps"),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: draft.setsController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(labelText: "Sets"),
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
                            drafts.add(_ExerciseDraft());
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFBB86FC),
                          side: const BorderSide(color: Color(0xFFBB86FC)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("+ Add Exercise"),
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
                              const SnackBar(content: Text("Please enter plan name"), duration: Duration(seconds: 1))
                            );
                            return;
                          }

                          final List<Exercise> planExercises = [];
                          for (final draft in drafts) {
                            final exercise = draft.toExercise();
                            if (exercise == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Please complete all exercise fields"), duration: Duration(seconds: 1))
                              );
                              return;
                            }
                            planExercises.add(exercise);
                          }

                          setState(() {
                            _templates[name] = planExercises;
                          });
                          await _saveTemplates();
                          if (mounted) Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFBB86FC),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("SAVE PLAN", style: TextStyle(fontWeight: FontWeight.bold)),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Plan Settings"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditPlan(),
        backgroundColor: const Color(0xFFBB86FC),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: _templates.isEmpty
          ? Center(
              child: Text(
                "No plans yet. Tap + to create one.",
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _templates.entries.map((entry) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
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
              }).toList(),
            ),
    );
  }
}

class _ExerciseDraft {
  final TextEditingController nameController;
  final TextEditingController weightController;
  final TextEditingController repsController;
  final TextEditingController setsController;

  _ExerciseDraft({
    String name = "",
    String weight = "0",
    String reps = "10",
    String sets = "3",
  })  : nameController = TextEditingController(text: name),
        weightController = TextEditingController(text: weight),
        repsController = TextEditingController(text: reps),
        setsController = TextEditingController(text: sets);

  factory _ExerciseDraft.fromExercise(Exercise exercise) {
    final set = exercise.sets.isNotEmpty ? exercise.sets.first : WorkoutSet(weight: 0, reps: 0);
    return _ExerciseDraft(
      name: exercise.name,
      weight: set.weight.toString(),
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

    return Exercise(
      name: name,
      sets: List.generate(sets, (_) => WorkoutSet(weight: weight, reps: reps)),
    );
  }

  void dispose() {
    nameController.dispose();
    weightController.dispose();
    repsController.dispose();
    setsController.dispose();
  }
}
