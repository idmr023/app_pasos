import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api.dart';

Map<String, dynamic> _parseJson(http.Response response) {
  try {
    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic>) return data;
  } catch (_) {}
  throw Exception('El servidor no respondió correctamente. Verifica tu conexión.');
}

class GymService {
  final String token;

  GymService(this.token);

  Future<Map<String, dynamic>> getExercises({String? category}) async {
    final queryParams = <String, String>{};
    if (category != null) queryParams['category'] = category;

    final uri = Uri.parse('${ApiConfig.baseUrl}/gym/exercises')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    final response = await http.get(uri, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    }).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al obtener ejercicios');
    }
    return data;
  }

  Future<Map<String, dynamic>> getRoutines({bool? isWarmup}) async {
    final queryParams = <String, String>{};
    if (isWarmup != null) queryParams['isWarmup'] = isWarmup.toString();

    final uri = Uri.parse('${ApiConfig.baseUrl}/gym/routines')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    final response = await http.get(uri, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    }).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al obtener rutinas');
    }
    return data;
  }

  Future<Map<String, dynamic>> getRoutine(String id) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/gym/routines/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al obtener rutina');
    }
    return data;
  }

  Future<Map<String, dynamic>> createRoutine(Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/gym/routines'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 201) {
      throw Exception(data['error'] ?? 'Error al crear rutina');
    }
    return data;
  }

  Future<Map<String, dynamic>> updateRoutine(String id, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/gym/routines/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al actualizar rutina');
    }
    return data;
  }

  Future<void> deleteRoutine(String id) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/gym/routines/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(ApiConfig.timeout);

    if (response.statusCode != 200) {
      final data = _parseJson(response);
      throw Exception(data['error'] ?? 'Error al eliminar rutina');
    }
  }

  Future<Map<String, dynamic>> logWorkout(Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/gym/workouts'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 201) {
      throw Exception(data['error'] ?? 'Error al registrar entrenamiento');
    }
    return data;
  }

  Future<Map<String, dynamic>> getStreak() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/gym/streak'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al obtener racha');
    }
    return data;
  }
}