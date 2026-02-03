class WorkoutSet {
  double weight;
  int reps;
  bool isCompleted;

  WorkoutSet({
    required this.weight,
    required this.reps,
    this.isCompleted = false,
  });
}

class Exercise {
  String name;
  List<WorkoutSet> sets;

  Exercise({
    required this.name,
    required this.sets,
  });
}