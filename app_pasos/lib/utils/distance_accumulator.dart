import 'gpx.dart';

/// Acumula la distancia de una carrera a partir de fixes GPS ruidosos.
///
/// Pensado para el celular en el bolsillo con mala señal (arena, cerros):
/// - Fixes con precisión > [maxAccuracyForDistance] no suman ni mueven el
///   ancla: el siguiente fix bueno "puentea" el tramo.
/// - Huecos largos (sin señal) se puentean en línea recta si la velocidad
///   implícita es plausible, en vez de perder esos km.
/// - Movimientos menores que el ruido esperado no mueven el ancla, para que
///   la caminata lenta sume y el GPS quieto (avituallamiento) no.
class DistanceAccumulator {
  DistanceAccumulator({
    this.maxAccuracyForDistance = 30,
    this.maxSpeedMps = 12,
    this.maxGap = const Duration(hours: 1),
  });

  final double maxAccuracyForDistance;
  final double maxSpeedMps;
  final Duration maxGap;

  double _meters = 0;
  double? _lat;
  double? _lng;
  double _acc = 0;
  DateTime? _time;
  int bridgedGaps = 0;

  double get meters => _meters;
  double get km => _meters / 1000;

  void reset() {
    _meters = 0;
    _lat = null;
    _lng = null;
    _time = null;
    bridgedGaps = 0;
  }

  /// Devuelve los metros sumados por este fix (0 si no sumó).
  double add({
    required double lat,
    required double lng,
    required double accuracy,
    required DateTime timestamp,
    double speed = -1,
  }) {
    if (!accuracy.isFinite || accuracy <= 0 || accuracy > maxAccuracyForDistance) return 0;

    if (_lat == null || _time == null) {
      _setAnchor(lat, lng, accuracy, timestamp);
      return 0;
    }

    final dt = timestamp.difference(_time!).inMilliseconds / 1000;
    if (dt <= 0) return 0;

    final delta = haversineMeters(_lat!, _lng!, lat, lng);
    final implied = delta / dt;

    if (dt > maxGap.inSeconds || implied > maxSpeedMps) {
      // Salto imposible o hueco enorme: reanclar sin sumar.
      _setAnchor(lat, lng, accuracy, timestamp);
      return 0;
    }

    // Ruido esperado: la mitad de la peor precisión de ambos fixes (mín. 3 m).
    final noise = [3.0, 0.5 * (accuracy > _acc ? accuracy : _acc)].reduce((a, b) => a > b ? a : b);
    final stationary = speed >= 0 && speed < 0.3 && delta < accuracy;
    if (delta < noise || stationary) {
      // No mover el ancla: el movimiento lento real se acumula hasta superar el ruido.
      if (dt > 120) _time = timestamp; // evita que un parado largo parezca hueco
      return 0;
    }

    if (dt > 120) bridgedGaps++;
    _meters += delta;
    _setAnchor(lat, lng, accuracy, timestamp);
    return delta;
  }

  void _setAnchor(double lat, double lng, double acc, DateTime t) {
    _lat = lat;
    _lng = lng;
    _acc = acc;
    _time = t;
  }
}
