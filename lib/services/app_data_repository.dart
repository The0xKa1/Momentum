import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/diet_models.dart';
import '../models/exercise_library.dart';
import '../models/workout_model.dart';

class WorkoutDayState {
  const WorkoutDayState({
    required this.planTitle,
    required this.exercises,
    required this.planCount,
  });

  final String planTitle;
  final List<Exercise> exercises;
  final int planCount;
}

class AppDataRepository {
  AppDataRepository({SharedPreferences? prefs})
      : _prefsFuture = prefs == null ? SharedPreferences.getInstance() : Future.value(prefs);

  static const String eventsDataKey = 'events_data';
  static const String completedPlansKey = 'completed_plans';
  static const String planTemplatesKey = 'plan_templates';
  static const String dailyExtrasKey = 'daily_extra_workout_data';
  static const String hiddenPlanKey = 'hidden_plan_today';
  static const String dailyCompletionKey = 'daily_completion_state';
  static const String dailyWorkoutSnapshotKey = 'daily_workout_snapshot';
  static const String dietEntriesKey = 'diet_entries';

  final Future<SharedPreferences> _prefsFuture;

  Future<Map<DateTime, List<String>>> loadScheduledPlans() async {
    final prefs = await _prefsFuture;
    final raw = prefs.getString(eventsDataKey);
    if (raw == null || raw.isEmpty) return {};

    final decoded = _decodeJsonMap(raw);
    final result = <DateTime, List<String>>{};
    decoded.forEach((key, value) {
      result[_normalizeDate(DateTime.parse(key))] = List<String>.from(value as List);
    });
    return result;
  }

  Future<void> saveScheduledPlans(Map<DateTime, List<String>> plans) async {
    final prefs = await _prefsFuture;
    final encoded = <String, dynamic>{};
    plans.forEach((key, value) {
      encoded[_normalizeDate(key).toIso8601String()] = value;
    });
    await prefs.setString(eventsDataKey, json.encode(encoded));
  }

  Future<Map<DateTime, Set<String>>> loadCompletedPlans() async {
    final prefs = await _prefsFuture;
    final raw = prefs.getString(completedPlansKey);
    if (raw == null || raw.isEmpty) return {};

    final decoded = _decodeJsonMap(raw);
    final result = <DateTime, Set<String>>{};
    decoded.forEach((key, value) {
      result[_normalizeDate(DateTime.parse(key))] = Set<String>.from(value as List);
    });
    return result;
  }

  Future<void> saveCompletedPlans(Map<DateTime, Set<String>> completedByDate) async {
    final prefs = await _prefsFuture;
    final encoded = <String, dynamic>{};
    completedByDate.forEach((key, value) {
      encoded[_normalizeDate(key).toIso8601String()] = value.toList();
    });
    await prefs.setString(completedPlansKey, json.encode(encoded));
  }

  Future<List<String>> loadTemplateNames() async {
    final prefs = await _prefsFuture;
    final raw = prefs.getString(planTemplatesKey);
    if (raw == null || raw.isEmpty) return const [];
    return _decodeJsonMap(raw).keys.toList();
  }

