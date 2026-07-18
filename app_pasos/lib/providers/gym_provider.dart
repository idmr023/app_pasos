import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exercise.dart';
import '../models/routine.dart';
import '../services/gym_service.dart';

class GymProvider extends ChangeNotifier {
  GymService? _service;

  List<Exercise> _exercises = [];
  List<Routine> _routines = [];
  int _streak = 0;
  bool _currentWeekChecked = false;
  bool _isLoading = false;
  bool _hasCachedExercises = false;
  String? _error;
  Map<String, double> _personalRecords = {};
  List<Map<String, dynamic>> _weightAchievements = [];
  double _maxKg = 0;

  List<Exercise> get exercises => _exercises;
  List<Routine> get routines => _routines;
  int get streak => _streak;
  bool get currentWeekChecked => _currentWeekChecked;
  bool get isLoading => _isLoading;
  bool get hasCachedExercises => _hasCachedExercises;
  String? get error => _error;
  Map<String, double> get personalRecords => _personalRecords;
  List<Map<String, dynamic>> get weightAchievements => _weightAchievements;
  double get maxKg => _maxKg;

  double getPrForExercise(String exerciseId) => _personalRecords[exerciseId] ?? 0;

  void setToken(String token) {
    _service = GymService(token);
  }

  Future<void> _loadExercisesFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_exercises');
      if (cached != null) {
        final list = jsonDecode(cached) as List;
        _exercises = list.map((e) => Exercise.fromJson(e)).toList();
        _hasCachedExercises = true;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveExercisesToCache(List<Exercise> exercises) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(exercises.map((e) => e.toJson()).toList());
      await prefs.setString('cached_exercises', json);
      _hasCachedExercises = true;
    } catch (_) {}
  }

  Future<void> loadExercises({String? category, String? search}) async {
    if (_service == null) return;

    final isSimpleQuery = category == null && search == null;

    // Si es carga inicial y hay cache, mostrar inmediatamente sin spinner
    if (isSimpleQuery && _exercises.isEmpty) {
      await _loadExercisesFromCache();
    }

    if (isSimpleQuery && _hasCachedExercises && _exercises.isNotEmpty) {
      // Refrescar en background
      _refreshExercisesInBackground(category, search);
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final data = await _service!.getExercises(category: category, search: search);
      final exercises = (data['exercises'] as List)
          .map((e) => Exercise.fromJson(e))
          .toList();
      _exercises = exercises;
      if (isSimpleQuery) _saveExercisesToCache(exercises);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // Si falla y no hay cache, reintentar una vez tras 3s (cold start de Render)
      if (_exercises.isEmpty) {
        await Future.delayed(const Duration(seconds: 3));
        try {
          final data = await _service!.getExercises(category: category, search: search);
          final exercises = (data['exercises'] as List)
              .map((e) => Exercise.fromJson(e))
              .toList();
          _exercises = exercises;
          if (isSimpleQuery) _saveExercisesToCache(exercises);
          _isLoading = false;
          notifyListeners();
          return;
        } catch (_) {}
      }
      // Sin cache ni retry exitoso, mostrar error
      if (_exercises.isNotEmpty) {
        _isLoading = false;
        notifyListeners();
        return;
      }
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _refreshExercisesInBackground(String? category, String? search) async {
    try {
      final data = await _service!.getExercises(category: category, search: search);
      final exercises = (data['exercises'] as List)
          .map((e) => Exercise.fromJson(e))
          .toList();
      _exercises = exercises;
      if (category == null && search == null) _saveExercisesToCache(exercises);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadRoutines({bool? isWarmup}) async {
    if (_service == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _service!.getRoutines(isWarmup: isWarmup);
      _routines = (data['routines'] as List)
          .map((r) => Routine.fromJson(r))
          .toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createRoutine(Map<String, dynamic> body) async {
    if (_service == null) return false;
    try {
      await _service!.createRoutine(body);
      await loadRoutines();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteRoutine(String id) async {
    if (_service == null) return false;
    try {
      await _service!.deleteRoutine(id);
      await loadRoutines();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> loadStreak() async {
    if (_service == null) return;
    try {
      final data = await _service!.getStreak();
      _streak = data['streak'] as int? ?? 0;
      _currentWeekChecked = data['currentWeekChecked'] as bool? ?? false;
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> logWorkout(Map<String, dynamic> body) async {
    if (_service == null) return false;
    try {
      await _service!.logWorkout(body);
      await loadStreak();
      await loadPersonalRecords();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> loadPersonalRecords() async {
    if (_service == null) return;
    try {
      final data = await _service!.getPersonalRecords();
      final records = data['records'] as List? ?? [];
      _personalRecords = {};
      for (final r in records) {
        final exId = r['exercise'] is Map
            ? (r['exercise']['_id'] ?? r['exercise']['id'] ?? '')
            : (r['exercise'] ?? '');
        final w = (r['maxWeightKg'] as num?)?.toDouble() ?? 0;
        if (exId.isNotEmpty) _personalRecords[exId] = w;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadWeightAchievements() async {
    if (_service == null) return;
    try {
      final data = await _service!.getWeightAchievements();
      _weightAchievements = (data['achievements'] as List? ?? [])
          .map((a) => a as Map<String, dynamic>)
          .toList();
      _maxKg = (data['maxKg'] as num?)?.toDouble() ?? 0;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setPersonalRecord(String exerciseId, double weightKg, {String exerciseName = ''}) async {
    if (_service == null) return;
    try {
      await _service!.setPersonalRecord(exerciseId, weightKg, exerciseName: exerciseName);
      _personalRecords[exerciseId] = weightKg;
      notifyListeners();
    } catch (_) {}
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
