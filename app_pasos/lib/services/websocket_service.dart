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
    // Reconectar a la misma sala como corredor conserva los puntos pendientes.
    disconnect(keepPending: isRunner && roomCode == _roomCode);
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
        // Sin forceNew, socket_io_client reutiliza el Manager cacheado por
        // URL y puede conservar el query (roomCode/isRunner) de la sala
        // anterior al cambiar de carrera.
        .enableForceNew()
        // Reintentar para siempre: en una carrera larga con mala señal la
        // red puede caer muchas veces; antes se rendía tras 10 intentos.
        .setReconnectionAttempts(double.infinity)
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(5000)
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
      _flushPending();
      // También se dispara en cada reconexión automática.
      _eventsController.add({'type': 'connection', 'data': true});
      if (!completer.isCompleted) completer.complete();
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      _eventsController.add({'type': 'connection', 'data': false});
    });

    _socket!.onConnectError((err) {
      _isConnected = false;
      if (!completer.isCompleted) {
        // Primer intento: el error lo maneja quien llamó a connect().
        completer.completeError(Exception('Error de conexión: $err'));
      }
      // En reconexiones no se emite aviso por cada intento fallido: la UI
      // ya muestra el estado "Reconectando…" vía el evento 'connection'.
    });

    // Eventos del backend -> stream unificado. ('error' se registra solo
    // aquí: onError() escucha el mismo evento y duplicaba cada aviso.)
    for (final event in [
      'connected',
      'locationUpdate',
      'locationBatch',
      'routeUpdated',
      'trackingResumed',
      'chatMessage',
      'powerUp',
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

  // --- Cola offline de ubicaciones (corredor) ---
  // Sin señal, los puntos se guardan aquí y se envían en lotes con ack al
  // reconectar (antes se descartaban y el mapa del espectador quedaba con
  // huecos). Tope ~6 h a 1 punto cada 3 s.
  static const int _maxPending = 7200;
  static const int _batchSize = 200;
  final List<Map<String, dynamic>> _pending = [];
  bool _flushing = false;

  /// Puntos GPS aún no confirmados por el servidor.
  int get pendingLocations => _pending.length;

  /// Encola el punto y lo envía con ack. Todo pasa por la cola: con mala
  /// señal el socket puede seguir "conectado" con el transporte muerto
  /// (hasta ~85 s hasta que el ping lo detecta) y un emit sin ack se perdería.
  void sendLocation(Map<String, dynamic> data) {
    _pending.add(data);
    if (_pending.length > _maxPending) {
      // Se descarta uno de cada dos puntos de la mitad más antigua: se pierde
      // resolución del mapa, no distancia (la distancia viaja acumulada).
      // No se toca el lote que puede estar en vuelo (primeros _batchSize).
      final from = _batchSize;
      final half = _pending.length ~/ 2;
      final thinned = <Map<String, dynamic>>[];
      for (var i = from; i < half; i += 2) {
        thinned.add(_pending[i]);
      }
      _pending.replaceRange(from, half, thinned);
    }
    if (_isConnected) _flushPending();
  }

  /// Intenta entregar los puntos pendientes antes de cerrar la carrera.
  /// Devuelve true si no quedó nada pendiente.
  Future<bool> flushPendingLocations({Duration timeout = const Duration(seconds: 20)}) async {
    final deadline = DateTime.now().add(timeout);
    while (_pending.isNotEmpty && DateTime.now().isBefore(deadline)) {
      if (_isConnected) await _flushPending();
      if (_pending.isEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return _pending.isEmpty;
  }

  Future<void> _flushPending() async {
    if (_flushing || !_isRunner) return;
    _flushing = true;
    try {
      while (_pending.isNotEmpty && _isConnected && _socket != null) {
        final batch = _pending.take(_batchSize).toList();
        final ok = await _emitBatch(batch);
        if (!ok) break; // se reintenta en la próxima reconexión
        _pending.removeRange(0, batch.length);
        _eventsController.add({'type': 'pendingLocations', 'data': _pending.length});
      }
    } finally {
      _flushing = false;
    }
  }

  Future<bool> _emitBatch(List<Map<String, dynamic>> batch) {
    final completer = Completer<bool>();
    final timer = Timer(const Duration(seconds: 15), () {
      if (!completer.isCompleted) completer.complete(false);
    });
    _socket!.emitWithAck('locationBatch', {'points': batch}, ack: (resp) {
      timer.cancel();
      if (!completer.isCompleted) {
        completer.complete(resp is Map && resp['ok'] == true);
      }
    });
    return completer.future;
  }

  bool sendChatMessage(String message) {
    if (!_isConnected || _socket == null) return false;
    _socket!.emit('chatMessage', {'message': message});
    return true;
  }

  /// Power-up / ánimo en vivo (solo espectadores). [text] solo para 'voz';
  /// [senderName] solo lo respeta el servidor para invitados.
  bool sendPowerUp(String type, {String? text, String? senderName}) {
    if (!_isConnected || _socket == null) return false;
    _socket!.emit('powerUp', {
      'type': type,
      if (text != null) 'text': text,
      if (senderName != null) 'senderName': senderName,
    });
    return true;
  }

  void sendStopTracking() {
    if (!_isConnected || _socket == null) return;
    _socket!.emit('stopTracking');
  }

  void disconnect({bool keepPending = false}) {
    if (!keepPending) _pending.clear();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }

  Future<void> reconnect() async {
    final roomCode = _roomCode;
    if (roomCode == null || _isConnected) return;

    // Reuse the existing Socket.IO client when possible. Calling connect()
    // creates a new socket and emits disconnect on the old one, which can
    // trigger the backend's runner disconnect timeout.
    final socket = _socket;
    if (socket != null) {
      socket.connect();
      for (var attempt = 0; attempt < 40; attempt++) {
        if (_isConnected) return;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      throw Exception('Tiempo de espera agotado al reconectar');
    }

    await connect(
      roomCode: roomCode,
      isRunner: _isRunner,
      guestName: _guestName,
    );
  }
}
