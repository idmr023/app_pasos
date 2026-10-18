import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../config/api.dart';
import '../services/websocket_service.dart';
import '../services/location_service.dart';
import '../services/tts_service.dart';

enum TrackingRole { runner, spectator }

class TrackingProvider extends ChangeNotifier with WidgetsBindingObserver {
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

  // --- Datos de Ubicación, Progreso y Cronómetro ---
  double _goalDistance = 5.0;
  double _currentDistance = 0.0; // km acumulados
  Map<String, dynamic>? _currentRunnerLocation;
  DateTime? _startTime;
  Duration _elapsedTime = Duration.zero;
  Timer? _timer;

  // --- Historial ---
  List<Map<String, dynamic>> _messages = [];
  final List<Map<String, dynamic>> _locations = [];

  // --- Stats finales (emitidas por el backend al detener el tracking) ---
  Map<String, dynamic>? _finalStats;
  bool _resuming = false;

  TrackingProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

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
  Duration get elapsedTime => _elapsedTime;
  Map<String, dynamic>? get currentRunnerLocation => _currentRunnerLocation;
  List<Map<String, dynamic>> get messages => _messages;
  List<Map<String, dynamic>> get locations => _locations;
  Map<String, dynamic>? get finalStats => _finalStats;

  /// Puntos del recorrido como LatLng para la polyline del mapa.
  List<LatLng> get routePoints {
    return _locations
        .where((p) => p['latitude'] is num && p['longitude'] is num)
        .map(
          (p) => LatLng(
            (p['latitude'] as num).toDouble(),
            (p['longitude'] as num).toDouble(),
          ),
        )
        .toList();
  }

