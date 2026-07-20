import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/xp_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  static const _storage = FlutterSecureStorage();
  static const _userKey = 'auth_user';

  User? _user;
  String? _token;
  bool _isLoading = true;
  String? _error;

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null && _user != null;
  String? get error => _error;

  Future<void> tryAutoLogin() async {
    _isLoading = true;
    notifyListeners();

    final token = await _authService.getToken();
    final user = await _authService.getSavedUser();

    if (token != null && user != null) {
      _token = token;
      _user = user;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.login(username, password);
      _token = result['token'] as String;
      _user = result['user'] as User;
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

  Future<bool> register(String username, String password, String displayName) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.register(username, password, displayName);
      _token = result['token'] as String;
      _user = result['user'] as User;
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

  Future<void> logout() async {
    await _authService.logout();
    _token = null;
    _user = null;
    notifyListeners();
  }

  Future<bool> updateProfile({String? displayName, String? avatar, double? weight, double? height, String? goal}) async {
    final token = _token;
    if (token == null) return false;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _authService.updateProfile(token, displayName: displayName, avatar: avatar, weight: weight, height: height, goal: goal);
      _user = user;
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

  Future<void> refreshXp() async {
    if (_token == null) return;
    try {
      final xpService = XpService(_token!);
      final data = await xpService.getXp();
      final newXp = data['xp'] as int? ?? _user?.xp ?? 0;
      final newLevel = data['level'] as int? ?? _user?.level ?? 0;
      final newTitle = data['title'] as String? ?? _user?.title ?? '';
      _user = _user?.copyWith(xp: newXp, level: newLevel, title: newTitle) ?? _user;
      await _storage.write(key: _userKey, value: jsonEncode({
        'id': _user!.id,
        'username': _user!.username,
        'displayName': _user!.displayName,
        'role': _user!.role,
        'avatar': _user!.avatar,
        'xp': _user!.xp,
        'level': _user!.level,
        'title': _user!.title,
      }));
      notifyListeners();
    } catch (_) {}
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
