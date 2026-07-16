import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api.dart';
import '../models/step_entry.dart';

Map<String, dynamic> _parseJson(http.Response response) {
  try {
    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic>) return data;
  } catch (_) {}
  throw Exception('El servidor no respondió correctamente. Verifica tu conexión.');
}

class StepService {
  final String token;

  StepService(this.token);

  Future<StepEntry> saveSteps(String challengeId, DateTime date, int steps) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/steps'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'challengeId': challengeId,
        'date': date.toIso8601String().split('T')[0],
        'steps': steps,
      }),
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al guardar pasos');
    }

    return StepEntry.fromJson(data);
  }

  Future<List<StepEntry>> getSteps({String? challengeId, DateTime? date}) async {
    final queryParams = <String, String>{};
    if (challengeId != null) queryParams['challengeId'] = challengeId;
    if (date != null) queryParams['date'] = date.toIso8601String().split('T')[0];

    final uri = Uri.parse('${ApiConfig.baseUrl}/steps')
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
      throw Exception(data['error'] ?? 'Error al obtener pasos');
    }

    return (data['entries'] as List)
        .map((e) => StepEntry.fromJson(e))
        .toList();
  }

  Future<int> getTodaySteps() async {
    final today = DateTime.now();
    final dateStr = today.toIso8601String().split('T')[0];

    final uri = Uri.parse('${ApiConfig.baseUrl}/steps')
        .replace(queryParameters: {'date': dateStr});

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al obtener pasos');
    }

    final entries = data['entries'] as List;
    int total = 0;
    for (final e in entries) {
      total += e['steps'] as int;
    }
    return total;
  }

  Future<List<CalendarDay>> getCalendar(String challengeId, {int? year, int? month}) async {
    final now = DateTime.now();
    final queryParams = {
      'challengeId': challengeId,
      'year': (year ?? now.year).toString(),
      'month': (month ?? now.month).toString(),
    };

    final uri = Uri.parse('${ApiConfig.baseUrl}/steps/calendar')
        .replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al obtener calendario');
    }

    return (data['calendar'] as List)
        .map((d) => CalendarDay.fromJson(d))
        .toList();
  }
}
