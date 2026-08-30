import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/websocket_service.dart';
import '../services/location_service.dart';
import '../services/tts_service.dart';

enum TrackingRole { runner, spectator }

class TrackingProvider extends ChangeNotifier {
  final WebSocketService _wsService = WebSocketService();
  final LocationService _locationService = LocationService();
  final TtsService _ttsService = TtsService();

  StreamSubscription<Map<String, dynamic>>? _socketSubscription;
  StreamSubscription<Position>? _positionSubscription;

  // --- Estado de Conexión y Roles ---
  TrackingRole? _role;
  String? _roomCode;
  bool _isConnected = false;
  bool _isTracking = false;
  bool _isRunner = false;
  String? _error;
  bool _trackingStopped = false;

  // --- Datos de Ubicación y Progreso ---
  double _goalDistance = 5.0;
  double _currentDistance = 0.0; // km acumulados
  Map<String, dynamic>? _currentRunnerLocation;

  // --- Historial ---
  List<Map<String, dynamic>> _messages = [];
  final List<Map<String, dynamic>> _locations = [];

  // --- Getters ---
  TrackingRole? get role => _role;
  String? get roomCode => _roomCode;
  bool get isConnected => _isConnected;
  bool get isTracking => _isTracking;
  bool get isRunner => _isRunner;
  String? get error => _error;
  bool get trackingStopped => _trackingStopped;
  double get goalDistance => _goalDistance;
  double get currentDistance => _currentDistance;
  Map<String, dynamic>? get currentRunnerLocation => _currentRunnerLocation;
  List<Map<String, dynamic>> get messages => _messages;
  List<Map<String, dynamic>> get locations => _locations;

  // --- Init ---
  Future<void> init() async {
    await _ttsService.init();
    await _locationService.init();
  }

