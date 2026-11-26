import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../config/api.dart';
import '../models/power_up.dart';
import '../services/websocket_service.dart';
import '../services/location_service.dart';
import '../services/tts_service.dart';
import '../utils/distance_accumulator.dart';
import '../utils/gpx.dart';

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
  // Avisos transitorios (mensaje rechazado, reconexión, GPS...). Antes se
  // guardaban en _error y las pantallas reemplazaban mapa+chat por una
  // pantalla de error sin salida: el chat "dejaba de funcionar" al primer
  // aviso del servidor. Ahora se muestran como SnackBar y se descartan.
  String? _notice;
  bool _socketConnectedOnce = false;
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

  // --- Ánimo en vivo (power-ups de espectadores) ---
  // Stream de power-ups recibidos, para animaciones (overlay del corredor).
  final StreamController<Map<String, dynamic>> _powerUpController =
      StreamController<Map<String, dynamic>>.broadcast();
  int _cheersTotal = 0;
  int _cheersSupporters = 0;
  Map<String, dynamic>? _topSupporter; // {name, count}
  DateTime? _powerUpCooldownUntil;

  // --- Robustez GPS / red (carreras largas con mala señal) ---
  final DistanceAccumulator _distanceAcc = DistanceAccumulator();
  DateTime? _lastFixAt; // último fix GPS recibido (cualquier precisión)
  Timer? _gpsWatchdog;
  bool _gpsStale = false;
  int _pendingLocations = 0;

  // --- Ruta planificada (GPX) ---
  GpxRoute? _plannedRoute;
  RouteProgress? _routeProgress;
  DateTime? _sessionStartedAt;
  DateTime? _lastPointAt;

  TrackingProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Sin fix GPS hace > 45 s (el tiempo sigue corriendo; los km se
  /// recuperan en línea recta cuando vuelve la señal).
  bool get gpsStale => _gpsStale;

  /// Puntos guardados sin conexión que aún no llegaron al servidor.
  int get pendingLocations => _pendingLocations;

  GpxRoute? get plannedRoute => _plannedRoute;
  RouteProgress? get routeProgress => _routeProgress;

  /// Puntos de la ruta planificada para dibujarla en el mapa.
  List<LatLng> get plannedRoutePoints =>
      _plannedRoute?.points.map((p) => LatLng(p.lat, p.lng)).toList() ?? const [];

  /// Tiempo estimado restante según el ritmo medio hasta ahora.
  Duration? get estimatedRemaining {
    final progress = _routeProgress;
    if (progress == null || _currentDistance <= 0.2) return null;
    Duration? elapsed;
    if (_role == TrackingRole.runner) {
      elapsed = _elapsedTime;
    } else if (_sessionStartedAt != null) {
      elapsed = (_lastPointAt ?? DateTime.now()).difference(_sessionStartedAt!);
    }
    if (elapsed == null || elapsed.inSeconds <= 0) return null;
    final secPerKm = elapsed.inSeconds / _currentDistance;
    return Duration(seconds: (secPerKm * progress.remainingMeters / 1000).round());
  }

  void _updateRouteProgress(double lat, double lng) {
    final route = _plannedRoute;
    if (route == null) return;
    _routeProgress = progressOnRoute(
      route,
      lat,
      lng,
      // Sin progreso previo se usa la distancia recorrida como pista, para
      // que en rutas ida y vuelta no caiga en el tramo equivocado.
      previousAlong: _routeProgress?.alongMeters ??
          (_currentDistance > 0.5 ? _currentDistance * 1000 - 300 : null),
    );
  }

  /// Agrega un punto al recorrido del mapa (solo si se movió ≥ 8 m, para que
  /// 35 km quepan sin truncar el inicio).
  void _appendLocation(Map<String, dynamic> point) {
    final lat = point['latitude'];
    final lng = point['longitude'];
    if (lat is! num || lng is! num) return;
    if (_locations.isNotEmpty) {
      final last = _locations.last;
      final d = haversineMeters(
        (last['latitude'] as num).toDouble(),
        (last['longitude'] as num).toDouble(),
        lat.toDouble(),
        lng.toDouble(),
      );
      if (d < 8) return;
    }
    _locations.add(point);
    if (_locations.length > 6000) {
      // Adelgaza la mitad más antigua en vez de borrar el inicio de la ruta.
      final half = _locations.length ~/ 2;
      final thinned = [for (var i = 0; i < half; i += 2) _locations[i]];
      _locations.replaceRange(0, half, thinned);
    }
  }

  /// Sube la ruta GPX planificada a la sala (el corredor). Los espectadores
  /// la reciben en vivo por `routeUpdated`.
  Future<String?> uploadPlannedRoute(GpxRoute route) async {
    final code = _roomCode;
    if (code == null) return 'No hay sala activa';
    final simplified = route.simplified(3000);
    _plannedRoute = simplified;
    _routeProgress = null;
    final loc = _currentRunnerLocation;
    if (loc != null && loc['latitude'] is num && loc['longitude'] is num) {
      _updateRouteProgress((loc['latitude'] as num).toDouble(), (loc['longitude'] as num).toDouble());
    }
    notifyListeners();
    try {
      final token = await const FlutterSecureStorage().read(key: 'auth_token');
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/tracking/$code/route'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: json.encode(simplified.toJson()),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        String msg = 'No se pudo subir la ruta (${response.statusCode})';
        try {
          msg = (json.decode(response.body)['error'] ?? msg).toString();
        } catch (_) {}
        return msg;
      }
      return null;
    } catch (e) {
      // La ruta queda local para el corredor; se puede reintentar.
      return 'Sin conexión: la ruta se ve en tu celular pero no se envió a los espectadores. Reintenta luego.';
    }
  }

  void _applyPlannedRouteJson(dynamic raw) {
    if (raw is! Map) {
      _plannedRoute = null;
      _routeProgress = null;
      return;
    }
    final route = GpxRoute.fromJson(Map<String, dynamic>.from(raw));
    if (route.points.length < 2) return;
    _plannedRoute = route;
    _routeProgress = null;
    final loc = _currentRunnerLocation;
    if (loc != null && loc['latitude'] is num && loc['longitude'] is num) {
      _updateRouteProgress((loc['latitude'] as num).toDouble(), (loc['longitude'] as num).toDouble());
    }
  }

  /// Antes de cerrar la carrera: entrega los puntos guardados sin señal.
  Future<bool> flushPendingLocations() async {
    final ok = await _wsService.flushPendingLocations();
    _pendingLocations = _wsService.pendingLocations;
    return ok;
  }

  void _startGpsWatchdog() {
    _gpsWatchdog?.cancel();
    _gpsWatchdog = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_isTracking || _role != TrackingRole.runner) return;
      final last = _lastFixAt;
      final stale = last == null
          ? (_startTime != null && DateTime.now().difference(_startTime!) > const Duration(seconds: 45))
          : DateTime.now().difference(last) > const Duration(seconds: 45);
      if (stale != _gpsStale) {
        _gpsStale = stale;
        notifyListeners();
      }
      // Si el stream de GPS murió (servicio de ubicación apagado y vuelto a
      // encender, el SO lo cortó…), se reinicia sin perder la distancia.
      if (stale && last != null && DateTime.now().difference(last) > const Duration(seconds: 90)) {
        _restartGpsStream();
        _lastFixAt = DateTime.now(); // espera otros 90 s antes de reintentar
      }
    });
  }

  Future<void> _restartGpsStream() async {
    debugPrint('[Tracking] Reiniciando stream GPS (sin fixes)');
    await _locationService.stopTracking();
    await _positionSubscription?.cancel();
    _positionSubscription = _locationService.startTracking().listen(
      _sendPositionAsRunner,
      onError: (e) => _setNotice('Error de GPS: $e'),
    );
  }

  // --- Getters ---
  TrackingRole? get role => _role;
  String? get roomCode => _roomCode;
  bool get isConnected => _isConnected;
  bool get isTracking => _isTracking;
  bool get isRunner => _isRunner;
  String? get notice => _notice;

  /// Consume el aviso actual (la UI lo muestra una sola vez).
  String? takeNotice() {
    final n = _notice;
    _notice = null;
    return n;
  }

  void _setNotice(String message) {
    _notice = message;
    notifyListeners();
  }
  String? get error => _error;
  bool get trackingStopped => _trackingStopped;
  double get goalDistance => _goalDistance;
  double get currentDistance => _currentDistance;
  Duration get elapsedTime => _elapsedTime;
  Map<String, dynamic>? get currentRunnerLocation => _currentRunnerLocation;
  List<Map<String, dynamic>> get messages => _messages;
  List<Map<String, dynamic>> get locations => _locations;
  Map<String, dynamic>? get finalStats => _finalStats;

  /// Power-ups recibidos en vivo (cada evento: type, emoji, message,
  /// senderName, speech...). Lo escucha el overlay animado del corredor.
  Stream<Map<String, dynamic>> get powerUpEvents => _powerUpController.stream;

  /// "Energía del público": total de ánimos, nº de supporters y el top.
  int get cheersTotal => _cheersTotal;
  int get cheersSupporters => _cheersSupporters;
  Map<String, dynamic>? get topSupporter => _topSupporter;

  /// Hasta cuándo el espectador debe esperar para otro power-up (espejo
  /// local del rate limit del servidor, para el anillo de cooldown).
  DateTime? get powerUpCooldownUntil => _powerUpCooldownUntil;

  void _resetCheers() {
    _cheersTotal = 0;
    _cheersSupporters = 0;
    _topSupporter = null;
    _powerUpCooldownUntil = null;
  }

  /// Acepta tanto `stats` del evento en vivo ({total, supporters,
  /// topSupporter}) como el recap de /cheers ({total, supporters,
  /// topSupporters: [...]}).
  void _applyCheerStats(dynamic stats) {
    if (stats is! Map) return;
    if (stats['total'] is num) _cheersTotal = (stats['total'] as num).toInt();
    if (stats['supporters'] is num) {
      _cheersSupporters = (stats['supporters'] as num).toInt();
    }
    var top = stats['topSupporter'];
    final list = stats['topSupporters'];
    if (top == null && list is List && list.isNotEmpty) top = list.first;
    _topSupporter = top is Map ? Map<String, dynamic>.from(top) : null;
  }

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
      // El GPS corre en un foreground service y sigue con la pantalla
      // apagada: solo se reinicia si dejó de entregar fixes. Antes se
      // reiniciaba siempre y se descartaba el tramo entre el último punto y
      // el primero tras volver a la app.
      if (_role == TrackingRole.runner && _isRunner && _isTracking) {
        final last = _lastFixAt;
        if (last == null || DateTime.now().difference(last) > const Duration(seconds: 30)) {
          await _restartGpsStream();
        }
      }
      final reloadTasks = <Future<void>>[
        _loadMessageHistory(),
        _loadCheerStats(),
      ];
      if (_role == TrackingRole.spectator) {
        reloadTasks.add(_loadRouteHistory());
      }
      await Future.wait(reloadTasks);
      notifyListeners();
    } catch (e) {
      _isConnected = false;
      debugPrint('[Tracking] Error reconectando al volver a la app: $e');
      _setNotice(
        'No se pudo reconectar al tracking. Revisa tu conexión e inténtalo de nuevo.',
      );
    } finally {
      _resuming = false;
    }
  }

  // --- Runner ---
  Future<void> startAsRunner(
    String roomCode,
    double goal,
    bool isRunner, {
    GpxRoute? plannedRoute,
  }) async {
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
    _resetCheers();

    _positionSubscription?.cancel();
    _positionSubscription = null;
    _distanceAcc.reset();
    _lastFixAt = null;
    _lastAcceptedPositionTime = null;
    _gpsStale = false;
    _pendingLocations = 0;
    _plannedRoute = null;
    _routeProgress = null;
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
        onError: (e) => _setNotice('Error de GPS: $e'),
      );
      _startGpsWatchdog();

      if (plannedRoute != null) {
        uploadPlannedRoute(plannedRoute).then((err) {
          if (err != null) _setNotice(err);
        });
      }

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

  DateTime? _lastAcceptedPositionTime;

  void _sendPositionAsRunner(Position position) {
    _lastFixAt = DateTime.now();
    if (_gpsStale) {
      _gpsStale = false;
      notifyListeners();
    }
    final positionAge = DateTime.now().difference(position.timestamp);
    // Hasta 50 m de precisión se acepta para el mapa (en bolsillo/arena es
    // común 25–40 m); la distancia aplica su propio umbral más estricto.
    if (positionAge > const Duration(seconds: 30) ||
        !position.timestamp.isAfter(
          _lastAcceptedPositionTime ?? DateTime(2000),
        ) ||
        !position.accuracy.isFinite ||
        position.accuracy <= 0 ||
        position.accuracy > 50) {
      return;
    }
    _lastAcceptedPositionTime = position.timestamp;

    // Distancia robusta: ignora fixes imprecisos, puentea huecos sin señal
    // en línea recta y no suma el "baile" del GPS estando parado.
    _distanceAcc.add(
      lat: position.latitude,
      lng: position.longitude,
      accuracy: position.accuracy,
      timestamp: position.timestamp,
      speed: position.speed.isFinite ? position.speed : -1,
    );
    _currentDistance = _distanceAcc.km;
    _updateRouteProgress(position.latitude, position.longitude);

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
    _appendLocation({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': data['timestamp'],
    });

    _wsService.sendLocation(data);
    _pendingLocations = _wsService.pendingLocations;
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
    _resetCheers();

    // Cancelar cualquier rastreo GPS previo (p.ej. el del corredor)
    _positionSubscription?.cancel();
    _positionSubscription = null;
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
      _loadCheerStats();
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
    _resetCheers();

    _positionSubscription?.cancel();
    _positionSubscription = null;
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
      _loadCheerStats();
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
    _socketConnectedOnce = false;
    _notice = null;
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
            // full=true: todo el recorrido muestreado a ≤ 4000 puntos, para
            // que en carreras largas se vea desde la salida hasta el tramo
            // actual (antes solo los últimos 1000 puntos).
            Uri.parse(
              '${ApiConfig.baseUrl}/tracking/$_roomCode/history?full=true&limit=4000',
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
          _appendLocation({
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
        // Recalcular el progreso desde cero (sin ventana previa).
        _routeProgress = null;
        _onSpectatorPoint(last);
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
      if (session is Map) {
        _sessionStartedAt = DateTime.tryParse(session['startedAt']?.toString() ?? '');
        if (session['plannedRoute'] is Map) {
          _applyPlannedRouteJson(session['plannedRoute']);
          notifyListeners();
        }
      }
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
                  'kind': message['kind'] ?? 'chat',
                  'powerUpType': message['powerUpType'],
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

  /// Best-effort: estadísticas de ánimos ya recibidos (espectador que se une
  /// tarde o reconexión).
  Future<void> _loadCheerStats() async {
    try {
      final token = await const FlutterSecureStorage().read(key: 'auth_token');
      if (_roomCode == null) return;
      final headers = <String, String>{};
      if (token != null) headers['Authorization'] = 'Bearer $token';
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/tracking/$_roomCode/cheers'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return;
      final data = json.decode(response.body);
      _applyCheerStats(data['cheers']);
      notifyListeners();
    } catch (e) {
      debugPrint('[Tracking] No se pudo cargar ánimos: $e');
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
          _appendLocation({
            'latitude': data['latitude'],
            'longitude': data['longitude'],
            'timestamp': data['timestamp'],
          });
          _onSpectatorPoint(data);
          notifyListeners();
        }
        break;

      case 'locationBatch':
        // Puntos que el corredor guardó sin señal y envió al reconectar.
        if (data is Map && data['points'] is List) {
          final points = (data['points'] as List).whereType<Map>().toList();
          for (final p in points) {
            _appendLocation({
              'latitude': p['latitude'],
              'longitude': p['longitude'],
              'timestamp': p['timestamp'],
            });
          }
          if (points.isNotEmpty) {
            final last = points.last;
            _currentRunnerLocation = {
              'latitude': last['latitude'],
              'longitude': last['longitude'],
              'speed': last['speed'],
              'pace': last['pace'],
              'accuracy': last['accuracy'],
              'heading': last['heading'],
              'distance': last['distance'],
            };
            if (last['distance'] is num) {
              _currentDistance = (last['distance'] as num).toDouble();
            }
            _onSpectatorPoint(last);
          }
          notifyListeners();
        }
        break;

      case 'routeUpdated':
        if (_role == TrackingRole.spectator) {
          _applyPlannedRouteJson(data is Map ? data['route'] : null);
          notifyListeners();
        }
        break;

      case 'trackingResumed':
        // El servidor cerró la sala por desconexión larga y el corredor volvió.
        if (_role == TrackingRole.spectator && _trackingStopped) {
          _trackingStopped = false;
          _finalStats = null;
          _setNotice('El corredor recuperó la señal: la carrera continúa');
          _loadRouteHistory();
        }
        break;

      case 'pendingLocations':
        if (data is int) {
          _pendingLocations = data;
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

      case 'powerUp':
        if (data is Map) {
          final powerUp = Map<String, dynamic>.from(data);
          _messages.add({
            'message': powerUp['message'],
            'senderName': powerUp['senderName'],
            'senderId': powerUp['senderId'],
            'senderType': powerUp['senderType'],
            'timestamp': powerUp['timestamp'],
            'kind': 'powerUp',
            'powerUpType': powerUp['type'],
          });
          if (_messages.length > 50) _messages.removeAt(0);
          _applyCheerStats(powerUp['stats']);
          if (!_powerUpController.isClosed) _powerUpController.add(powerUp);
          // El corredor escucha cada ánimo en cola (no se cortan entre sí).
          if (_role == TrackingRole.runner && powerUp['speech'] is String) {
            _ttsService.enqueue(powerUp['speech'] as String);
          }
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
        if (data is Map &&
            data['code'] == 'POWERUP_COOLDOWN' &&
            data['retryInMs'] is num) {
          // Sincronizar el anillo de cooldown con el rate limit del servidor.
          _powerUpCooldownUntil = DateTime.now().add(
            Duration(milliseconds: (data['retryInMs'] as num).toInt()),
          );
        }
        _setNotice(data is Map ? '${data['message']}' : '$data');
        break;

      case 'connection':
        // Estado de la conexión Socket.IO (reconexión automática).
        final connected = data == true;
        final isReconnect = connected && _socketConnectedOnce;
        if (connected) _socketConnectedOnce = true;
        if (connected == _isConnected) break;
        _isConnected = connected;
        notifyListeners();
        if (isReconnect && _roomCode != null && !_trackingStopped) {
          // Recuperar mensajes/puntos perdidos mientras estaba desconectado.
          _loadMessageHistory();
          _loadCheerStats();
          if (_role == TrackingRole.spectator) _loadRouteHistory();
        }
        break;
    }
  }

  void _onSpectatorPoint(Map<dynamic, dynamic> p) {
    final ts = p['timestamp'];
    if (ts is num) {
      _lastPointAt = DateTime.fromMillisecondsSinceEpoch(ts.toInt());
    } else if (ts is String) {
      _lastPointAt = DateTime.tryParse(ts) ?? _lastPointAt;
    }
    final lat = p['latitude'];
    final lng = p['longitude'];
    if (lat is num && lng is num) _updateRouteProgress(lat.toDouble(), lng.toDouble());
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
    if (_trackingStopped) {
      _setNotice('El chat está cerrado porque la actividad ya finalizó.');
      return;
    }
    if (!_wsService.isConnected) {
      await _reconnectAfterResume();
    }
    if (!_wsService.sendChatMessage(trimmed)) {
      _setNotice(
        'El chat no está conectado. Espera un momento y vuelve a intentarlo.',
      );
    }
  }

  /// Manda un power-up al corredor (espectadores). Devuelve true si se envió.
  /// [text] solo para el ánimo de voz (máx. 80 caracteres).
  Future<bool> sendPowerUp(PowerUpType type, {String? text}) async {
    if (_role != TrackingRole.spectator) return false;
    if (_trackingStopped) {
      _setNotice('La actividad ya finalizó.');
      return false;
    }
    final until = _powerUpCooldownUntil;
    if (until != null && DateTime.now().isBefore(until)) {
      final secs =
          (until.difference(DateTime.now()).inMilliseconds / 1000).ceil();
      _setNotice('Espera $secs s para mandar otro ánimo');
      return false;
    }
    String? custom;
    if (type.id == PowerUpType.voz.id) {
      custom = (text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (custom.isEmpty) return false;
      if (custom.length > PowerUpType.maxCustomLength) {
        custom = custom.substring(0, PowerUpType.maxCustomLength);
      }
    }
    if (!_wsService.isConnected) {
      await _reconnectAfterResume();
    }
    if (!_wsService.sendPowerUp(type.id, text: custom)) {
      _setNotice('Sin conexión. Espera un momento y vuelve a intentarlo.');
      return false;
    }
    _powerUpCooldownUntil = DateTime.now().add(PowerUpType.cooldown);
    notifyListeners();
    return true;
  }

  void stopTracking() {
    _isTracking = false;
    _timer?.cancel();
    _timer = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _gpsWatchdog?.cancel();
    _gpsWatchdog = null;
    _gpsStale = false;
    _locationService.stopTracking();
    WakelockPlus.disable().catchError((Object e) {
      debugPrint('[Tracking] Error liberando wakelock: $e');
      return null;
    });
  }

  /// [notify] = false cuando se llama desde `dispose()` de una pantalla:
  /// notificar con el árbol de widgets bloqueado lanza una aserción.
  void leaveRoom({bool notify = true}) {
    stopTracking();
    _notice = null;
    _error = null;
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _wsService.disconnect();
    _isConnected = false;
    _role = null;
    _roomCode = null;
    _isRunner = false;
    _trackingStopped = false;
    _finalStats = null;
    _resetCheers();
    _currentRunnerLocation = null;
    _messages = [];
    _locations.clear();
    _currentDistance = 0;
    _distanceAcc.reset();
    _pendingLocations = 0;
    _plannedRoute = null;
    _routeProgress = null;
    _sessionStartedAt = null;
    _lastPointAt = null;
    _startTime = null;
    _elapsedTime = Duration.zero;
    _timer?.cancel();
    _timer = null;
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _powerUpController.close();
    _socketSubscription?.cancel();
    _positionSubscription?.cancel();
    _timer?.cancel();
    _gpsWatchdog?.cancel();
    _wsService.disconnect();
    _locationService.stopTracking();
    WakelockPlus.disable().catchError((Object e) {
      debugPrint('[Tracking] Error liberando wakelock: $e');
      return null;
    });
    super.dispose();
  }
}
