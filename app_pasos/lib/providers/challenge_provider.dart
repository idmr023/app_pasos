import 'package:flutter/material.dart';
import '../models/challenge.dart';
import '../services/challenge_service.dart';

class ChallengeProvider extends ChangeNotifier {
  ChallengeService? _service;

  List<Challenge> _challenges = [];
  Challenge? _currentChallenge;
  Map<String, dynamic>? _challengeDetail;
  bool _isLoading = false;
  String? _error;

  List<Challenge> get challenges => _challenges;
  Challenge? get currentChallenge => _currentChallenge;
  Map<String, dynamic>? get challengeDetail => _challengeDetail;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setToken(String token) {
    _service = ChallengeService(token);
  }

  Future<bool> createChallenge() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final challenge = await _service!.createChallenge();
      _currentChallenge = challenge;
      _challenges.insert(0, challenge);
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

  Future<bool> joinChallenge(String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final challenge = await _service!.joinChallenge(code);
      _currentChallenge = challenge;
      _challenges.insert(0, challenge);
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

  Future<void> loadChallenges() async {
    _isLoading = true;
    notifyListeners();

    try {
      _challenges = await _service!.getChallenges();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadChallengeDetail(String id) async {
    _isLoading = true;
    notifyListeners();

    try {
      _challengeDetail = await _service!.getChallengeDetail(id);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
