import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api.dart';
import '../models/chat_message.dart';

Map<String, dynamic> _parseJson(http.Response response) {
  try {
    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic>) return data;
  } catch (_) {}
  throw Exception('El servidor no respondió correctamente. Verifica tu conexión.');
}

class ChatService {
  final String token;

  ChatService(this.token);

  Future<Map<String, dynamic>> sendMessage(String message) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/chat'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'message': message}),
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al enviar mensaje');
    }
    return data;
  }

  Future<List<ChatMessage>> getHistory() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/chat/history'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al obtener historial');
    }

    final messages = data['messages'] as List? ?? [];
    return messages.map((m) => ChatMessage.fromJson(m)).toList();
  }

  Future<void> clearHistory() async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/chat/history'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    ).timeout(ApiConfig.timeout);

    if (response.statusCode != 200) {
      final data = _parseJson(response);
      throw Exception(data['error'] ?? 'Error al borrar historial');
    }
  }
}
