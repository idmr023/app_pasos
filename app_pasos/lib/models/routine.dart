class RoutineExercise {
  final String exerciseId;
  final String exerciseName;
  int sets;
  String reps;
  int restTime;
  int order;
  /// Rango de repeticiones para la progresión de carga (null = se deriva de [reps]).
  int? repsMin;
  int? repsMax;
  double incrementKg;

  RoutineExercise({
    required this.exerciseId,
    this.exerciseName = '',
    this.sets = 3,
    this.reps = '10',
    this.restTime = 60,
    this.order = 0,
    this.repsMin,
    this.repsMax,
    this.incrementKg = 2.5,
  });

  factory RoutineExercise.fromJson(Map<String, dynamic> json) {
    return RoutineExercise(
      exerciseId: json['exercise']?.toString() ?? '',
      exerciseName: json['exerciseName']?.toString() ?? '',
      sets: json['sets'] ?? 3,
      reps: json['reps']?.toString() ?? '10',
      restTime: json['restTime'] ?? 60,
      order: json['order'] ?? 0,
      repsMin: (json['repsMin'] as num?)?.toInt(),
      repsMax: (json['repsMax'] as num?)?.toInt(),
      incrementKg: (json['incrementKg'] as num?)?.toDouble() ?? 2.5,
    );
  }

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'sets': sets,
    'reps': reps,
    'restTime': restTime,
    'order': order,
    if (repsMin != null) 'repsMin': repsMin,
    if (repsMax != null) 'repsMax': repsMax,
    'incrementKg': incrementKg,
  };

  /// Ejercicio por tiempo (`reps` termina en "s", ej. "45s").
  bool get isTimed => RegExp(r'^\d+\s*s', caseSensitive: false).hasMatch(reps.trim());

  /// Segundos objetivo de un ejercicio por tiempo (0 si no aplica).
  int get targetSeconds => int.tryParse(RegExp(r'^(\d+)').firstMatch(reps.trim())?.group(1) ?? '') ?? 0;

  /// Repeticiones objetivo por defecto para registrar una serie (piso del rango).
  int get defaultTargetReps {
    if (repsMin != null) return repsMin!;
    final m = RegExp(r'^(\d+)').firstMatch(reps.trim());
    return int.tryParse(m?.group(1) ?? '') ?? 10;
  }

  /// Copia con todos los campos (al editar una rutina no se pierde nada).
  RoutineExercise copy() => RoutineExercise(
    exerciseId: exerciseId,
    exerciseName: exerciseName,
    sets: sets,
    reps: reps,
    restTime: restTime,
    order: order,
    repsMin: repsMin,
    repsMax: repsMax,
    incrementKg: incrementKg,
  );
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
