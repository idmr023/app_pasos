import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api.dart';
import '../models/challenge.dart';

Map<String, dynamic> _parseJson(http.Response response) {
  try {
    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic>) return data;
  } catch (_) {}
  throw Exception('El servidor no respondió correctamente. Verifica tu conexión.');
}

class ChallengeService {
  final String token;

  ChallengeService(this.token);

  Future<Challenge> createChallenge({int duration = 30}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/challenges'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'duration': duration}),
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 201) {
      throw Exception(data['error'] ?? 'Error al crear reto');
    }

    return Challenge.fromJson(data);
  }

  Future<Challenge> joinChallenge(String code) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/challenges/join'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'code': code}),
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al unirse al reto');
    }

    return Challenge.fromJson(data);
  }

  Future<List<Challenge>> getChallenges() async {
    return getChallengesByStatus(null);
  }

  Future<List<Challenge>> getChallengesByStatus(String? status) async {
    final queryParams = <String, String>{};
    if (status != null) queryParams['status'] = status;

    final uri = Uri.parse('${ApiConfig.baseUrl}/challenges')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al obtener retos');
    }

    return (data['challenges'] as List)
        .map((c) => Challenge.fromJson(c))
        .toList();
  }

  Future<Map<String, dynamic>> getChallengeDetail(String id) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/challenges/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al obtener reto');
    }

    return data;
  }

  Future<void> leaveChallenge(String id) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/challenges/$id/leave'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al salir del reto');
    }
  }

  Future<void> deleteChallenge(String id) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/challenges/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al eliminar reto');
    }
  }

  Future<List<Map<String, dynamic>>> getAnalytics(String challengeId, {String? start, String? end}) async {
    final queryParams = <String, String>{};
    if (start != null) queryParams['start'] = start;
    if (end != null) queryParams['end'] = end;

    final uri = Uri.parse('${ApiConfig.baseUrl}/steps/$challengeId/analytics')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al obtener estadísticas');
    }

    return List<Map<String, dynamic>>.from(data['entries']);
  }
}
