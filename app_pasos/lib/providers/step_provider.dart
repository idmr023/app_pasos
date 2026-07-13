import 'package:flutter/material.dart';
import '../models/step_entry.dart';
import '../services/step_service.dart';

class StepProvider extends ChangeNotifier {
  StepService? _service;

  List<CalendarDay> _calendar = [];
  int _todaySteps = 0;
  bool _isLoading = false;
  String? _error;

  List<CalendarDay> get calendar => _calendar;
  int get todaySteps => _todaySteps;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setToken(String token) {
    _service = StepService(token);
  }

  Future<bool> saveSteps(String challengeId, DateTime date, int steps) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service!.saveSteps(challengeId, date, steps);

      final today = DateTime.now();
      if (date.year == today.year &&
          date.month == today.month &&
          date.day == today.day) {
        _todaySteps = steps;
      }

      await loadCalendar(challengeId, year: date.year, month: date.month);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadCalendar(String challengeId, {int? year, int? month}) async {
    try {
      _calendar = await _service!.getCalendar(challengeId, year: year, month: month);

      final today = DateTime.now();
      final todayStr = today.toIso8601String().split('T')[0];
      for (final day in _calendar) {
        if (day.date == todayStr && day.entries.isNotEmpty) {
          _todaySteps = day.entries.first.steps;
          break;
        }
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
