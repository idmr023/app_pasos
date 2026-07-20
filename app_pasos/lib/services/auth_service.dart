import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api.dart';
import '../models/user.dart';

Map<String, dynamic> _parseJson(http.Response response) {
  try {
    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic>) return data;
  } catch (_) {}
  throw Exception('El servidor no respondió correctamente. Verifica tu conexión.');
}

Future<T> _withRetry<T>(Future<T> Function() fn, {int retries = 2}) async {
  for (int i = 0; i <= retries; i++) {
    try {
      return await fn();
    } catch (e) {
      if (i >= retries) rethrow;
      await Future.delayed(Duration(seconds: 1 + i));
    }
  }
  throw Exception('No se pudo conectar con el servidor');
}

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<User?> getSavedUser() async {
    final data = await _storage.read(key: _userKey);
    if (data == null) return null;
    return User.fromJson(jsonDecode(data));
  }

  Future<void> _saveSession(String token, User user) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: jsonEncode({
      'id': user.id,
      'username': user.username,
      'displayName': user.displayName,
      'role': user.role,
      'avatar': user.avatar,
      'xp': user.xp,
      'level': user.level,
      'title': user.title,
      'weight': user.weight,
      'height': user.height,
      'goal': user.goal,
    }));
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    return _withRetry(() async {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(ApiConfig.timeout);

      final data = _parseJson(response);
      if (response.statusCode != 200) {
        throw Exception(data['error'] ?? 'Error al iniciar sesión');
      }

      final user = User.fromJson(data['user']);
      await _saveSession(data['token'], user);
      return {'token': data['token'], 'user': user};
    });
  }

  Future<Map<String, dynamic>> register(String username, String password, String displayName) async {
    return _withRetry(() async {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'displayName': displayName,
        }),
      ).timeout(ApiConfig.timeout);

      final data = _parseJson(response);
      if (response.statusCode != 201) {
        throw Exception(data['error'] ?? 'Error al registrar');
      }

      final user = User.fromJson(data['user']);
      await _saveSession(data['token'], user);
      return {'token': data['token'], 'user': user};
    });
  }

  Future<User> updateProfile(String token, {String? displayName, String? avatar, double? weight, double? height, String? goal}) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['displayName'] = displayName;
    if (avatar != null) body['avatar'] = avatar;
    if (weight != null) body['weight'] = weight;
    if (height != null) body['height'] = height;
    if (goal != null) body['goal'] = goal;

    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/auth/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al actualizar perfil');
    }

    final user = User.fromJson(data['user']);
    await _storage.write(key: _userKey, value: jsonEncode({
      'id': user.id,
      'username': user.username,
      'displayName': user.displayName,
      'role': user.role,
      'avatar': user.avatar,
      'xp': user.xp,
      'level': user.level,
      'title': user.title,
      'weight': user.weight,
      'height': user.height,
      'goal': user.goal,
    }));
    return user;
  }

  Future<User> getProfile(String token) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/auth/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(ApiConfig.timeout);

    final data = _parseJson(response);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al obtener perfil');
    }

    return User.fromJson(data['user']);
  }
}
