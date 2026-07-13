import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api.dart';
import '../models/challenge.dart';

class ChallengeService {
  final String token;

  ChallengeService(this.token);

  Future<Challenge> createChallenge() async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/challenges'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(ApiConfig.timeout);

    final data = jsonDecode(response.body);
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

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al unirse al reto');
    }

    return Challenge.fromJson(data);
  }

  Future<List<Challenge>> getChallenges() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/challenges'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(ApiConfig.timeout);

    final data = jsonDecode(response.body);
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

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al obtener reto');
    }

    return data;
  }
}
