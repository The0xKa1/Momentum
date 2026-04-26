import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitflow/models/diet_models.dart';
import 'package:fitflow/services/app_data_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String dayKey(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day).toIso8601String();
  }

  test('loadWorkoutDayState prefers snapshot and applies completion fallback', () async {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);

    SharedPreferences.setMockInitialValues({
      AppDataRepository.eventsDataKey: json.encode({
        dayKey(today): ['Push Day'],
      }),
      AppDataRepository.dailyWorkoutSnapshotKey: json.encode({
        dayKey(today): {
          'planTitle': 'Push Day',
          'planCount': 1,
          'exercises': [
            {
              'name': 'Bench Press',
              'type': 'weighted',
              'sets': [
                {'weight': 100.0, 'reps': 5},
                {'weight': 95.0, 'reps': 6},
              ],
            },
            {
              'name': 'Push Up',
              'type': 'free',
              'customFields': ['个数'],
              'sets': [
                {
                  'customValues': {'个数': '20'},
                  'isCompleted': true,
                },
              ],
            },
          ],
        },
      }),
      AppDataRepository.dailyCompletionKey: json.encode({
        dayKey(today): [
          [true, false],
          [true],
        ],
      }),
    });

    final prefs = await SharedPreferences.getInstance();
    final repository = AppDataRepository(prefs: prefs);

    final state = await repository.loadWorkoutDayState(today);

    expect(state.planTitle, 'Push Day');
    expect(state.planCount, 1);
    expect(state.exercises, hasLength(2));
    expect(state.exercises.first.sets.first.isCompleted, isTrue);
    expect(state.exercises.first.sets.last.isCompleted, isFalse);
    expect(state.exercises.last.sets.first.isCompleted, isTrue);
  });

  test('scheduled plans and completed plans persist through repository', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = AppDataRepository(prefs: prefs);
    final date = DateTime.utc(2026, 4, 26);

    await repository.saveScheduledPlans({
      date: ['Leg Day'],
    });
    await repository.saveCompletedPlans({
      date: {'Leg Day'},
    });

    final plans = await repository.loadScheduledPlans();
    final completed = await repository.loadCompletedPlans();

    expect(plans[date], ['Leg Day']);
    expect(completed[date], {'Leg Day'});
  });

  test('diet entries persist and build daily summary', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = AppDataRepository(prefs: prefs);
    final day = DateTime.utc(2026, 4, 26);

    await repository.upsertDietEntry(
      DietEntry(
        id: '1',
        date: day,
        mealType: MealType.breakfast,
        photoPath: 'C:/meal-1.jpg',
        title: 'Eggs',
        note: '',
        calories: 320,
        proteinGrams: 24,
        carbGrams: 8,
        fatGrams: 20,
        analysisStatus: DietAnalysisStatus.manual,
        analysisSummary: 'Manual',
        createdAt: day,
        updatedAt: day,
      ),
    );
    await repository.upsertDietEntry(
      DietEntry(
        id: '2',
        date: day,
        mealType: MealType.lunch,
        photoPath: 'C:/meal-2.jpg',
        title: 'Rice Bowl',
        note: '',
        calories: 540,
        proteinGrams: 32,
        carbGrams: 68,
        fatGrams: 14,
        analysisStatus: DietAnalysisStatus.manual,
        analysisSummary: 'Manual',
        createdAt: day,
        updatedAt: day.add(const Duration(minutes: 10)),
      ),
    );

    final entries = await repository.loadDietEntriesForDay(day);
    final summary = await repository.buildDietDaySummary(day);

    expect(entries, hasLength(2));
    expect(entries.first.id, '2');
    expect(summary.totalCalories, 860);
    expect(summary.totalProteinGrams, closeTo(56, 0.001));
    expect(summary.totalCarbGrams, closeTo(76, 0.001));
    expect(summary.totalFatGrams, closeTo(34, 0.001));
  });
}