  Future<List<DietEntry>> loadDietEntries() async {
    final prefs = await _prefsFuture;
    final raw = prefs.getString(dietEntriesKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = json.decode(raw);
    if (decoded is! List) return [];

    final entries = decoded
        .whereType<Map>()
        .map((item) => DietEntry.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entries;
  }

  Future<void> saveDietEntries(List<DietEntry> entries) async {
    final prefs = await _prefsFuture;
    await prefs.setString(
      dietEntriesKey,
      json.encode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<List<DietEntry>> loadDietEntriesForDay(DateTime day) async {
    final normalizedDay = _normalizeDate(day);
    final entries = await loadDietEntries();
    return entries
        .where((entry) => _normalizeDate(entry.date) == normalizedDay)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> upsertDietEntry(DietEntry entry) async {
    final entries = List<DietEntry>.from(await loadDietEntries());
    final index = entries.indexWhere((item) => item.id == entry.id);
    if (index >= 0) {
      entries[index] = entry;
    } else {
      entries.add(entry);
    }
    await saveDietEntries(entries);
  }

  Future<void> deleteDietEntry(String entryId) async {
    final entries = List<DietEntry>.from(await loadDietEntries());
    entries.removeWhere((entry) => entry.id == entryId);
    await saveDietEntries(entries);
  }

  Future<DietDaySummary> buildDietDaySummary(DateTime day) async {
    final normalizedDay = _normalizeDate(day);
    final entries = await loadDietEntriesForDay(normalizedDay);
    var totalCalories = 0;
    var totalProteinGrams = 0.0;
    var totalCarbGrams = 0.0;
    var totalFatGrams = 0.0;

    for (final entry in entries) {
      totalCalories += entry.calories ?? 0;
      totalProteinGrams += entry.proteinGrams ?? 0;
      totalCarbGrams += entry.carbGrams ?? 0;
      totalFatGrams += entry.fatGrams ?? 0;
    }

    return DietDaySummary(
      date: normalizedDay,
      totalCalories: totalCalories,
      totalProteinGrams: totalProteinGrams,
      totalCarbGrams: totalCarbGrams,
      totalFatGrams: totalFatGrams,
      entries: entries,
    );
  }

  Future<Map<String, dynamic>> loadRawWorkoutSnapshots() async {
    final prefs = await _prefsFuture;
    final raw = prefs.getString(dailyWorkoutSnapshotKey);
    if (raw == null || raw.isEmpty) return {};
    return _decodeJsonMap(raw);
  }

  Future<Map<String, dynamic>> loadRawWorkoutCompletionState() async {
    final prefs = await _prefsFuture;
    final raw = prefs.getString(dailyCompletionKey);
    if (raw == null || raw.isEmpty) return {};
    return _decodeJsonMap(raw);
  }

  Future<WorkoutDayState> loadWorkoutDayState(DateTime day) async {
    final prefs = await _prefsFuture;
    final dateKey = _normalizeDate(day).toIso8601String();
    final scheduledPlans = await loadScheduledPlans();
    final planNames = scheduledPlans[_normalizeDate(day)] ?? const <String>[];
    final planName = planNames.isNotEmpty ? planNames.first : null;
    if (planName == null || planName.isEmpty) {
      return const WorkoutDayState(planTitle: 'Rest Day', exercises: [], planCount: 0);
    }

    final rawSnapshots = await loadRawWorkoutSnapshots();
    final snapshot = _parseSnapshot(rawSnapshots[dateKey]);
    if (snapshot != null && snapshot.planTitle == planName) {
      final exercises = snapshot.exercises.map((exercise) => exercise.copy()).toList();
      final completionMap = await loadRawWorkoutCompletionState();
      _applyCompletionFallback(exercises, completionMap[dateKey]);
      return WorkoutDayState(
        planTitle: planName,
        exercises: exercises,
        planCount: snapshot.planCount.clamp(0, exercises.length).toInt(),
      );
    }

    final templateExercises = await _loadTemplateExercisesForPlan(prefs, planName);
    final hiddenToday = await _loadHiddenExerciseNamesForDay(prefs, dateKey);
    final filteredTemplates = templateExercises
        .where((exercise) => !hiddenToday.contains(exercise.name))
        .toList();
    final extraExercises = await _loadExtraExercisesForDay(prefs, dateKey);
    final combined = [...filteredTemplates, ...extraExercises];
    final completionMap = await loadRawWorkoutCompletionState();
    _applyCompletionFallback(combined, completionMap[dateKey]);

    return WorkoutDayState(
      planTitle: planName,
      exercises: combined,
      planCount: filteredTemplates.length,
    );
  }

  Future<List<Exercise>> loadExercisesForDay(DateTime day) async {
    final state = await loadWorkoutDayState(day);
    return state.exercises;
  }

  Future<void> persistWorkoutCompletionState(DateTime day, List<Exercise> exercises) async {
    final prefs = await _prefsFuture;
    final completionMap = await loadRawWorkoutCompletionState();
    completionMap[_normalizeDate(day).toIso8601String()] = exercises
        .map((exercise) => exercise.sets.map((set) => set.isCompleted).toList())
        .toList();
    await prefs.setString(dailyCompletionKey, json.encode(completionMap));
  }

  Future<void> persistWorkoutSnapshot(
    DateTime day, {
    required String planTitle,
    required int planCount,
    required List<Exercise> exercises,
  }) async {
    final prefs = await _prefsFuture;
    final snapshots = await loadRawWorkoutSnapshots();
    snapshots[_normalizeDate(day).toIso8601String()] = {
      'planTitle': planTitle,
      'planCount': planCount,
      'exercises': serializeExercises(exercises),
    };
    await prefs.setString(dailyWorkoutSnapshotKey, json.encode(snapshots));
  }

  Future<void> appendDailyExtraExercises(DateTime day, List<Exercise> extras) async {
    final prefs = await _prefsFuture;
    final dateKey = _normalizeDate(day).toIso8601String();
    final extrasMap = await _loadRawExtrasMap(prefs);
    final existing = List<dynamic>.from(extrasMap[dateKey] ?? const []);
    existing.addAll(serializeExercises(extras));
    extrasMap[dateKey] = existing;
    await prefs.setString(dailyExtrasKey, json.encode(extrasMap));
  }

  Future<void> saveDailyExtraExerciseAt(DateTime day, int extraIndex, Exercise updated) async {
    final prefs = await _prefsFuture;
    final dateKey = _normalizeDate(day).toIso8601String();
    final extrasMap = await _loadRawExtrasMap(prefs);
    final list = List<dynamic>.from(extrasMap[dateKey] ?? const []);
    if (extraIndex < 0 || extraIndex >= list.length) return;
    list[extraIndex] = serializeExercises([updated]).first;
    extrasMap[dateKey] = list;
    await prefs.setString(dailyExtrasKey, json.encode(extrasMap));
  }

  Future<void> removeDailyExtraExerciseAt(DateTime day, int extraIndex) async {
    final prefs = await _prefsFuture;
    final dateKey = _normalizeDate(day).toIso8601String();
    final extrasMap = await _loadRawExtrasMap(prefs);
    final list = List<dynamic>.from(extrasMap[dateKey] ?? const []);
    if (extraIndex < 0 || extraIndex >= list.length) return;
    list.removeAt(extraIndex);
    extrasMap[dateKey] = list;
    await prefs.setString(dailyExtrasKey, json.encode(extrasMap));
  }

  Future<void> hidePlanExerciseForDay(DateTime day, String exerciseName) async {
    final prefs = await _prefsFuture;
    final dateKey = _normalizeDate(day).toIso8601String();
    final hiddenMap = await _loadRawHiddenMap(prefs);
    final list = List<dynamic>.from(hiddenMap[dateKey] ?? const []);
    if (!list.contains(exerciseName)) {
      list.add(exerciseName);
      hiddenMap[dateKey] = list;
      await prefs.setString(hiddenPlanKey, json.encode(hiddenMap));
    }
  }

  Future<void> savePlanForDay(DateTime day, String planName) async {
    final plans = await loadScheduledPlans();
    plans[_normalizeDate(day)] = [planName];
    await saveScheduledPlans(plans);
  }

  Future<void> deletePlanForDay(DateTime day, int index) async {
    final plans = await loadScheduledPlans();
    final dateKey = _normalizeDate(day);
    final list = List<String>.from(plans[dateKey] ?? const []);
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    if (list.isEmpty) {
      plans.remove(dateKey);
    } else {
      plans[dateKey] = list;
    }
    await saveScheduledPlans(plans);
  }

  Future<List<Exercise>> _loadTemplateExercisesForPlan(
    SharedPreferences prefs,
    String planName,
  ) async {
    final raw = prefs.getString(planTemplatesKey);
    if (raw == null || raw.isEmpty) {
      return ExerciseLibrary.getExercisesForList([planName]);
    }

    final templates = _decodeJsonMap(raw);
    if (!templates.containsKey(planName)) return [];
    return parseExercises(List<dynamic>.from(templates[planName] ?? const []));
  }

  Future<Set<String>> _loadHiddenExerciseNamesForDay(SharedPreferences prefs, String dateKey) async {
    final hiddenMap = await _loadRawHiddenMap(prefs);
    final hiddenList = hiddenMap[dateKey];
    if (hiddenList is! List) return {};
    return hiddenList.map((item) => item.toString()).toSet();
  }

  Future<List<Exercise>> _loadExtraExercisesForDay(SharedPreferences prefs, String dateKey) async {
    final extrasMap = await _loadRawExtrasMap(prefs);
    final rawExtras = extrasMap[dateKey];
    if (rawExtras is! List) return [];
    return parseExercises(List<dynamic>.from(rawExtras));
  }

  WorkoutDayState? _parseSnapshot(dynamic rawSnapshot) {
    if (rawSnapshot is! Map) return null;
    final snapshot = Map<String, dynamic>.from(rawSnapshot);
    final rawExercises = snapshot['exercises'];
    if (rawExercises is! List) return null;
    return WorkoutDayState(
      planTitle: (snapshot['planTitle'] ?? '').toString(),
      planCount: (snapshot['planCount'] as num?)?.toInt() ?? 0,
      exercises: parseExercises(List<dynamic>.from(rawExercises)),
    );
  }

  Future<Map<String, dynamic>> _loadRawExtrasMap(SharedPreferences prefs) async {
    final raw = prefs.getString(dailyExtrasKey);
    if (raw == null || raw.isEmpty) return {};
    return _decodeJsonMap(raw);
  }

  Future<Map<String, dynamic>> _loadRawHiddenMap(SharedPreferences prefs) async {
    final raw = prefs.getString(hiddenPlanKey);
    if (raw == null || raw.isEmpty) return {};
    return _decodeJsonMap(raw);
  }

  void _applyCompletionFallback(List<Exercise> exercises, dynamic rawCompletionForDay) {
    if (rawCompletionForDay is! List) return;
    for (var i = 0; i < exercises.length && i < rawCompletionForDay.length; i++) {
      final rawSetFlags = rawCompletionForDay[i];
      if (rawSetFlags is! List) continue;
      final sets = exercises[i].sets;
      for (var j = 0; j < sets.length && j < rawSetFlags.length; j++) {
        if (sets[j].isCompleted) continue;
        final rawFlag = rawSetFlags[j];
        if (rawFlag is bool) {
          sets[j].isCompleted = rawFlag;
        }
      }
    }
  }

  Map<String, dynamic> _decodeJsonMap(String raw) {
    final decoded = json.decode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    return Map<String, dynamic>.from(decoded as Map);
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }
}
