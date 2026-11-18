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

/// Cliente HTTP de `/api/leagues` (ligas semanales). Ver docs/LEAGUES.md.
class LeagueService {
  final String token;

  LeagueService(this.token);

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

  Future<Map<String, dynamic>> getCurrent() =>
      _get('/leagues/current', 'Error al obtener la liga');

  Future<Map<String, dynamic>> getHistory() =>
      _get('/leagues/history', 'Error al obtener el historial de ligas');

  Future<void> ackResult({String? week}) async {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/leagues/ack-result'),
          headers: _headers,
          body: jsonEncode({if (week != null) 'week': week}),
        )
        .timeout(ApiConfig.timeout);
    if (response.statusCode != 200) {
      final data = _parseJson(response);
      throw Exception(data['error'] ?? 'Error al confirmar el resultado');
    }
  }
}
