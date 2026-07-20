import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../models/routine.dart';
import '../services/gym_service.dart';

class GymProvider extends ChangeNotifier {
  GymService? _service;

  List<Exercise> _exercises = [];
  bool _hasMore = true;
  bool _isLoading = false;

  List<Routine> _routines = [];
  int _streak = 0;
  bool _currentWeekChecked = false;
  String? _error;
  Map<String, double> _personalRecords = {};
  List<Map<String, dynamic>> _weightAchievements = [];
  double _maxKg = 0;
  Map<String, dynamic>? _currentQuote;

  List<Exercise> get exercises => _exercises;
  List<Routine> get routines => _routines;
  int get streak => _streak;
  bool get currentWeekChecked => _currentWeekChecked;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  Map<String, double> get personalRecords => _personalRecords;
  List<Map<String, dynamic>> get weightAchievements => _weightAchievements;
  double get maxKg => _maxKg;
  Map<String, dynamic>? get currentQuote => _currentQuote;

  double getPrForExercise(String exerciseId) => _personalRecords[exerciseId] ?? 0;

  void setToken(String token) {
    _service = GymService(token);
  }

  Future<void> loadExercises({String? category, String? search, int limit = 20, int offset = 0, bool reset = false}) async {
    if (_service == null) return;
    if (_isLoading) return;
    if (!reset && !_hasMore) return;

    if (reset) {
      _exercises = [];
      _hasMore = true;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final data = await _service!.getExercises(category: category, search: search, limit: limit, offset: offset);
      final list = (data['exercises'] as List)
          .map((e) => Exercise.fromJson(e))
          .toList();
      _exercises.addAll(list);
      _hasMore = list.length >= limit;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (_exercises.isEmpty) {
        await Future.delayed(const Duration(seconds: 3));
        try {
          final data = await _service!.getExercises(category: category, search: search, limit: limit, offset: offset);
          final list = (data['exercises'] as List)
              .map((e) => Exercise.fromJson(e))
              .toList();
          _exercises.addAll(list);
          _hasMore = list.length >= limit;
          _isLoading = false;
          notifyListeners();
          return;
        } catch (_) {}
      }
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
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

  Future<bool> updateRoutine(String id, Map<String, dynamic> body) async {
    if (_service == null) return false;
    try {
      await _service!.updateRoutine(id, body);
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
        final exId = r['exercise']?.toString() ?? '';
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

  Future<void> loadQuote() async {
    if (_service == null) return;
    try {
      final data = await _service!.getQuote(_streak);
      _currentQuote = data['quote'] as Map<String, dynamic>?;
      notifyListeners();
    } catch (_) {}
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
