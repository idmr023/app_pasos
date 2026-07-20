class RoutineExercise {
  final String exerciseId;
  final String exerciseName;
  int sets;
  String reps;
  int restTime;
  int order;

  RoutineExercise({
    required this.exerciseId,
    this.exerciseName = '',
    this.sets = 3,
    this.reps = '10',
    this.restTime = 60,
    this.order = 0,
  });

  factory RoutineExercise.fromJson(Map<String, dynamic> json) {
    return RoutineExercise(
      exerciseId: json['exercise']?.toString() ?? '',
      exerciseName: json['exerciseName']?.toString() ?? '',
      sets: json['sets'] ?? 3,
      reps: json['reps']?.toString() ?? '10',
      restTime: json['restTime'] ?? 60,
      order: json['order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'sets': sets,
    'reps': reps,
    'restTime': restTime,
    'order': order,
  };
}

class Routine {
  final String id;
  final String name;
  final List<RoutineExercise> exercises;
  final bool isWarmup;
  final DateTime? createdAt;

  Routine({
    required this.id,
    required this.name,
    required this.exercises,
    this.isWarmup = false,
    this.createdAt,
  });

  factory Routine.fromJson(Map<String, dynamic> json) {
    return Routine(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      exercises: (json['exercises'] as List?)
              ?.map((e) => RoutineExercise.fromJson(e))
              .toList() ??
          [],
      isWarmup: json['isWarmup'] ?? false,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }
}
