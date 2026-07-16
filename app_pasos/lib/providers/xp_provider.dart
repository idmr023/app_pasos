import 'package:flutter/material.dart';
import '../services/xp_service.dart';

class XpProvider extends ChangeNotifier {
  XpService? _service;

  int _xp = 0;
  int _level = 0;
  String _title = '';
  Map<String, dynamic> _progress = {};
  List<Map<String, dynamic>> _rewards = [];
  bool _isLoading = false;
  String? _error;

  int get xp => _xp;
  int get level => _level;
  String get title => _title;
  Map<String, dynamic> get progress => _progress;
  List<Map<String, dynamic>> get rewards => _rewards;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setToken(String token) {
    _service = XpService(token);
  }

  Future<void> loadXp() async {
    if (_service == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _service!.getXp();
      _xp = data['xp'] as int;
      _level = data['level'] as int;
      _title = data['title'] as String? ?? '';
      _progress = data['progress'] as Map<String, dynamic>? ?? {};
      _rewards = (data['rewards'] as List?)
              ?.map((r) => r as Map<String, dynamic>)
              .toList() ??
          [];
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> claimReward(String rewardKey) async {
    if (_service == null) return false;
    try {
      await _service!.claimReward(rewardKey);
      await loadXp();
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