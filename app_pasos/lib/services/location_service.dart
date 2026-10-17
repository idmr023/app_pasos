import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Servicio singleton de geolocalización para el tracking en vivo.
///
/// Emite un stream de posiciones GPS mientras el tracking está activo.
/// El TrackingProvider es quien reenvía esas posiciones por el socket.
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _currentPosition;
  bool _isTracking = false;
  StreamSubscription<Position>? _positionSubscription;

  static const int _distanceFilterMeters = 5;

  bool get isTracking => _isTracking;
  Position? get currentPosition => _currentPosition;

  Future<void> init() async {
    await _checkAndRequestPermissions();
  }

  Future<void> _checkAndRequestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('El servicio de ubicación está desactivado');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permisos de ubicación denegados permanentemente');
    }
  }

  /// Inicia el tracking y devuelve un stream de posiciones.
  ///
  /// Obtiene primero una posición inicial y luego escucha el stream
  /// periódico de GPS con alta precisión.
  Stream<Position> startTracking() async* {
    if (_isTracking) return;

    await _checkAndRequestPermissions();
    _isTracking = true;

    // 1) Posición conocida previa (instantánea) para que la UI muestre datos
    //    de inmediato mientras se obtiene un fix real.
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _currentPosition = last;
        yield last;
      }
    } catch (_) {}

    // 2) Intento de fix actual con timeout: si no responde en 8s no bloqueamos
    //    el arranque; el stream periódico de abajo seguirá entregando datos.
    try {
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 8));
      _currentPosition = current;
      yield current;
    } catch (_) {}

    // 3) Stream periódico de ubicaciones (siempre arranca, haya o no fix previo)
    final locationSettings =
        defaultTargetPlatform == TargetPlatform.android
            ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: _distanceFilterMeters,
              intervalDuration: const Duration(seconds: 5),
              foregroundNotificationConfig: const ForegroundNotificationConfig(
                notificationTitle: 'App Pasos está registrando tu carrera',
                notificationText:
                    'El tracking continúa activo mientras usas otra app.',
                notificationChannelName: 'Tracking en vivo',
                enableWakeLock: true,
                enableWifiLock: true,
                setOngoing: true,
              ),
            )
            : const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: _distanceFilterMeters,
            );

    final stream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    );

    await for (final position in stream) {
      if (!_isTracking) break;
      _currentPosition = position;
      yield position;
    }
  }

  Future<void> stopTracking() async {
    _isTracking = false;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  Future<void> restartTracking() async {
    await stopTracking();
  }
}
