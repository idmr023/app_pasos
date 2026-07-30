import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api.dart';
import '../models/route.dart';

Map<String, dynamic> _parseJson(http.Response response) {
  try {
    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic>) return data;
  } catch (_) {}
  throw Exception('El servidor no respondió correctamente.');
}

class RouteService {
  final String token;

  RouteService(this.token);

  Future<List<UserRoute>> getRoutes() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/routes'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al obtener rutas');
    }

    final list = data['routes'] as List? ?? [];
    return list.map((r) => UserRoute.fromJson(r)).toList();
  }

  Future<UserRoute> getRoute(String id) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/routes/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al obtener ruta');
    }

    return UserRoute.fromJson(data['route']);
  }

  Future<UserRoute> createRoute(Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/routes'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 201) {
      throw Exception(data['error'] ?? 'Error al crear ruta');
    }

    return UserRoute.fromJson(data['route']);
  }

  Future<void> deleteRoute(String id) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/routes/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al eliminar ruta');
    }
  }

  Future<String> getStravaAuthUrl() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/routes/strava/auth-url'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al obtener URL de Strava');
    }
    return data['url'];
  }

  Future<bool> connectStrava(String code) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/routes/strava/connect'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'code': code}),
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al conectar con Strava');
    }
    return true;
  }

  Future<int> syncStravaActivities() async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/routes/strava/sync'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al sincronizar con Strava');
    }
    return data['count'] ?? 0;
  }
}
