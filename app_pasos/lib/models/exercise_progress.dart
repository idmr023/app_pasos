/// Sugerencia del motor de progresión de carga (backend/services/progressionService.js).
class ProgressSuggestion {
  /// calibrate | increase | hold | bridge | decrease | deload
  final String action;
  final double weightKg;
  final int? targetReps;
  final int heavySets;
  final double baseWeightKg;
  final int? targetSeconds;
  final String message;

  const ProgressSuggestion({
    required this.action,
    this.weightKg = 0,
    this.targetReps,
    this.heavySets = 0,
    this.baseWeightKg = 0,
    this.targetSeconds,
    this.message = '',
  });

  factory ProgressSuggestion.fromJson(Map<String, dynamic> json) => ProgressSuggestion(
        action: json['action']?.toString() ?? 'hold',
        weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0,
        targetReps: (json['targetReps'] as num?)?.toInt(),
        heavySets: (json['heavySets'] as num?)?.toInt() ?? 0,
        baseWeightKg: (json['baseWeightKg'] as num?)?.toDouble() ?? 0,
        targetSeconds: (json['targetSeconds'] as num?)?.toInt(),
        message: json['message']?.toString() ?? '',
      );

  bool get isBridge => action == 'bridge' && heavySets > 0;
  bool get isDeload => action == 'deload';
}

/// Estado de progresión de un ejercicio (`GET /api/gym/progress`).
class ExerciseProgress {
  final String exerciseId;
  final String exerciseName;
  final double currentWeightKg;
  final int currentSeconds;
  final String unit;
  final String loadNote;
  /// calibrating | progressing | bridge
  final String status;
  final double bridgeTargetKg;
  final int bridgeHeavySets;
  final int stallCount;
  final ProgressSuggestion? next;

  const ExerciseProgress({
    required this.exerciseId,
    this.exerciseName = '',
    this.currentWeightKg = 0,
    this.currentSeconds = 0,
    this.unit = 'kg',
    this.loadNote = '',
    this.status = 'calibrating',
    this.bridgeTargetKg = 0,
    this.bridgeHeavySets = 0,
    this.stallCount = 0,
    this.next,
  });

  factory ExerciseProgress.fromJson(Map<String, dynamic> json) => ExerciseProgress(
        exerciseId: json['exerciseId']?.toString() ?? '',
        exerciseName: json['exerciseName']?.toString() ?? '',
        currentWeightKg: (json['currentWeightKg'] as num?)?.toDouble() ?? 0,
        currentSeconds: (json['currentSeconds'] as num?)?.toInt() ?? 0,
        unit: json['unit']?.toString() == 'lb' ? 'lb' : 'kg',
        loadNote: json['loadNote']?.toString() ?? '',
        status: json['status']?.toString() ?? 'calibrating',
        bridgeTargetKg: (json['bridgeTargetKg'] as num?)?.toDouble() ?? 0,
        bridgeHeavySets: (json['bridgeHeavySets'] as num?)?.toInt() ?? 0,
        stallCount: (json['stallCount'] as num?)?.toInt() ?? 0,
        next: json['next'] is Map<String, dynamic>
            ? ProgressSuggestion.fromJson(json['next'] as Map<String, dynamic>)
            : null,
      );

  bool get isCalibrating => currentWeightKg <= 0 && status == 'calibrating';

  /// Peso sugerido para la serie [setNumber] (1-based): en puente, las primeras
  /// `heavySets` series van con el peso nuevo y el resto con la base.
  double weightForSet(int setNumber) {
    final n = next;
    if (n == null) return currentWeightKg;
    if (n.isBridge) return setNumber <= n.heavySets ? n.weightKg : n.baseWeightKg;
    return n.weightKg > 0 ? n.weightKg : currentWeightKg;
  }

  String get statusLabel => switch (status) {
        'bridge' => 'Puente',
        'progressing' => 'Progresando',
        _ => 'Calibrando',
      };
}

/// Formato de peso sin ceros de sobra: 12.5 → "12.5", 15.0 → "15".
String formatKg(double kg) {
  final r = (kg * 100).round() / 100;
  return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toString();
}