  // --- Init ---
  Future<void> init() async {
    await _ttsService.init();
    await _locationService.init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _roomCode != null &&
        !_trackingStopped) {
      _reconnectAfterResume();
    }
  }

  Future<void> _reconnectAfterResume() async {
    if (_resuming) return;
    _resuming = true;
    try {
      if (!_wsService.isConnected) {
        await _wsService.reconnect();
      }
      _isConnected = true;
      if (_role == TrackingRole.runner && _isRunner && _isTracking) {
        await _locationService.restartTracking();
        _positionSubscription?.cancel();
        _lastPosition = null;
        _lastAcceptedPositionTime = null;
        _positionSubscription = _locationService.startTracking().listen(
          _sendPositionAsRunner,
          onError: (e) {
            _error = 'Error de GPS: $e';
            notifyListeners();
          },
        );
      }
      final reloadTasks = <Future<void>>[_loadMessageHistory()];
      if (_role == TrackingRole.spectator) {
        reloadTasks.add(_loadRouteHistory());
      }
      await Future.wait(reloadTasks);
      _error = null;
      notifyListeners();
    } catch (e) {
      _isConnected = false;
      _error =
          'No se pudo reconectar al tracking. Revisa tu conexión e inténtalo de nuevo.';
      debugPrint('[Tracking] Error reconectando al volver a la app: $e');
      notifyListeners();
    } finally {
      _resuming = false;
    }
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
    _startTime = DateTime.now();
    _elapsedTime = Duration.zero;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isTracking && _startTime != null) {
        _elapsedTime = DateTime.now().difference(_startTime!);
        notifyListeners();
      }
    });
    _error = null;
    _trackingStopped = false;
    _messages = [];
    _locations.clear();
    _finalStats = null;

    _positionSubscription?.cancel();
    _positionSubscription = null;
    _lastPosition = null;
    _lastAcceptedPositionTime = null;
    _locationService.stopTracking();

    try {
      // Inicializar TTS de forma best-effort: un fallo del motor de voz
      // (dispositivo sin TTS, etc.) no debe impedir que el tracking arranque.
      try {
        await _ttsService.init();
      } catch (ttsError) {
        debugPrint('[Tracking] TTS no disponible: $ttsError');
      }

      // Suscribirse a eventos ANTES de conectar para no perder el evento
      // 'connected' emitido por el backend al unirse a la sala.
      _listenToSocket();

      // Conectar socket como corredor (espera la conexión real)
      await _wsService.connect(roomCode: roomCode, isRunner: true);
      _isConnected = true;

      // Iniciar GPS y reenviar posiciones por socket
      _positionSubscription = _locationService.startTracking().listen(
        _sendPositionAsRunner,
        onError: (e) {
          _error = 'Error de GPS: $e';
          notifyListeners();
        },
      );

      // Mantener la pantalla activa mientras se graba: si el corredor pone
      // el celular en el bolsillo, Android pausaría el stream GPS y los km
      // dejarían de contar. Best-effort: un fallo del wakelock no detiene
      // el tracking.
      try {
        await WakelockPlus.enable();
      } catch (e) {
        debugPrint('[Tracking] Wakelock no disponible: $e');
      }

      notifyListeners();
    } catch (e) {
      _error = '$e';
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  Position? _lastPosition;
  DateTime? _lastAcceptedPositionTime;

  void _sendPositionAsRunner(Position position) {
    final positionAge = DateTime.now().difference(position.timestamp);
    if (positionAge > const Duration(seconds: 30) ||
        position.timestamp.isBefore(
          _lastAcceptedPositionTime ?? DateTime(2000),
        ) ||
        !position.accuracy.isFinite ||
        position.accuracy <= 0 ||
        position.accuracy > 25) {
      return;
    }

    // Distancia acumulada en km
    if (_lastPosition != null) {
      final deltaMeters = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      final elapsedSeconds =
          position.timestamp.difference(_lastPosition!.timestamp).inSeconds;
      final speedMetersPerSecond =
          position.speed.isFinite && position.speed > 0 ? position.speed : 0;
      final maxPlausibleDelta = [
        40.0,
        speedMetersPerSecond * elapsedSeconds +
            position.accuracy +
            _lastPosition!.accuracy,
      ].reduce((a, b) => a > b ? a : b);

      if (deltaMeters >= 3.0 && deltaMeters <= maxPlausibleDelta) {
        _currentDistance += deltaMeters / 1000.0;
      }
    }
    _lastPosition = position;
    _lastAcceptedPositionTime = position.timestamp;

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
    _finalStats = null;

    // Cancelar cualquier rastreo GPS previo (p.ej. el del corredor)
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _lastPosition = null;
    _locationService.stopTracking();

    try {
      _listenToSocket();
      await _wsService.connect(roomCode: roomCode, isRunner: false);
      _isConnected = true;
      notifyListeners();
      // Cargar el recorrido ya registrado para que el espectador que se
      // une tarde vea el mapa completo (best-effort).
      _loadRouteHistory();
      _loadMessageHistory();
      // Si la carrera finalizó en la ventana entre validación y socket,
      // marcarla como completada en lugar de esperar eternamente.
      _checkSessionStatus();
    } catch (e) {
      _error = '$e';
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Espectador invitado (sin cuenta): se une con un nombre y ve el recorrido
  /// en vivo + chat. No requiere token.
  Future<void> joinAsGuest(
    String roomCode, {
    String guestName = 'Invitado',
  }) async {
    _role = TrackingRole.spectator;
    _roomCode = roomCode;
    _isRunner = false;
    _isTracking = false;
    _error = null;
    _trackingStopped = false;
    _currentRunnerLocation = null;
    _messages = [];
    _locations.clear();
    _finalStats = null;

    _positionSubscription?.cancel();
    _positionSubscription = null;
    _lastPosition = null;
    _locationService.stopTracking();

    try {
      _listenToSocket();
      await _wsService.connect(
        roomCode: roomCode,
        isRunner: false,
        guestName: guestName,
      );
      _isConnected = true;
      notifyListeners();
      _loadRouteHistory();
      _loadMessageHistory();
      _checkSessionStatus();
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

  /// Best-effort: carga los puntos ya registrados en el servidor para que
  /// un espectador que se une tarde vea el recorrido completo en el mapa.
  Future<void> _loadRouteHistory() async {
    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'auth_token');
      if (_roomCode == null) return;

      final headers = <String, String>{};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final response = await http
          .get(
            // recent=true: los puntos más recientes, para que un espectador
            // que se une tarde vea el tramo actual y no solo el inicio.
            Uri.parse(
              '${ApiConfig.baseUrl}/tracking/$_roomCode/history?recent=true&limit=1000',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return;
      final data = json.decode(response.body);
      final locations = data['locations'];
      if (locations is! List) return;

      _locations.clear();
      for (final loc in locations) {
        if (loc is Map && loc['latitude'] is num && loc['longitude'] is num) {
          _locations.add({
            'latitude': loc['latitude'],
            'longitude': loc['longitude'],
            'distance': loc['distance'],
            'speed': loc['speed'],
            'pace': loc['pace'],
            'timestamp': loc['timestamp'],
          });
        }
      }
      // La distancia acumulada más reciente del historial
      final lastWithDistance = locations.lastWhere(
        (l) => l is Map && l['distance'] is num && (l['distance'] as num) > 0,
        orElse: () => null,
      );
      if (lastWithDistance is Map && lastWithDistance['distance'] is num) {
        _currentDistance = (lastWithDistance['distance'] as num).toDouble();
      }
      // Setear la ubicación "actual" con el último punto para que el overlay
      // muestre datos reales en vez de "Esperando datos del corredor...".
      if (_locations.isNotEmpty) {
        final last = _locations.last;
        _currentRunnerLocation = {
          'latitude': last['latitude'],
          'longitude': last['longitude'],
          'speed': last['speed'],
          'pace': last['pace'],
          'distance': last['distance'],
        };
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[Tracking] No se pudo cargar historial: $e');
    }
  }

  /// Verifica el estado de la sesión tras unirse como espectador.
  /// Si la carrera ya finalizó (ventana de carrera entre la validación del
  /// hub y la conexión del socket), muestra el banner de finalizada en
  /// lugar de esperar posiciones que ya no llegarán.
  Future<void> _checkSessionStatus() async {
    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'auth_token');
      if (_roomCode == null) return;

      final headers = <String, String>{};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/tracking/$_roomCode'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return;
      final data = json.decode(response.body);
      final session = data['session'];
      if (session is Map && session['status'] != null) {
        if (session['status'] != 'active') {
          _trackingStopped = true;
          _finalStats = {
            'totalDistance': session['totalDistance'],
            'avgSpeed': session['avgSpeed'],
            'maxSpeed': session['maxSpeed'],
            'avgPace': session['avgPace'],
            'pointCount': session['pointCount'],
          };
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[Tracking] No se pudo verificar estado de sesión: $e');
    }
  }

  Future<void> _loadMessageHistory() async {
    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'auth_token');
      if (_roomCode == null) return;

      final headers = <String, String>{};
      if (token != null) headers['Authorization'] = 'Bearer $token';
      final response = await http
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}/tracking/$_roomCode/messages?limit=100',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return;
      final data = json.decode(response.body);
      final messages = data['messages'];
      if (messages is! List) return;

      _messages =
          messages
              .whereType<Map>()
              .map(
                (message) => {
                  'message': message['message'],
                  'senderName':
                      message['senderName'] ??
                      (message['sender'] is Map
                          ? message['sender']['displayName']
                          : 'Alguien'),
                  'senderAvatar':
                      message['senderAvatar'] ??
                      (message['sender'] is Map
                          ? message['sender']['avatar']
                          : null),
                  'senderId':
                      message['senderId'] ??
                      (message['sender'] is Map
                          ? message['sender']['_id']
                          : null),
                  'senderType': message['senderType'],
                  'timestamp': message['timestamp'],
                },
              )
              .toList();
      if (_messages.length > 50) {
        _messages = _messages.sublist(_messages.length - 50);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[Tracking] No se pudo cargar historial de chat: $e');
    }
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
        if (data is Map) {
          _finalStats = {
            'totalDistance': data['totalDistance'],
            'avgSpeed': data['avgSpeed'],
            'maxSpeed': data['maxSpeed'],
            'avgPace': data['avgPace'],
            'pointCount': data['pointCount'],
          };
        }
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
  Future<void> sendMessage(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    if (!_wsService.isConnected) {
      await _reconnectAfterResume();
    }
    if (!_wsService.sendChatMessage(trimmed)) {
      _error =
          'El chat no está conectado. Espera un momento y vuelve a intentarlo.';
      notifyListeners();
    }
  }

  void stopTracking() {
    _isTracking = false;
    _timer?.cancel();
    _timer = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _lastPosition = null;
    _locationService.stopTracking();
    WakelockPlus.disable().catchError((Object e) {
      debugPrint('[Tracking] Error liberando wakelock: $e');
      return null;
    });
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
    _finalStats = null;
    _currentRunnerLocation = null;
    _messages = [];
    _locations.clear();
    _currentDistance = 0;
    _startTime = null;
    _elapsedTime = Duration.zero;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _socketSubscription?.cancel();
    _positionSubscription?.cancel();
    _timer?.cancel();
    _wsService.disconnect();
    _locationService.stopTracking();
    WakelockPlus.disable().catchError((Object e) {
      debugPrint('[Tracking] Error liberando wakelock: $e');
      return null;
    });
    super.dispose();
  }
}
