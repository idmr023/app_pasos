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

/// Cliente HTTP de `/api/wallet` (economía de pasos: saldo, tienda, inventario).
class WalletService {
  final String token;

  WalletService(this.token);

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

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body, String fallbackError) async {
    final response = await http
        .post(Uri.parse('${ApiConfig.baseUrl}$path'), headers: _headers, body: jsonEncode(body))
        .timeout(ApiConfig.timeout);
    final data = _parseJson(response);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(data['error'] ?? fallbackError);
    }
    return data;
  }

  Future<Map<String, dynamic>> getWallet() => _get('/wallet', 'Error al obtener el monedero');

  Future<Map<String, dynamic>> getCatalog() => _get('/wallet/catalog', 'Error al obtener la tienda');

  Future<Map<String, dynamic>> getInventory() => _get('/wallet/inventory', 'Error al obtener el inventario');

  Future<Map<String, dynamic>> purchase(String itemId) =>
      _post('/wallet/purchase', {'itemId': itemId}, 'Error al comprar');

  Future<Map<String, dynamic>> equip(String slot, String? itemId) =>
      _post('/wallet/equip', {'slot': slot, 'itemId': itemId}, 'Error al equipar');
}
