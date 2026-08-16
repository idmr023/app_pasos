import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api.dart';
import '../models/user.dart';
import '../services/tts_service.dart';

enum TrackingRole { runner, spectator }

class TrackingProvider extends ChangeNotifier {
  final WebSocketService _wsService = WebSocketService();
  final LocationService _locationService = LocationService();
  final TtsService _ttsService = TtsService();

  TrackingRole? _role;
  String? _roomCode;
  bool _isConnected = false;
  bool _isTracking = false;
  Map<String, dynamic>? _currentRunnerLocation;
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _locations = [];

  TrackingRole? get role => _role;
  String? get roomCode => _roomCode;
  bool get isConnected => _isConnected;
  bool get isTracking => _isTracking;
  Map<String, dynamic>? get currentRunnerLocation => _currentRunnerLocation;
  List<Map<String, dynamic>> get messages => _messages;
  List<Map<String, dynamic>> get locations => _locations;

  Future<void> init() async {
    await _ttsService.init();
    await _locationService.init();
  }

  Future<void> startAsRunner(String roomCode) async {
    _role = TrackingRole.runner;
    _roomCode = roomCode;
    _isTracking = true;

    // Connect WebSocket as runner
    await _wsService.connect(roomCode, isRunner: true);

    // Subscribe to WebSocket messages
    _wsService.messages.listen(_handleWebSocketMessage);

    // Start location service
    await _locationService.startTracking(
      roomCode: roomCode,
      wsChannel: _wsService._channel!,
    );

    notifyListeners();
  }

  Future<void> joinAsSpectator(String roomCode) async {
    _role = TrackingRole.spectator;
    _roomCode = roomCode;
    _isTracking = false;

    // Connect WebSocket as spectator
    await _wsService.connect(roomCode, isRunner: false);

    // Subscribe to WebSocket messages
    _wsService.messages.listen(_handleWebSocketMessage);

    notifyListeners();
  }

  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = json.decode(message);

      switch (data['type']) {
        case 'connected':
          // Already connected
          break;

        case 'locationUpdate':
          final locData = data['data'];
          _currentRunnerLocation = {
            'latitude': locData['latitude'],
            'longitude': locData['longitude'],
            'speed': locData['speed'],
            'pace': locData['pace'],
            'accuracy': locData['accuracy'],
          };
          _locations.add({
            'latitude': locData['latitude'],
            'longitude': locData['longitude'],
            'timestamp': locData['timestamp'],
          });
          // Keep only last 200 points
          if (_locations.length > 200) {
            _locations.removeAt(0);
          }
          notifyListeners();
          break;

        case 'chatMessage':
          final msg = data;
          _messages.add({
            'message': msg['message'],
            'senderName': msg['senderName'],
            'senderId': msg['senderId'],
            'timestamp': msg['timestamp'],
            'isMe': false,
          });
          // Keep only last 50 messages
          if (_messages.length > 50) {
            _messages.removeAt(0);
          }
          // Trigger TTS for support messages
          _triggerTtsIfNeeded(msg);
          notifyListeners();
          break;

        case 'trackingStopped':
          _isTracking = false;
          _role = null;
          _roomCode = null;
          _wsService.disconnect();
          notifyListeners();
          break;

        case 'error':
          print('WebSocket Error: ${data['message']}');
          break;
      }
    } catch (e) {
      print('Error handling WebSocket message: $e');
    }
  }

  void _triggerTtsIfNeeded(dynamic msg) {
    // If message is a quick reaction emoji, we can read it
    final message = msg['message'];
    if (message == '🔥' || message == '💪' || message == '⚡' || message == '👏') {
      final senderName = msg['senderName'] ?? 'Alguien';
      _ttsService.speakSupportMessage(senderName, message);
    }
  }

  void sendMessage(String message) {
    _wsService.sendChatMessage(message);
  }

  void stopTracking() {
    _isTracking = false;
    _role = null;
    _roomCode = null;
    _wsService.disconnect();
    _locationService.stopTracking();
    notifyListeners();
  }

  void leaveRoom() {
    stopTracking();
    _locations.clear();
    _messages.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _wsService.disconnect();
    _locationService.stopTracking();
    super.dispose();
  }
}