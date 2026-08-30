import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api.dart';

/// Servicio singleton para la conexión Socket.IO del tracking en vivo.
///
/// El backend usa Socket.IO (no WebSocket crudo), por eso se usa
/// `socket_io_client`. La autenticación se envía en `auth.token` y el
/// roomCode/isRunner en los query params, tal como espera `server.js`.
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;
  final _storage = const FlutterSecureStorage();

  bool get isConnected => _isConnected;

  /// Stream de eventos de tracking ya parseados:
  /// {'type': 'locationUpdate'|'chatMessage'|..., 'data': {...}}
  final StreamController<Map<String, dynamic>> _eventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _eventsController.stream;

  Future<void> connect({required String roomCode, bool isRunner = false}) async {
    disconnect();

    final token = await _storage.read(key: 'auth_token');
    if (token == null) {
      throw Exception('No hay token de autenticación');
    }

    // Derivar la URL base del servidor a partir de ApiConfig.baseUrl
    // (ej. https://app-pasos.onrender.com/api -> https://app-pasos.onrender.com)
    final baseUrl = ApiConfig.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');

    _socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .setQuery({
            'roomCode': roomCode,
            'isRunner': isRunner.toString(),
          })
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
    });

    _socket!.onConnectError((err) {
      _isConnected = false;
      _eventsController.add({
        'type': 'error',
        'data': {'message': 'Error de conexión: $err'},
      });
    });

    _socket!.onError((err) {
      _eventsController.add({
        'type': 'error',
        'data': {'message': '$err'},
      });
    });

    // Eventos del backend -> stream unificado
    for (final event in [
      'connected',
      'locationUpdate',
      'chatMessage',
      'trackingStopped',
      'userJoined',
      'userLeft',
      'error',
    ]) {
      _socket!.on(event, (data) {
        _eventsController.add({'type': event, 'data': data});
      });
    }

    _socket!.connect();
  }

  void sendLocation(Map<String, dynamic> data) {
    if (!_isConnected || _socket == null) return;
    _socket!.emit('locationUpdate', data);
  }

  void sendChatMessage(String message) {
    if (!_isConnected || _socket == null) return;
    _socket!.emit('chatMessage', {'message': message});
  }

  void sendStopTracking() {
    if (!_isConnected || _socket == null) return;
    _socket!.emit('stopTracking');
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }
}
