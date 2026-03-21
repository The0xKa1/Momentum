import 'workout_model.dart';

class ExerciseLibrary {
  // 1. 扩充预设模板，方便测试“组合功能”
  static final Map<String, List<Exercise>> templates = {
    // --- 练腿 ---
    "Legs": [
      Exercise(
        name: "Barbell Squat",
        type: ExerciseType.free,
        customFields: const ["重量", "次数"],
        sets: [
          WorkoutSet(customValues: {"重量": "60", "次数": "12"}),
          WorkoutSet(customValues: {"重量": "80", "次数": "10"}),
        ],
      ),
      Exercise(
        name: "Leg Press",
        type: ExerciseType.free,
        customFields: const ["重量", "次数"],
        sets: [WorkoutSet(customValues: {"重量": "150", "次数": "12"})],
      ),
    ],

    // --- 推胸 ---
    "Chest": [
      Exercise(
        name: "Bench Press",
        type: ExerciseType.free,
        customFields: const ["重量", "次数"],
        sets: [
          WorkoutSet(customValues: {"重量": "60", "次数": "10"}),
          WorkoutSet(customValues: {"重量": "80", "次数": "8"}),
        ],
      ),
      Exercise(
        name: "Incline Dumbbell Press",
        type: ExerciseType.free,
        customFields: const ["重量", "次数"],
        sets: [WorkoutSet(customValues: {"重量": "20", "次数": "12"})],
      ),
    ],

    // --- 拉背 ---
    "Back": [
      Exercise(
        name: "Deadlift",
        type: ExerciseType.free,
        customFields: const ["重量", "次数"],
        sets: [WorkoutSet(customValues: {"重量": "100", "次数": "5"})],
      ),
      Exercise(
        name: "Lat Pulldown",
        type: ExerciseType.free,
        customFields: const ["重量", "次数"],
        sets: [WorkoutSet(customValues: {"重量": "40", "次数": "12"})],
      ),
    ],

    // --- 肩部 ---
    "Shoulders": [
      Exercise(
        name: "Overhead Press",
        type: ExerciseType.free,
        customFields: const ["重量", "次数"],
        sets: [WorkoutSet(customValues: {"重量": "40", "次数": "10"})],
      ),
      Exercise(
        name: "Lateral Raises",
        type: ExerciseType.free,
        customFields: const ["重量", "次数"],
        sets: [WorkoutSet(customValues: {"重量": "10", "次数": "15"})],
      ),
    ],

    // --- 手臂 ---
    "Arms": [
      Exercise(
        name: "Bicep Curls",
        type: ExerciseType.free,
        customFields: const ["重量", "次数"],
        sets: [WorkoutSet(customValues: {"重量": "15", "次数": "12"})],
      ),
      Exercise(
        name: "Tricep Extensions",
        type: ExerciseType.free,
        customFields: const ["重量", "次数"],
        sets: [WorkoutSet(customValues: {"重量": "15", "次数": "12"})],
      ),
    ],
    
    // --- 三头 (用于组合测试: Chest & Triceps) ---
    "Triceps": [
      Exercise(
        name: "Tricep Dips",
        type: ExerciseType.free,
        customFields: const ["重量", "次数"],
        sets: [WorkoutSet(customValues: {"重量": "0", "次数": "15"})],
      ),
      Exercise(
        name: "Skull Crushers",
        type: ExerciseType.free,
        customFields: const ["重量", "次数"],
        sets: [WorkoutSet(customValues: {"重量": "20", "次数": "12"})],
      ),
    ],
  };

  // 2. 核心升级：支持列表查找 (Mix & Match Logic)
  // 输入: ["Chest", "Back"]
  // 输出: [Bench Press..., Deadlift...]
  static List<Exercise> getExercisesForList(List<String> planNames) {
    List<Exercise> combinedList = [];

    for (String name in planNames) {
      // 对每一个关键词，去字典里找
      List<Exercise> found = _getDeepCopyOf(name);
      combinedList.addAll(found);
    }

    return combinedList;
  }

  // 私有辅助方法：模糊匹配 + 深拷贝
  static List<Exercise> _getDeepCopyOf(String query) {
    for (var key in templates.keys) {
      // 只要包含关键词就匹配 (比如 "Heavy Chest" 也能匹配 "Chest")
      if (query.toLowerCase().contains(key.toLowerCase())) {
        // 深拷贝：确保修改动作不会影响模板
        return templates[key]!
            .map((e) => Exercise(
                  name: e.name,
                  type: e.type,
                  customFields: List<String>.from(e.customFields),
                  sets: e.sets.map((s) => s.copy()).toList(),
                ))
            .toList();
      }
    }
    // 如果找不到 (比如用户输入了 "My Special Day")，返回空列表，而不是假数据
    return [];
  }
}
