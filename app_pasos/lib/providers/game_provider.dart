import 'package:flutter/material.dart';
import '../services/game_service.dart';

int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

/// Fila del ranking del minijuego.
class GameLeaderboardEntry {
  final int rank;
  final String username;
  final String avatar;
  final int score;
  final int level;
  final int distance;
  final bool isMe;

  const GameLeaderboardEntry({
    required this.rank,
    required this.username,
    required this.avatar,
    required this.score,
    required this.level,
    required this.distance,
    required this.isMe,
  });

  factory GameLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return GameLeaderboardEntry(
      rank: _int(json['rank']),
      username: json['username'] as String? ?? 'Anon',
      avatar: json['avatar'] as String? ?? 'runner',
      score: _int(json['score']),
      level: _int(json['level']),
      distance: _int(json['distance']),
      isMe: json['isMe'] == true,
    );
  }
}

/// Resultado de enviar una partida a `/api/game/play`.
class GameSubmitResult {
  final int xpAwarded;
  final bool isNewBest;
  final int bestScore;
  final int attemptsLeft;

  const GameSubmitResult({
    required this.xpAwarded,
    required this.isNewBest,
    required this.bestScore,
    required this.attemptsLeft,
  });
}

class GameProvider extends ChangeNotifier {
  GameService? _service;

  // Intentos ("combustible") ganados con los pasos de hoy
  int _attempts = 0;
  int _maxAttempts = 0;
  int _usedToday = 0;
  int _stepsToday = 0;
  int _stepsUntilNext = 2000;
  int _stepsPerAttempt = 2000;
  int _maxAttemptsPerDay = 5;

  // Multiplicador de XP
  bool _hasMultiplier = false;
  int _bestLevelToday = 0;
  int _multiplierLevel = 5;
  double _multiplierValue = 1.5;

  // Boost por pasos reales: escudo (un choque gratis) en carreras oficiales
  bool _hasShield = false;
  int _shieldStepsRequired = 8000;
  int _shieldStepsToday = 0;

  int _bestScore = 0;
  int? _myRank;
  List<GameLeaderboardEntry> _leaderboard = [];

  bool _isLoading = false;
  bool _isLoadingLeaderboard = false;
  bool _hasLoadedFuel = false;
  String? _error;

  int get attempts => _attempts;
  int get maxAttempts => _maxAttempts;
  int get usedToday => _usedToday;
  int get stepsToday => _stepsToday;
  int get stepsUntilNext => _stepsUntilNext;
  int get stepsPerAttempt => _stepsPerAttempt;
  int get maxAttemptsPerDay => _maxAttemptsPerDay;
  bool get hasMultiplier => _hasMultiplier;
  int get bestLevelToday => _bestLevelToday;
  int get multiplierLevel => _multiplierLevel;
  double get multiplierValue => _multiplierValue;
  bool get hasShield => _hasShield;
  int get shieldStepsRequired => _shieldStepsRequired;
  int get shieldStepsToday => _shieldStepsToday;
  int get bestScore => _bestScore;
  int? get myRank => _myRank;
  List<GameLeaderboardEntry> get leaderboard => _leaderboard;
  bool get isLoading => _isLoading;
  bool get isLoadingLeaderboard => _isLoadingLeaderboard;
  bool get hasLoadedFuel => _hasLoadedFuel;
  bool get hasService => _service != null;
  String? get error => _error;

  void setToken(String token) {
    _service = GameService(token);
  }

  Future<void> loadAll() async {
    await Future.wait([loadFuel(), loadLeaderboard()]);
  }

  Future<void> loadFuel() async {
    if (_service == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _service!.getFuel();
      _attempts = _int(data['attempts']);
      _maxAttempts = _int(data['maxAttempts']);
      _usedToday = _int(data['usedToday']);
      _stepsToday = _int(data['stepsToday']);
      _stepsUntilNext = _int(data['stepsUntilNext']);
      _hasMultiplier = data['hasMultiplier'] == true;
      _bestLevelToday = _int(data['bestLevelToday']);
      if (data['stepsPerAttempt'] != null) {
        _stepsPerAttempt = _int(data['stepsPerAttempt']);
      }
      if (data['maxAttemptsPerDay'] != null) {
        _maxAttemptsPerDay = _int(data['maxAttemptsPerDay']);
      }
      if (data['multiplierLevel'] != null) {
        _multiplierLevel = _int(data['multiplierLevel']);
      }
      if (data['multiplierValue'] is num) {
        _multiplierValue = (data['multiplierValue'] as num).toDouble();
      }
      if (data['bestScore'] != null) {
        _bestScore = _int(data['bestScore']);
      }
      final shield = data['shield'];
      if (shield is Map<String, dynamic>) {
        _hasShield = shield['active'] == true;
        _shieldStepsRequired = _int(shield['stepsRequired']);
        _shieldStepsToday = _int(shield['stepsToday']);
      }
      _hasLoadedFuel = true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadLeaderboard() async {
    if (_service == null) return;
    _isLoadingLeaderboard = true;
    notifyListeners();
    try {
      final data = await _service!.getLeaderboard();
      _leaderboard = (data['leaderboard'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(GameLeaderboardEntry.fromJson)
          .toList();
      final me = data['me'];
      if (me is Map<String, dynamic>) {
        _myRank = me['rank'] == null ? null : _int(me['rank']);
        final best = _int(me['bestScore']);
        if (best > _bestScore) _bestScore = best;
      }
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    _isLoadingLeaderboard = false;
    notifyListeners();
  }

  /// Envía una partida oficial (consume un intento). Lanza excepción si falla.
  Future<GameSubmitResult> submitScore({
    required int level,
    required int score,
    required int obstaclesDodged,
    required int distance,
    required int coins,
    required int maxCombo,
    required int durationMs,
  }) async {
    if (_service == null) {
      throw Exception('Inicia sesión para guardar tu puntuación');
    }
    final data = await _service!.submitScore(
      level: level,
      score: score,
      obstaclesDodged: obstaclesDodged,
      distance: distance,
      coins: coins,
      maxCombo: maxCombo,
      durationMs: durationMs,
    );
    final fuel = data['fuel'];
    if (fuel is Map<String, dynamic>) {
      _attempts = _int(fuel['attempts']);
      _usedToday = _int(fuel['usedToday']);
      _maxAttempts = _int(fuel['maxAttempts']);
    }
    if (data['hasMultiplier'] == true) {
      _hasMultiplier = true;
      if (level > _bestLevelToday) _bestLevelToday = level;
    }
    final previousBest = _bestScore;
    final best = data['bestScore'] != null ? _int(data['bestScore']) : score;
    if (best > _bestScore) _bestScore = best;
    notifyListeners();
    // El ranking puede haber cambiado; se refresca en segundo plano.
    loadLeaderboard();
    return GameSubmitResult(
      xpAwarded: _int(data['xpAwarded']),
      isNewBest: data['isNewBest'] == true || score > previousBest,
      bestScore: _bestScore,
      attemptsLeft: _attempts,
    );
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
