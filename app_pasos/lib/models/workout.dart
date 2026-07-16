class WorkoutExercise {
  final String exerciseId;
  final String exerciseName;
  final int setsCompleted;
  final String repsCompleted;

  WorkoutExercise({
    required this.exerciseId,
    this.exerciseName = '',
    this.setsCompleted = 0,
    this.repsCompleted = '',
  });

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    return WorkoutExercise(
      exerciseId: json['exercise'] ?? '',
      exerciseName: json['exerciseName'] ?? '',
      setsCompleted: json['setsCompleted'] ?? 0,
      repsCompleted: json['repsCompleted'] ?? '',
    );
  }
}

class Workout {
  final String id;
  final String routineName;
  final DateTime date;
  final int duration;
  final List<WorkoutExercise> exercises;

  Workout({
    required this.id,
    this.routineName = '',
    required this.date,
    this.duration = 0,
    this.exercises = const [],
  });

  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['_id'] ?? json['id'] ?? '',
      routineName: json['routineName'] ?? '',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      duration: json['duration'] ?? 0,
      exercises: (json['exercises'] as List?)
              ?.map((e) => WorkoutExercise.fromJson(e))
              .toList() ??
          [],
    );
  }
}