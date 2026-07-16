import 'package:flutter/material.dart';
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
  String? _error;

  List<Exercise> get exercises => _exercises;
  List<Routine> get routines => _routines;
  int get streak => _streak;
  bool get currentWeekChecked => _currentWeekChecked;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setToken(String token) {
    _service = GymService(token);
  }

  Future<void> loadExercises({String? category}) async {
    if (_service == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _service!.getExercises(category: category);
      _exercises = (data['exercises'] as List)
          .map((e) => Exercise.fromJson(e))
          .toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
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
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}