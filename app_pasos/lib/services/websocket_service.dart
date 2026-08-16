import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;
  final _storage = const FlutterSecureStorage();

  bool get isConnected => _isConnected;

  Future<void> connect({required String roomCode, bool isRunner = false}) async {
    if (_isConnected) {
      _channel?.sink.close();
    }

    final token = await _storage.read(key: 'jwt_token');
    if (token == null) {
      throw Exception('No hay token de autenticación');
    }

    // Build WebSocket URL with query params
    final wsUrl = 'ws://10.0.2.2:3000/socket?roomCode=$roomCode&isRunner=$isRunner';

    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    _isConnected = true;

    // Send authentication message
    _channel!.sink.add(json.encode({
      'type': 'authenticate',
      'token': token,
      'roomCode': roomCode,
      'isRunner': isRunner,
    }));

    // Listen for messages
    _channel!.stream.listen(_onMessage, onError: _onError, onDone: _onDone);
  }

  void _onMessage(dynamic message) {
    // Return raw message to listener
    // The TrackingProvider will handle parsing
  }

  void sendChatMessage(String message) {
    if (_channel == null || !_isConnected) return;
    _channel!.sink.add(json.encode({
      'type': 'chatMessage',
      'message': message,
    }));
  }

  void sendStopTracking() {
    if (_channel == null || !_isConnected) return;
    _channel!.sink.add(json.encode({
      'type': 'stopTracking',
    }));
  }

  Stream<dynamic> get messages => _channel!.stream;

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }

  void _onError(Object error) {
    print('WebSocket Error: $error');
    _isConnected = false;
  }

  void _onDone() {
    _isConnected = false;
    _channel = null;
  }
}