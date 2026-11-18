import 'package:flutter/material.dart';
import '../services/league_service.dart';

int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
double _double(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

Color _hexColor(String? hex, Color fallback) {
  if (hex == null) return fallback;
  final clean = hex.replaceAll('#', '');
  final value = int.tryParse(clean.length == 6 ? 'FF$clean' : clean, radix: 16);
  return value == null ? fallback : Color(value);
}

/// Una división (Bronce … Leyenda).
class LeagueDivision {
  final int index;
  final String key;
  final String name;
  final Color color;

  const LeagueDivision({required this.index, required this.key, required this.name, required this.color});

  factory LeagueDivision.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const {};
    return LeagueDivision(
      index: _int(j['index']),
      key: j['key'] as String? ?? 'bronce',
      name: j['name'] as String? ?? 'Bronce',
      color: _hexColor(j['color'] as String?, const Color(0xFFCD7F32)),
    );
  }
}

/// Desglose de puntos semanales.
class LeagueBreakdown {
  final int steps;
  final int stepsPoints;
  final int workouts;
  final int workoutsPoints;
  final int games;
  final int gamesPoints;
  final double runKm;
  final int runsPoints;
  final int total;

  const LeagueBreakdown({
    this.steps = 0,
    this.stepsPoints = 0,
    this.workouts = 0,
    this.workoutsPoints = 0,
    this.games = 0,
    this.gamesPoints = 0,
    this.runKm = 0,
    this.runsPoints = 0,
    this.total = 0,
  });

  factory LeagueBreakdown.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const {};
    Map<String, dynamic> part(String k) => (j[k] as Map?)?.cast<String, dynamic>() ?? const {};
    return LeagueBreakdown(
      steps: _int(part('steps')['value']),
      stepsPoints: _int(part('steps')['points']),
      workouts: _int(part('workouts')['count']),
      workoutsPoints: _int(part('workouts')['points']),
      games: _int(part('games')['count']),
      gamesPoints: _int(part('games')['points']),
      runKm: _double(part('runs')['km']),
      runsPoints: _int(part('runs')['points']),
      total: _int(j['total']),
    );
  }
}

/// Fila de la clasificación del grupo. `zone`: promote | stay | demote.
class LeagueStanding {
  final String userId;
  final String username;
  final String displayName;
  final String avatar;
  final int level;
  final int points;
  final int rank;
  final String zone;
  final bool isMe;
  final LeagueBreakdown breakdown;

  const LeagueStanding({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatar,
    required this.level,
    required this.points,
    required this.rank,
    required this.zone,
    required this.isMe,
    required this.breakdown,
  });

  factory LeagueStanding.fromJson(Map<String, dynamic> json) {
    return LeagueStanding(
      userId: json['userId'] as String? ?? '',
      username: json['username'] as String? ?? 'usuario',
      displayName: json['displayName'] as String? ?? 'Usuario',
      avatar: json['avatar'] as String? ?? '',
      level: _int(json['level']),
      points: _int(json['points']),
      rank: _int(json['rank']),
      zone: json['zone'] as String? ?? 'stay',
      isMe: json['isMe'] == true,
      breakdown: LeagueBreakdown.fromJson((json['breakdown'] as Map?)?.cast<String, dynamic>()),
    );
  }
}

/// Resultado congelado de una semana (para la celebración y el historial).
class LeagueWeekResult {
  final String week;
  final LeagueDivision division;
  final LeagueDivision? newDivision;
  final int? finalRank;
  final int? finalPoints;
  final String? result; // promoted | stayed | demoted | null (semana abierta)
  final int groupSize;
  final bool current;

  const LeagueWeekResult({
    required this.week,
    required this.division,
    this.newDivision,
    this.finalRank,
    this.finalPoints,
    this.result,
    this.groupSize = 0,
    this.current = false,
  });

  factory LeagueWeekResult.fromJson(Map<String, dynamic> json) {
    final nd = json['newDivision'];
    return LeagueWeekResult(
      week: json['week'] as String? ?? '',
      division: LeagueDivision.fromJson((json['division'] as Map?)?.cast<String, dynamic>()),
      newDivision: nd is Map ? LeagueDivision.fromJson(nd.cast<String, dynamic>()) : null,
      finalRank: json['finalRank'] == null ? null : _int(json['finalRank']),
      finalPoints: json['finalPoints'] == null ? null : _int(json['finalPoints']),
      result: json['result'] as String?,
      groupSize: _int(json['groupSize']),
      current: json['current'] == true,
    );
  }
}

