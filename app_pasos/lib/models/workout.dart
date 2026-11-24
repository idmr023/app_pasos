/// Serie real registrada en un entrenamiento.
class WorkoutSet {
  final double weightKg;
  final int reps;
  final int seconds;
  /// Repeticiones en reserva (solo en calibración); -1 = no llegó.
  final int? rir;

  const WorkoutSet({this.weightKg = 0, this.reps = 0, this.seconds = 0, this.rir});

  factory WorkoutSet.fromJson(Map<String, dynamic> json) => WorkoutSet(
        weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0,
        reps: (json['reps'] as num?)?.toInt() ?? 0,
        seconds: (json['seconds'] as num?)?.toInt() ?? 0,
        rir: (json['rir'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'weightKg': weightKg,
        'reps': reps,
        'seconds': seconds,
        if (rir != null) 'rir': rir,
      };
}

class WorkoutExercise {
  final String exerciseId;
  final String exerciseName;
  final int setsCompleted;
  final String repsCompleted;
  final double weightKg;
  final List<WorkoutSet> setLogs;

  WorkoutExercise({
    required this.exerciseId,
    this.exerciseName = '',
    this.setsCompleted = 0,
    this.repsCompleted = '',
    this.weightKg = 0,
    this.setLogs = const [],
  });

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    return WorkoutExercise(
      exerciseId: json['exercise'] ?? '',
      exerciseName: json['exerciseName'] ?? '',
      setsCompleted: json['setsCompleted'] ?? 0,
      repsCompleted: json['repsCompleted'] ?? '',
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0,
      setLogs: (json['setLogs'] as List?)
              ?.map((s) => WorkoutSet.fromJson(s as Map<String, dynamic>))
              .toList() ??
          const [],
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
