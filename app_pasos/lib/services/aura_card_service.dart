import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api.dart';
import '../models/route_card_template.dart';

class AuraCardData {
  final String imageUrl;
  final Map<String, dynamic> stats;
  final String template;
  final int width;
  final int height;
  final RouteCardTemplate templateConfig;

  AuraCardData({
    required this.imageUrl,
    required this.stats,
    required this.template,
    required this.width,
    required this.height,
    required this.templateConfig,
  });
}

class AuraCardService {
  final String token;

  AuraCardService(this.token);

  Future<AuraCardData> getMapCardData(
    String routeId, {
    String template = 'cyberpunk',
    int width = 1080,
    int height = 1350,
  }) async {
    final uri = Uri.parse(
        '${ApiConfig.baseUrl}/routes/$routeId/map-card')
        .replace(queryParameters: {
      'template': template,
      'width': width.toString(),
      'height': height.toString(),
    });

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(ApiConfig.timeout);

    if (response.statusCode != 200) {
      final data = _parseJson(response.body);
      throw Exception(data['error'] ?? 'Error al generar card');
    }

    final data = _parseJson(response.body);
    final templateConfig = getTemplateById(template);

    return AuraCardData(
      imageUrl: data['url'],
      stats: Map<String, dynamic>.from(data['stats']),
      template: data['template'],
      width: data['width'],
      height: data['height'],
      templateConfig: templateConfig,
    );
  }

  Future<Uint8List> downloadMapImage(String url) async {
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('Error al descargar imagen del mapa');
    }
    return response.bodyBytes;
  }

  Map<String, dynamic> _parseJson(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) return data;
    } catch (_) {}
    throw Exception('El servidor no respondió correctamente.');
  }
}
