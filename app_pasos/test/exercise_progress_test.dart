import 'package:flutter_test/flutter_test.dart';
import 'package:app_pasos/models/exercise_progress.dart';
import 'package:app_pasos/models/routine.dart';

void main() {
  group('ExerciseProgress.weightForSet', () {
    test('puente: primeras series con el peso nuevo, el resto con la base', () {
      final p = ExerciseProgress.fromJson({
        'exerciseId': 'x',
        'currentWeightKg': 7.5,
        'status': 'bridge',
        'next': {'action': 'bridge', 'weightKg': 10, 'heavySets': 1, 'baseWeightKg': 7.5},
      });
      expect(p.weightForSet(1), 10);
      expect(p.weightForSet(2), 7.5);
      expect(p.weightForSet(3), 7.5);
    });

    test('subida: todas las series con el peso sugerido', () {
      final p = ExerciseProgress.fromJson({
        'exerciseId': 'x',
        'currentWeightKg': 17.5,
        'status': 'progressing',
        'next': {'action': 'increase', 'weightKg': 17.5, 'targetReps': 6},
      });
      expect(p.weightForSet(4), 17.5);
      expect(p.isCalibrating, isFalse);
    });

    test('sin sugerencia: usa el peso base', () {
      final p = ExerciseProgress.fromJson({'exerciseId': 'x', 'currentWeightKg': 12});
      expect(p.weightForSet(1), 12);
    });
  });

  group('RoutineExercise', () {
    test('lee y escribe rango e incremento', () {
      final e = RoutineExercise.fromJson({
        'exercise': 'a', 'sets': 4, 'reps': '6-10', 'repsMin': 6, 'repsMax': 10, 'incrementKg': 2,
      });
      expect(e.repsMin, 6);
      expect(e.repsMax, 10);
      expect(e.incrementKg, 2);
      expect(e.defaultTargetReps, 6);
      expect(e.toJson()['repsMax'], 10);
      expect(e.copy().incrementKg, 2);
    });

    test('rutinas antiguas cargan sin rango', () {
      final e = RoutineExercise.fromJson({'exercise': 'a', 'sets': 3, 'reps': '12'});
      expect(e.repsMin, isNull);
      expect(e.incrementKg, 2.5);
      expect(e.defaultTargetReps, 12);
      expect(e.toJson().containsKey('repsMin'), isFalse);
    });

    test('ejercicio por tiempo', () {
      final e = RoutineExercise.fromJson({'exercise': 'a', 'reps': '45s'});
      expect(e.isTimed, isTrue);
      expect(e.targetSeconds, 45);
    });
  });

  test('formatKg quita ceros de sobra', () {
    expect(formatKg(12.5), '12.5');
    expect(formatKg(15), '15');
  });
}
