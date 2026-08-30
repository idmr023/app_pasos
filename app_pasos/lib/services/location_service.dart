import 'dart:async';
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

    // Posición inicial
    _currentPosition = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    yield _currentPosition!;

    // Stream periódico de ubicaciones
    final stream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _distanceFilterMeters,
      ),
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
}
