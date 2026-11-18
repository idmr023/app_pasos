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

/// Cliente HTTP de `/api/game` (intentos por pasos, partidas y ranking).
class GameService {
  final String token;

  GameService(this.token);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> _get(String path, String fallbackError) async {
    final response = await http
        .get(Uri.parse('${ApiConfig.baseUrl}$path'), headers: _headers)
        .timeout(ApiConfig.timeout);
    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? fallbackError);
    }
    return data;
  }

  Future<Map<String, dynamic>> getFuel() =>
      _get('/game/fuel', 'Error al obtener intentos');

  Future<Map<String, dynamic>> getLeaderboard() =>
      _get('/game/leaderboard', 'Error al obtener el ranking');

  Future<Map<String, dynamic>> getMultiplierStatus() =>
      _get('/game/multiplier-status', 'Error al obtener el multiplicador');

  Future<Map<String, dynamic>> submitScore({
    required int level,
    required int score,
    required int obstaclesDodged,
    required int distance,
    required int coins,
    required int maxCombo,
    required int durationMs,
  }) async {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/game/play'),
          headers: _headers,
          body: jsonEncode({
            'game': 'sprint',
            'level': level,
            'score': score,
            'obstaclesDodged': obstaclesDodged,
            // Compatibilidad con backends que solo conocen el campo de Orbiter
            'asteroidsDodged': obstaclesDodged,
            'distance': distance,
            'coins': coins,
            'maxCombo': maxCombo,
            'durationMs': durationMs,
          }),
        )
        .timeout(ApiConfig.timeout);
    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al guardar la partida');
    }
    return data;
  }
}