  // --- Runner ---
  Future<void> startAsRunner(
    String roomCode,
    double goal,
    bool isRunner,
  ) async {
    _role = TrackingRole.runner;
    _roomCode = roomCode;
    _isRunner = isRunner;
    _isTracking = true;
    _goalDistance = goal;
    _currentDistance = 0;
    _error = null;
    _trackingStopped = false;
    _messages = [];
    _locations.clear();

    _positionSubscription?.cancel();
    _positionSubscription = null;
    _lastPosition = null;
    _locationService.stopTracking();

    try {
      // Inicializar TTS de forma best-effort: un fallo del motor de voz
      // (dispositivo sin TTS, etc.) no debe impedir que el tracking arranque.
      try {
        await _ttsService.init();
      } catch (ttsError) {
        debugPrint('[Tracking] TTS no disponible: $ttsError');
      }

      // Conectar socket como corredor
      await _wsService.connect(roomCode: roomCode, isRunner: true);
      _isConnected = true;
      _listenToSocket();

      // Iniciar GPS y reenviar posiciones por socket
      _positionSubscription = _locationService.startTracking().listen(
        _sendPositionAsRunner,
        onError: (e) {
          _error = 'Error de GPS: $e';
          notifyListeners();
        },
      );

      notifyListeners();
    } catch (e) {
      _error = '$e';
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  Position? _lastPosition;

  void _sendPositionAsRunner(Position position) {
    // Distancia acumulada en km
    if (_lastPosition != null) {
      final deltaMeters = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      // Ignorar saltos de ruido GPS menores al filtro
      if (deltaMeters >= 3) {
        _currentDistance += deltaMeters / 1000.0;
      }
    }
    _lastPosition = position;

    // Pace (min/km) desde speed (m/s): pace = 60 / (speed * 3.6)
    double pace = 0;
    if (position.speed > 0.5) {
      pace = 60 / (position.speed * 3.6);
    }

    final data = {
      'roomCode': _roomCode,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'speed': position.speed,
      'pace': double.parse(pace.toStringAsFixed(2)),
      'heading': position.heading,
      'accuracy': position.accuracy,
      'altitude': position.altitude,
      'distance': double.parse(_currentDistance.toStringAsFixed(3)),
      'timestamp': position.timestamp.millisecondsSinceEpoch,
    };

    _currentRunnerLocation = data;
    _locations.add({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': data['timestamp'],
    });
    if (_locations.length > 500) _locations.removeAt(0);

    _wsService.sendLocation(data);
    notifyListeners();
  }

  // --- Spectator ---
  Future<void> joinAsSpectator(String roomCode) async {
    _role = TrackingRole.spectator;
    _roomCode = roomCode;
    _isRunner = false;
    _isTracking = false;
    _error = null;
    _trackingStopped = false;
    _currentRunnerLocation = null;
    _messages = [];
    _locations.clear();

    // Cancelar cualquier rastreo GPS previo (p.ej. el del corredor)
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _lastPosition = null;
    _locationService.stopTracking();

    try {
      await _wsService.connect(roomCode: roomCode, isRunner: false);
      _isConnected = true;
      _listenToSocket();
      notifyListeners();
    } catch (e) {
      _error = '$e';
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  // --- Socket events ---
  void _listenToSocket() {
    _socketSubscription?.cancel();
    _socketSubscription = _wsService.events.listen(_handleSocketEvent);
  }

  void _handleSocketEvent(Map<String, dynamic> event) {
    final type = event['type'];
    final data = event['data'];

    switch (type) {
      case 'connected':
        _isConnected = true;
        if (data is Map && data['roomCode'] != null) {
          _roomCode = data['roomCode'];
        }
        notifyListeners();
        break;

      case 'locationUpdate':
        if (data is Map) {
          _currentRunnerLocation = {
            'latitude': data['latitude'],
            'longitude': data['longitude'],
            'speed': data['speed'],
            'pace': data['pace'],
            'accuracy': data['accuracy'],
            'heading': data['heading'],
            'distance': data['distance'],
          };
          if (data['distance'] is num) {
            _currentDistance = (data['distance'] as num).toDouble();
          }
          _locations.add({
            'latitude': data['latitude'],
            'longitude': data['longitude'],
            'timestamp': data['timestamp'],
          });
          if (_locations.length > 500) _locations.removeAt(0);
          notifyListeners();
        }
        break;

      case 'chatMessage':
        if (data is Map) {
          _messages.add({
            'message': data['message'],
            'senderName': data['senderName'],
            'senderAvatar': data['senderAvatar'],
            'senderId': data['senderId'],
            'senderType': data['senderType'],
            'timestamp': data['timestamp'],
          });
          if (_messages.length > 50) _messages.removeAt(0);
          _triggerTtsIfNeeded(data);
          notifyListeners();
        }
        break;

      case 'trackingStopped':
        _isTracking = false;
        _trackingStopped = true;
        notifyListeners();
        break;

      case 'error':
        _error = data is Map ? '${data['message']}' : '$data';
        notifyListeners();
        break;
    }
  }

  void _triggerTtsIfNeeded(Map<dynamic, dynamic> msg) {
    // El corredor escucha los mensajes de ánimo de los espectadores
    if (_role != TrackingRole.runner) return;
    final message = msg['message'];
    if (message == '🔥' ||
        message == '💪' ||
        message == '⚡' ||
        message == '👏') {
      final senderName = msg['senderName'] ?? 'Alguien';
      _ttsService.speakSupportMessage(senderName, message).catchError((e) {
        debugPrint('[Tracking] TTS error: $e');
      });
    }
  }

  // --- Acciones ---
  void sendMessage(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    _wsService.sendChatMessage(trimmed);
  }

  void stopTracking() {
    if (_role == TrackingRole.runner) {
      _wsService.sendStopTracking();
    }
    _isTracking = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _lastPosition = null;
    _locationService.stopTracking();
    notifyListeners();
  }

  void leaveRoom() {
    stopTracking();
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _wsService.disconnect();
    _isConnected = false;
    _role = null;
    _roomCode = null;
    _isRunner = false;
    _trackingStopped = false;
    _currentRunnerLocation = null;
    _messages = [];
    _locations.clear();
    _currentDistance = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _positionSubscription?.cancel();
    _wsService.disconnect();
    _locationService.stopTracking();
    super.dispose();
  }
}
