import 'exercise.dart';

class RoutineExercise {
  final String exerciseId;
  Exercise? exercise;
  int sets;
  String reps;
  int restTime;
  int order;

  RoutineExercise({
    required this.exerciseId,
    this.exercise,
    this.sets = 3,
    this.reps = '10',
    this.restTime = 60,
    this.order = 0,
  });

  factory RoutineExercise.fromJson(Map<String, dynamic> json) {
    final exData = json['exercise'];
    return RoutineExercise(
      exerciseId: exData is Map<String, dynamic> ? (exData['_id'] ?? '') : (json['exercise'] ?? ''),
      exercise: exData is Map<String, dynamic> ? Exercise.fromJson(exData) : null,
      sets: json['sets'] ?? 3,
      reps: json['reps'] ?? '10',
      restTime: json['restTime'] ?? 60,
      order: json['order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
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