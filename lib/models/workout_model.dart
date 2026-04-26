enum ExerciseType {
  free,
  weighted,
  timed,
}

ExerciseType _parseExerciseType(String? raw) {
  switch (raw) {
    case 'weighted':
      return ExerciseType.weighted;
    case 'timed':
      return ExerciseType.timed;
    default:
      return ExerciseType.free;
  }
}

String exerciseTypeKey(ExerciseType type) {
  switch (type) {
    case ExerciseType.weighted:
      return 'weighted';
    case ExerciseType.timed:
      return 'timed';
    case ExerciseType.free:
      return 'free';
  }
}

class WorkoutSet {
  double? weight;
  int? reps;
  int? duration;
  Map<String, String> customValues;
  bool isCompleted;

  WorkoutSet({
    this.weight,
    this.reps,
    this.duration,
    Map<String, String>? customValues,
    this.isCompleted = false,
  }) : customValues = customValues ?? {};

  factory WorkoutSet.fromJson(Map<String, dynamic> data) {
    final rawCustomValues = Map<String, dynamic>.from(data['customValues'] ?? const {});
    return WorkoutSet(
      weight: (data['weight'] as num?)?.toDouble(),
      reps: (data['reps'] as num?)?.toInt(),
      duration: (data['duration'] as num?)?.toInt(),
      customValues: rawCustomValues.map((key, value) => MapEntry(key, value.toString())),
      isCompleted: data['isCompleted'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (weight != null) json['weight'] = weight;
    if (reps != null) json['reps'] = reps;
    if (duration != null) json['duration'] = duration;
    if (customValues.isNotEmpty) json['customValues'] = customValues;
    if (isCompleted) json['isCompleted'] = true;
    return json;
  }

  WorkoutSet copy() {
    return WorkoutSet(
      weight: weight,
      reps: reps,
      duration: duration,
      customValues: Map<String, String>.from(customValues),
      isCompleted: isCompleted,
    );
  }
}

class Exercise {
  String name;
  ExerciseType type;
  List<String> customFields;
  List<WorkoutSet> sets;

  Exercise({
    required this.name,
    required this.type,
    required this.sets,
    List<String>? customFields,
  }) : customFields = customFields ?? [];

  factory Exercise.fromJson(Map<String, dynamic> data) {
    final name = (data['name'] ?? '').toString();
    final rawSets = List<dynamic>.from(data['sets'] ?? const []);
    final sets = rawSets
        .map((rawSet) => WorkoutSet.fromJson(Map<String, dynamic>.from(rawSet as Map)))
        .toList();
    final type = _parseExerciseType(data['type']?.toString());
    final customFields = List<dynamic>.from(data['customFields'] ?? const [])
        .map((field) => field.toString())
        .where((field) => field.trim().isNotEmpty)
        .toList();

    if (data['type'] != null) {
      if (type == ExerciseType.free) {
        _normalizeFreeSetsFromLegacyData(rawSets, sets);
      }
      final resolvedFields = type == ExerciseType.free
          ? (customFields.isNotEmpty ? customFields : _inferCustomFieldsFromSets(rawSets, sets))
          : const <String>[];
      return Exercise(
        name: name,
        type: type,
        sets: sets,
        customFields: resolvedFields,
      );
    }

    final inferredFields = <String>[];
    for (int i = 0; i < sets.length; i++) {
      final set = sets[i];
      final values = <String, String>{};
      if (set.weight != null) values['重量'] = _formatLegacyNumber(set.weight!);
      if (set.duration != null) values['时间'] = '${set.duration}';

      final rawSet = i < rawSets.length ? rawSets[i] : null;
      if (rawSet is Map) {
        final map = Map<String, dynamic>.from(rawSet);
        final count = map['count'] ?? map['reps'];
        final distance = map['distance'];
        if (count != null) values['个数'] = '$count';
        if (distance != null) values['距离'] = '$distance';
      }

      set.weight = null;
      set.duration = null;
      set.customValues = values;
      for (final field in values.keys) {
        if (!inferredFields.contains(field)) inferredFields.add(field);
      }
    }

    return Exercise(
      name: name,
      type: ExerciseType.free,
      sets: sets,
      customFields: inferredFields,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': exerciseTypeKey(type),
      'customFields': type == ExerciseType.free ? customFields : <String>[],
      'sets': sets.map((set) => set.toJson()).toList(),
    };
  }

  Exercise copy() {
    return Exercise(
      name: name,
      type: type,
      customFields: List<String>.from(customFields),
      sets: sets.map((set) => set.copy()).toList(),
    );
  }
}

String _formatLegacyNumber(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toString();
}

List<String> _inferCustomFieldsFromSets(List<dynamic> rawSets, List<WorkoutSet> sets) {
  final fields = <String>[];
  for (int i = 0; i < sets.length; i++) {
    final set = sets[i];
    if (set.customValues.isNotEmpty) {
      for (final field in set.customValues.keys) {
        if (!fields.contains(field)) fields.add(field);
      }
    }
    final rawSet = i < rawSets.length ? rawSets[i] : null;
    if (rawSet is Map) {
      final map = Map<String, dynamic>.from(rawSet);
      if ((map['weight'] != null || set.weight != null) && !fields.contains('重量')) {
        fields.add('重量');
      }
      if ((map['duration'] != null || set.duration != null) && !fields.contains('时间')) {
        fields.add('时间');
      }
      if ((map['count'] != null || map['reps'] != null) && !fields.contains('个数')) {
        fields.add('个数');
      }
      if (map['distance'] != null && !fields.contains('距离')) {
        fields.add('距离');
      }
    }
  }
  return fields;
}

void _normalizeFreeSetsFromLegacyData(List<dynamic> rawSets, List<WorkoutSet> sets) {
  for (int i = 0; i < sets.length; i++) {
    final set = sets[i];
    if (set.customValues.isNotEmpty) continue;
    final rawSet = i < rawSets.length ? rawSets[i] : null;
    if (rawSet is! Map) continue;
    final map = Map<String, dynamic>.from(rawSet);
    final values = <String, String>{};
    if (set.weight != null || map['weight'] != null) {
      values['重量'] = _formatLegacyNumber((set.weight ?? (map['weight'] as num).toDouble()));
    }
    if (set.duration != null || map['duration'] != null) {
      values['时间'] = '${set.duration ?? (map['duration'] as num).toInt()}';
    }
    if (map['count'] != null || map['reps'] != null) {
      values['个数'] = '${map['count'] ?? map['reps']}';
    }
    if (map['distance'] != null) {
      values['距离'] = '${map['distance']}';
    }
    set.customValues = values;
    set.weight = null;
    set.duration = null;
  }
}

List<Exercise> parseExercises(List<dynamic> rawExercises) {
  return rawExercises
      .map((raw) => Exercise.fromJson(Map<String, dynamic>.from(raw as Map)))
      .toList();
}

List<Map<String, dynamic>> serializeExercises(List<Exercise> list) {
  return list.map((exercise) => exercise.toJson()).toList();
}
