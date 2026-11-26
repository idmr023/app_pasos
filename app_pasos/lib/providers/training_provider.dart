import 'package:flutter/foundation.dart';
import '../models/training.dart';
import '../services/training_service.dart';

/// Estado del módulo Entrenamiento: resumen de progresión, perfil y sesiones.
class TrainingProvider with ChangeNotifier {
  String? _token;
  TrainingSummary? _summary;
  TrainingProfile _profile = const TrainingProfile();
  List<TrainingSession> _sessions = [];
  bool _hasStrava = false;
  bool _isLoading = false;
  bool _loadingMore = false;
  bool _hasMoreSessions = true;
  String? _error;

  TrainingSummary? get summary => _summary;
  TrainingProfile get profile => _profile;
  List<TrainingSession> get sessions => _sessions;
  bool get hasStrava => _hasStrava;
  bool get isLoading => _isLoading;
  bool get loadingMore => _loadingMore;
  bool get hasMoreSessions => _hasMoreSessions;
  String? get error => _error;

  TrainingService? get service => _token == null ? null : TrainingService(_token!);

  void setToken(String token) {
    final changed = token != _token;
    _token = token;
    if (changed || _summary == null) load();
  }

  String _msg(Object e) => e.toString().replaceAll('Exception: ', '');

  Future<void> load() async {
    final svc = service;
    if (svc == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([svc.getSummary(), svc.getSessions()]);
      final data = results[0] as Map<String, dynamic>;
      _summary = TrainingSummary.fromJson(data['summary'] as Map<String, dynamic>);
      _profile = TrainingProfile.fromJson(data['profile'] as Map<String, dynamic>?);
      _hasStrava = data['hasStrava'] == true;
      _sessions = results[1] as List<TrainingSession>;
      _hasMoreSessions = _sessions.length >= 30;
    } catch (e) {
      _error = _msg(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreSessions() async {
    final svc = service;
    if (svc == null || _loadingMore || !_hasMoreSessions || _sessions.isEmpty) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final more = await svc.getSessions(before: _sessions.last.startDate);
      _sessions = [..._sessions, ...more];
      _hasMoreSessions = more.length >= 30;
    } catch (e) {
      _error = _msg(e);
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  /// Devuelve null si salió bien, o el mensaje de error.
  Future<String?> _run(Future<void> Function(TrainingService svc) action) async {
    final svc = service;
    if (svc == null) return 'Sesión no iniciada';
    try {
      await action(svc);
      await load();
      return null;
    } catch (e) {
      return _msg(e);
    }
  }

  Future<String?> updateSession(String id, Map<String, dynamic> body) =>
      _run((svc) => svc.updateSession(id, body));

  Future<String?> deleteSession(String id) => _run((svc) => svc.deleteSession(id));

  Future<String?> createSession(Map<String, dynamic> body) => _run((svc) => svc.createSession(body));

  Future<String?> updateProfile(Map<String, dynamic> body) => _run((svc) => svc.updateProfile(body));

  Future<String?> importFromStrava(List<int> ids) async {
    final svc = service;
    if (svc == null) return 'Sesión no iniciada';
    try {
      final r = await svc.importStrava(ids);
      await load();
      if (r.failed > 0) return 'Importadas ${r.imported}; ${r.failed} no se pudieron importar';
      return null;
    } catch (e) {
      return _msg(e);
    }
  }
}
