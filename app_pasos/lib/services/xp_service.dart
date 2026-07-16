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

class XpService {
  final String token;

  XpService(this.token);

  Future<Map<String, dynamic>> getXp() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/xp'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al obtener XP');
    }
    return data;
  }

  Future<Map<String, dynamic>> getRewards() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/xp/rewards'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al obtener recompensas');
    }
    return data;
  }

  Future<Map<String, dynamic>> claimReward(String rewardKey) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/xp/claim/$rewardKey'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al reclamar recompensa');
    }
    return data;
  }
}