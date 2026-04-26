enum MealType {
  breakfast,
  lunch,
  dinner,
  snack,
}

MealType parseMealType(String? raw) {
  switch (raw) {
    case 'breakfast':
      return MealType.breakfast;
    case 'lunch':
      return MealType.lunch;
    case 'dinner':
      return MealType.dinner;
    case 'snack':
    default:
      return MealType.snack;
  }
}

String mealTypeKey(MealType mealType) {
  switch (mealType) {
    case MealType.breakfast:
      return 'breakfast';
    case MealType.lunch:
      return 'lunch';
    case MealType.dinner:
      return 'dinner';
    case MealType.snack:
      return 'snack';
  }
}

enum DietAnalysisStatus {
  pending,
  ai,
  manual,
  failed,
}

DietAnalysisStatus parseDietAnalysisStatus(String? raw) {
  switch (raw) {
    case 'ai':
      return DietAnalysisStatus.ai;
    case 'manual':
      return DietAnalysisStatus.manual;
    case 'failed':
      return DietAnalysisStatus.failed;
    case 'pending':
    default:
      return DietAnalysisStatus.pending;
  }
}

String dietAnalysisStatusKey(DietAnalysisStatus status) {
  switch (status) {
    case DietAnalysisStatus.pending:
      return 'pending';
    case DietAnalysisStatus.ai:
      return 'ai';
    case DietAnalysisStatus.manual:
      return 'manual';
    case DietAnalysisStatus.failed:
      return 'failed';
  }
}

class DietEntry {
  const DietEntry({
    required this.id,
    required this.date,
    required this.mealType,
    required this.photoPath,
    required this.title,
    required this.note,
    required this.analysisStatus,
    required this.analysisSummary,
    required this.createdAt,
    required this.updatedAt,
    this.calories,
    this.proteinGrams,
    this.carbGrams,
    this.fatGrams,
    this.analysisProvider,
    this.analysisConfidence,
    this.analysisError,
    this.analyzedAt,
  });

  final String id;
  final DateTime date;
  final MealType mealType;
  final String photoPath;
  final String title;
  final String note;
  final int? calories;
  final double? proteinGrams;
  final double? carbGrams;
  final double? fatGrams;
  final DietAnalysisStatus analysisStatus;
  final String analysisSummary;
  final String? analysisProvider;
  final String? analysisConfidence;
  final String? analysisError;
  final DateTime? analyzedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory DietEntry.fromJson(Map<String, dynamic> data) {
    return DietEntry(
      id: (data['id'] ?? '').toString(),
      date: DateTime.parse((data['date'] ?? DateTime.now().toIso8601String()).toString()),
      mealType: parseMealType(data['mealType']?.toString()),
      photoPath: (data['photoPath'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      note: (data['note'] ?? '').toString(),
      calories: (data['calories'] as num?)?.toInt(),
      proteinGrams: (data['proteinGrams'] as num?)?.toDouble(),
      carbGrams: (data['carbGrams'] as num?)?.toDouble(),
      fatGrams: (data['fatGrams'] as num?)?.toDouble(),
      analysisStatus: parseDietAnalysisStatus(data['analysisStatus']?.toString()),
      analysisSummary: (data['analysisSummary'] ?? '').toString(),
      analysisProvider: data['analysisProvider']?.toString(),
      analysisConfidence: data['analysisConfidence']?.toString(),
      analysisError: data['analysisError']?.toString(),
      analyzedAt: data['analyzedAt'] == null
          ? null
          : DateTime.parse(data['analyzedAt'].toString()),
      createdAt: DateTime.parse((data['createdAt'] ?? DateTime.now().toIso8601String()).toString()),
      updatedAt: DateTime.parse((data['updatedAt'] ?? DateTime.now().toIso8601String()).toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'mealType': mealTypeKey(mealType),
      'photoPath': photoPath,
      'title': title,
      'note': note,
      'calories': calories,
      'proteinGrams': proteinGrams,
      'carbGrams': carbGrams,
      'fatGrams': fatGrams,
      'analysisStatus': dietAnalysisStatusKey(analysisStatus),
      'analysisSummary': analysisSummary,
      'analysisProvider': analysisProvider,
      'analysisConfidence': analysisConfidence,
      'analysisError': analysisError,
      'analyzedAt': analyzedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  DietEntry copyWith({
    String? id,
    DateTime? date,
    MealType? mealType,
    String? photoPath,
    String? title,
    String? note,
    int? calories,
    double? proteinGrams,
    double? carbGrams,
    double? fatGrams,
    DietAnalysisStatus? analysisStatus,
    String? analysisSummary,
    String? analysisProvider,
    String? analysisConfidence,
    String? analysisError,
    DateTime? analyzedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearCalories = false,
    bool clearProteinGrams = false,
    bool clearCarbGrams = false,
    bool clearFatGrams = false,
    bool clearAnalysisProvider = false,
    bool clearAnalysisConfidence = false,
    bool clearAnalysisError = false,
    bool clearAnalyzedAt = false,
  }) {
    return DietEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      mealType: mealType ?? this.mealType,
      photoPath: photoPath ?? this.photoPath,
      title: title ?? this.title,
      note: note ?? this.note,
      calories: clearCalories ? null : (calories ?? this.calories),
      proteinGrams: clearProteinGrams ? null : (proteinGrams ?? this.proteinGrams),
      carbGrams: clearCarbGrams ? null : (carbGrams ?? this.carbGrams),
      fatGrams: clearFatGrams ? null : (fatGrams ?? this.fatGrams),
      analysisStatus: analysisStatus ?? this.analysisStatus,
      analysisSummary: analysisSummary ?? this.analysisSummary,
      analysisProvider: clearAnalysisProvider ? null : (analysisProvider ?? this.analysisProvider),
      analysisConfidence: clearAnalysisConfidence
          ? null
          : (analysisConfidence ?? this.analysisConfidence),
      analysisError: clearAnalysisError ? null : (analysisError ?? this.analysisError),
      analyzedAt: clearAnalyzedAt ? null : (analyzedAt ?? this.analyzedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class DietDaySummary {
  const DietDaySummary({
    required this.date,
    required this.totalCalories,
    required this.totalProteinGrams,
    required this.totalCarbGrams,
    required this.totalFatGrams,
    required this.entries,
  });

  final DateTime date;
  final int totalCalories;
  final double totalProteinGrams;
  final double totalCarbGrams;
  final double totalFatGrams;
  final List<DietEntry> entries;
}
