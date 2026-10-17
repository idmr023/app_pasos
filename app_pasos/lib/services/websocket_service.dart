import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io_client;
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

  io_client.Socket? _socket;
  bool _isConnected = false;
  final _storage = const FlutterSecureStorage();
  String? _roomCode;
  bool _isRunner = false;
  String? _guestName;

  bool get isConnected => _isConnected;

  /// Stream de eventos de tracking ya parseados:
  /// {'type': 'locationUpdate'|'chatMessage'|..., 'data': {...}}
  final StreamController<Map<String, dynamic>> _eventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _eventsController.stream;

  Future<void> connect({
    required String roomCode,
    bool isRunner = false,
    String? guestName,
  }) async {
    disconnect();
    _roomCode = roomCode;
    _isRunner = isRunner;
    _guestName = guestName;

    final token = await _storage.read(key: 'auth_token');
    final isGuest = guestName != null;

    if (!isGuest && token == null) {
      throw Exception('No hay token de autenticación');
    }

    // Derivar la URL base del servidor a partir de ApiConfig.baseUrl
    // (ej. https://app-pasos.onrender.com/api -> https://app-pasos.onrender.com)
    final baseUrl = ApiConfig.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');

    final completer = Completer<void>();

    final optionBuilder = io_client.OptionBuilder()
        .setTransports(['websocket'])
        .setReconnectionAttempts(10)
        .setReconnectionDelay(1000)
        .disableAutoConnect()
        .setQuery({
          'roomCode': roomCode,
          'isRunner': isRunner.toString(),
          if (isGuest) 'guest': 'true',
          if (isGuest) 'guestName': guestName,
        });

    if (!isGuest && token != null) {
      optionBuilder.setAuth({'token': token});
    }

    _socket = io_client.io(baseUrl, optionBuilder.build());

    _socket!.onConnect((_) {
      _isConnected = true;
      if (!completer.isCompleted) completer.complete();
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
      if (!completer.isCompleted) {
        completer.completeError(Exception('Error de conexión: $err'));
      }
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

    try {
      await completer.future.timeout(const Duration(seconds: 20));
    } catch (e) {
      _isConnected = false;
      rethrow;
    }
  }

  void sendLocation(Map<String, dynamic> data) {
    if (!_isConnected || _socket == null) return;
    _socket!.emit('locationUpdate', data);
  }

  bool sendChatMessage(String message) {
    if (!_isConnected || _socket == null) return false;
    _socket!.emit('chatMessage', {'message': message});
    return true;
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

  Future<void> reconnect() async {
    final roomCode = _roomCode;
    if (roomCode == null || _isConnected) return;
    await connect(
      roomCode: roomCode,
      isRunner: _isRunner,
      guestName: _guestName,
    );
  }
}
