import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api.dart';
import '../models/training.dart';

/// Cliente de `/api/training` (ver docs/TRAINING.md).
class TrainingService {
  final String token;

  TrainingService(this.token);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${ApiConfig.baseUrl}/training$path').replace(queryParameters: query);

  Map<String, dynamic> _parse(http.Response response, String fallback, {int ok = 200}) {
    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {}
    if (data == null) throw Exception('El servidor no respondió correctamente.');
    if (response.statusCode != ok) throw Exception(data['error'] ?? fallback);
    return data;
  }

  Future<Map<String, dynamic>> getSummary() async {
    final res = await http.get(_uri('/summary'), headers: _headers).timeout(ApiConfig.timeout);
    return _parse(res, 'Error al obtener el resumen');
  }

  Future<List<TrainingSession>> getSessions({DateTime? before, int limit = 30}) async {
    final query = {'limit': '$limit', if (before != null) 'before': before.toUtc().toIso8601String()};
    final res = await http.get(_uri('/sessions', query), headers: _headers).timeout(ApiConfig.timeout);
    final data = _parse(res, 'Error al obtener sesiones');
    return ((data['sessions'] as List?) ?? [])
        .map((e) => TrainingSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TrainingSession> getSession(String id) async {
    final res = await http.get(_uri('/sessions/$id'), headers: _headers).timeout(ApiConfig.timeout);
    final data = _parse(res, 'Error al obtener la sesión');
    return TrainingSession.fromJson(data['session'] as Map<String, dynamic>);
  }

  Future<String> createSession(Map<String, dynamic> body) async {
    final res = await http
        .post(_uri('/sessions'), headers: _headers, body: jsonEncode(body))
        .timeout(ApiConfig.timeout);
    final data = _parse(res, 'Error al registrar la sesión', ok: 201);
    return (data['session'] as Map)['_id'].toString();
  }

  Future<void> updateSession(String id, Map<String, dynamic> body) async {
    final res = await http
        .put(_uri('/sessions/$id'), headers: _headers, body: jsonEncode(body))
        .timeout(ApiConfig.timeout);
    _parse(res, 'Error al guardar la sesión');
  }

  Future<void> deleteSession(String id) async {
    final res = await http.delete(_uri('/sessions/$id'), headers: _headers).timeout(ApiConfig.timeout);
    _parse(res, 'Error al eliminar la sesión');
  }

  Future<TrainingProfile> updateProfile(Map<String, dynamic> body) async {
    final res = await http
        .put(_uri('/profile'), headers: _headers, body: jsonEncode(body))
        .timeout(ApiConfig.timeout);
    final data = _parse(res, 'Error al guardar el perfil');
    return TrainingProfile.fromJson(data['profile'] as Map<String, dynamic>?);
  }

  Future<({List<StravaActivityItem> items, bool hasMore})> getStravaActivities(int page) async {
    final res = await http
        .get(_uri('/strava/activities', {'page': '$page'}), headers: _headers)
        .timeout(ApiConfig.timeout);
    final data = _parse(res, 'Error al obtener actividades de Strava');
    final items = ((data['activities'] as List?) ?? [])
        .map((e) => StravaActivityItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return (items: items, hasMore: data['hasMore'] == true);
  }

  Future<({int imported, int failed})> importStrava(List<int> ids) async {
    final res = await http
        .post(_uri('/strava/import'), headers: _headers, body: jsonEncode({'activityIds': ids}))
        .timeout(const Duration(seconds: 120));
    final data = _parse(res, 'Error al importar desde Strava');
    return (
      imported: (data['importedCount'] as num?)?.toInt() ?? 0,
      failed: (data['failed'] as List?)?.length ?? 0,
    );
  }
}