class LeagueProvider extends ChangeNotifier {
  LeagueService? _service;

  bool _loading = false;
  bool _loaded = false;
  String? _error;
  DateTime? _lastLoad;

  String _week = '';
  LeagueDivision _division = LeagueDivision.fromJson(null);
  List<LeagueDivision> _divisions = const [];
  List<LeagueStanding> _standings = const [];
  LeagueStanding? _me;
  int _promoteCount = 0;
  int _demoteCount = 0;
  int _maxGroupSize = 20;
  DateTime? _weekEndsAt; // reloj local, a partir de timeRemainingMs del servidor
  LeagueWeekResult? _pendingResult;
  Map<String, dynamic> _pointsRules = const {};

  List<LeagueWeekResult> _history = const [];
  bool _loadingHistory = false;

  bool get isLoading => _loading;
  bool get hasLoaded => _loaded;
  String? get error => _error;
  String get week => _week;
  LeagueDivision get division => _division;
  List<LeagueDivision> get divisions => _divisions;
  List<LeagueStanding> get standings => _standings;
  LeagueStanding? get me => _me;
  int get promoteCount => _promoteCount;
  int get demoteCount => _demoteCount;
  int get maxGroupSize => _maxGroupSize;
  DateTime? get weekEndsAt => _weekEndsAt;
  LeagueWeekResult? get pendingResult => _pendingResult;
  Map<String, dynamic> get pointsRules => _pointsRules;
  List<LeagueWeekResult> get history => _history;
  bool get isLoadingHistory => _loadingHistory;

  Duration get timeRemaining {
    final end = _weekEndsAt;
    if (end == null) return Duration.zero;
    final d = end.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  void setToken(String token) {
    if (_service?.token == token) return;
    _service = LeagueService(token);
  }

  /// Recarga si nunca se cargó o si los datos tienen más de [maxAge].
  Future<void> loadIfStale({Duration maxAge = const Duration(minutes: 1)}) async {
    final last = _lastLoad;
    if (last != null && DateTime.now().difference(last) < maxAge && _loaded) return;
    await loadCurrent();
  }

  Future<void> loadCurrent() async {
    final service = _service;
    if (service == null || _loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await service.getCurrent();
      _week = data['week'] as String? ?? '';
      _division = LeagueDivision.fromJson((data['division'] as Map?)?.cast<String, dynamic>());
      _divisions = ((data['divisions'] as List?) ?? const [])
          .whereType<Map>()
          .map((d) => LeagueDivision.fromJson(d.cast<String, dynamic>()))
          .toList();
      _standings = ((data['standings'] as List?) ?? const [])
          .whereType<Map>()
          .map((s) => LeagueStanding.fromJson(s.cast<String, dynamic>()))
          .toList();
      final me = data['me'];
      _me = me is Map ? LeagueStanding.fromJson(me.cast<String, dynamic>()) : null;
      final group = (data['group'] as Map?)?.cast<String, dynamic>() ?? const {};
      _promoteCount = _int(group['promoteCount']);
      _demoteCount = _int(group['demoteCount']);
      _maxGroupSize = _int(group['maxSize']) == 0 ? 20 : _int(group['maxSize']);
      _weekEndsAt = DateTime.now().add(Duration(milliseconds: _int(data['timeRemainingMs'])));
      final pending = data['pendingResult'];
      _pendingResult = pending is Map ? LeagueWeekResult.fromJson(pending.cast<String, dynamic>()) : null;
      _pointsRules = (data['pointsRules'] as Map?)?.cast<String, dynamic>() ?? const {};
      _loaded = true;
      _lastLoad = DateTime.now();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadHistory() async {
    final service = _service;
    if (service == null || _loadingHistory) return;
    _loadingHistory = true;
    notifyListeners();
    try {
      final data = await service.getHistory();
      _history = ((data['history'] as List?) ?? const [])
          .whereType<Map>()
          .map((h) => LeagueWeekResult.fromJson(h.cast<String, dynamic>()))
          .toList();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _loadingHistory = false;
      notifyListeners();
    }
  }

  /// Marca como visto el resultado pendiente (la celebración se muestra una sola vez).
  Future<void> ackPendingResult() async {
    final pending = _pendingResult;
    final service = _service;
    if (pending == null || service == null) return;
    _pendingResult = null;
    notifyListeners();
    try {
      // Sin semana: marca también resultados más antiguos que nunca se vieron.
      await service.ackResult();
    } catch (_) {
      // Si falla, el servidor lo volverá a enviar en la próxima carga.
    }
  }
}
