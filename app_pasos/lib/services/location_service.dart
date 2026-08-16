import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _currentPosition;
  bool _isTracking = false;
  WebSocketChannel? _wsChannel;
  String? _roomCode;
  DateTime? _lastUpdate;
  Duration _updateInterval = const Duration(seconds: 3);
  double _distanceFilter = 5.0; // meters

  bool get isTracking => _isTracking;
  Position? get currentPosition => _currentPosition;

  Future<void> init() async {
    // Verify permissions
    await _checkAndRequestPermissions();
  }

  Future<void> _checkAndRequestPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permisos de ubicación denegados permanentemente');
    }
  }

  Future<void> startTracking({
    required String roomCode,
    required WebSocketChannel wsChannel,
  }) async {
    if (_isTracking) return;

    _isTracking = true;
    _roomCode = roomCode;
    _wsChannel = wsChannel;
    _lastUpdate = DateTime.now();

    // Get initial position
    _currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    _sendLocationUpdate(_currentPosition!);

    // Start periodic location updates
    Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _distanceFilter,
        timeLimit: _updateInterval,
      ),
    ).listen((Position position) {
      _currentPosition = position;
      _sendLocationUpdate(position);
    }).onError((error) {
      print('Error en stream de ubicación: $error');
    });
  }

  Future<void> stopTracking() async {
    if (!_isTracking) return;
    _isTracking = false;
    Geolocator.getPositionStream().listen((_) {}).cancel();
    _wsChannel = null;
    _roomCode = null;
    notifyListeners(); // If needed
  }

  void _sendLocationUpdate(Position location) {
    if (_wsChannel == null || _roomCode == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    // Calculate pace (min/km) from speed (m/s)
    double pace = 0;
    if (location.speed > 0) {
      // speed in m/s, convert to min/km
      // 1 m/s = 18 min/km approx (actually 60/3.6 = 16.67)
      pace = (60 / (location.speed * 3.6)).roundToDouble();
    }

    final data = {
      'roomCode': _roomCode,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'speed': location.speed,
      'pace': pace,
      'timestamp': now,
      'accuracy': location.accuracy,
    };

    _wsChannel!.sink.add('locationUpdate:${json.encode(data)}');
  }

  void notifyListeners() {
    // Placeholder for future notification system
  }
}