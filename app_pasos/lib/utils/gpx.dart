import 'dart:math' as math;

/// Punto de una ruta GPX (lat/lng en grados, ele en metros o null).
class GpxPoint {
  final double lat;
  final double lng;
  final double? ele;
  const GpxPoint(this.lat, this.lng, [this.ele]);

  List<num> toJson() => ele == null ? [lat, lng] : [lat, lng, ele!];

  static GpxPoint? fromJson(dynamic v) {
    if (v is List && v.length >= 2 && v[0] is num && v[1] is num) {
      return GpxPoint(
        (v[0] as num).toDouble(),
        (v[1] as num).toDouble(),
        v.length > 2 && v[2] is num ? (v[2] as num).toDouble() : null,
      );
    }
    return null;
  }
}

double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Ruta planificada (de un .gpx) con distancias acumuladas precalculadas.
class GpxRoute {
  final String name;
  final List<GpxPoint> points;
  final List<double> cumulative; // metros desde el inicio hasta cada punto
  final double elevationGain;
  final double elevationLoss;

  GpxRoute._(this.name, this.points, this.cumulative, this.elevationGain, this.elevationLoss);

  factory GpxRoute(String name, List<GpxPoint> points) {
    final cum = <double>[];
    var total = 0.0;
    var gain = 0.0;
    var loss = 0.0;
    double? smoothEle;
    for (var i = 0; i < points.length; i++) {
      if (i > 0) {
        total += haversineMeters(points[i - 1].lat, points[i - 1].lng, points[i].lat, points[i].lng);
      }
      cum.add(total);
      final e = points[i].ele;
      if (e != null) {
        // Umbral de 3 m para no sumar el ruido del altímetro/GPS.
        if (smoothEle == null) {
          smoothEle = e;
        } else if ((e - smoothEle).abs() >= 3) {
          if (e > smoothEle) {
            gain += e - smoothEle;
          } else {
            loss += smoothEle - e;
          }
          smoothEle = e;
        }
      }
    }
    return GpxRoute._(name, points, cum, gain, loss);
  }

  factory GpxRoute.fromJson(Map<String, dynamic> j) {
    final pts = ((j['points'] as List?) ?? []).map(GpxPoint.fromJson).whereType<GpxPoint>().toList();
    return GpxRoute(j['name']?.toString() ?? 'Ruta', pts);
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'points': points.map((p) => p.toJson()).toList(),
      };

  double get totalMeters => cumulative.isEmpty ? 0 : cumulative.last;
  double get totalKm => totalMeters / 1000;
  bool get hasElevation => points.any((p) => p.ele != null);

  /// Reduce a ≤ [maxPoints] conservando forma (espaciado uniforme por
  /// distancia + siempre el primero y el último).
  GpxRoute simplified(int maxPoints) {
    if (points.length <= maxPoints) return this;
    final step = totalMeters / (maxPoints - 1);
    final kept = <GpxPoint>[points.first];
    var lastKeptAt = 0.0;
    for (var i = 1; i < points.length - 1; i++) {
      if (cumulative[i] - lastKeptAt >= step) {
        kept.add(points[i]);
        lastKeptAt = cumulative[i];
      }
    }
    kept.add(points.last);
    return GpxRoute(name, kept);
  }
}

class GpxParseException implements Exception {
  final String message;
  GpxParseException(this.message);
  @override
  String toString() => message;
}

final _ptRegex = RegExp(r'<(trkpt|rtept)\b([^>]*?)(/>|>([\s\S]*?)</\1>)', caseSensitive: false);
final _latRegex = RegExp(r'''\blat\s*=\s*["']([-+0-9.eE]+)["']''');
final _lonRegex = RegExp(r'''\blon\s*=\s*["']([-+0-9.eE]+)["']''');
final _eleRegex = RegExp(r'<ele>\s*([-+0-9.eE]+)\s*</ele>', caseSensitive: false);
final _nameRegex = RegExp(r'<name>\s*(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?\s*</name>', caseSensitive: false);

/// Parsea un GPX (tracks `trkpt` o, si no hay, rutas `rtept`).
GpxRoute parseGpx(String xml, {String fallbackName = 'Ruta GPX'}) {
  if (!xml.contains('<gpx')) {
    throw GpxParseException('El archivo no parece un GPX válido');
  }
  final trk = <GpxPoint>[];
  final rte = <GpxPoint>[];
  for (final m in _ptRegex.allMatches(xml)) {
    final attrs = m.group(2) ?? '';
    final lat = double.tryParse(_latRegex.firstMatch(attrs)?.group(1) ?? '');
    final lon = double.tryParse(_lonRegex.firstMatch(attrs)?.group(1) ?? '');
    if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) continue;
    final ele = double.tryParse(_eleRegex.firstMatch(m.group(4) ?? '')?.group(1) ?? '');
    final p = GpxPoint(lat, lon, ele);
    (m.group(1)!.toLowerCase() == 'trkpt' ? trk : rte).add(p);
  }
  final points = trk.length >= 2 ? trk : rte;
  if (points.length < 2) {
    throw GpxParseException('El GPX no tiene un recorrido (necesita al menos 2 puntos)');
  }
  final rawName = _nameRegex.firstMatch(xml)?.group(1)?.trim() ?? '';
  final name = rawName.isEmpty ? fallbackName : (rawName.length > 80 ? rawName.substring(0, 80) : rawName);
  return GpxRoute(name, points);
}

/// Progreso de una posición sobre la ruta planificada.
class RouteProgress {
  final double alongMeters; // recorrido sobre la ruta
  final double remainingMeters;
  final double offRouteMeters; // distancia perpendicular a la ruta
  const RouteProgress(this.alongMeters, this.remainingMeters, this.offRouteMeters);

  bool get isOffRoute => offRouteMeters > 150;
}

/// Proyecta [lat]/[lng] sobre la ruta. [previousAlong] (metros) acota la
/// búsqueda a una ventana cercana para que en rutas ida y vuelta o en bucle
/// no "salte" al tramo equivocado; si la ventana queda lejos, busca en toda
/// la ruta.
RouteProgress? progressOnRoute(GpxRoute route, double lat, double lng, {double? previousAlong}) {
  final pts = route.points;
  if (pts.length < 2) return null;

  // Proyección equirectangular local (suficiente a escala de segmentos).
  final cosLat = math.cos(lat * math.pi / 180);
  const mPerDeg = 111320.0;
  double x(GpxPoint p) => (p.lng - lng) * mPerDeg * cosLat;
  double y(GpxPoint p) => (p.lat - lat) * mPerDeg;

  ({double dist, double along})? best(int from, int to) {
    ({double dist, double along})? b;
    for (var i = from; i < to; i++) {
      final ax = x(pts[i]), ay = y(pts[i]);
      final bx = x(pts[i + 1]), by = y(pts[i + 1]);
      final dx = bx - ax, dy = by - ay;
      final len2 = dx * dx + dy * dy;
      var t = len2 == 0 ? 0.0 : -(ax * dx + ay * dy) / len2;
      t = t.clamp(0.0, 1.0);
      final px = ax + t * dx, py = ay + t * dy;
      final d = math.sqrt(px * px + py * py);
      if (b == null || d < b.dist) {
        final segLen = route.cumulative[i + 1] - route.cumulative[i];
        b = (dist: d, along: route.cumulative[i] + t * segLen);
      }
    }
    return b;
  }

  ({double dist, double along})? result;
  if (previousAlong != null) {
    final lo = previousAlong - 500;
    final hi = previousAlong + 3000;
    var from = 0;
    while (from < pts.length - 2 && route.cumulative[from + 1] < lo) {
      from++;
    }
    var to = from;
    while (to < pts.length - 1 && route.cumulative[to] <= hi) {
      to++;
    }
    result = best(from, math.max(to, from + 1).clamp(1, pts.length - 1));
    if (result != null && result.dist > 200) result = null;
  }
  result ??= best(0, pts.length - 1);
  if (result == null) return null;
  final along = result.along.clamp(0.0, route.totalMeters);
  return RouteProgress(along, route.totalMeters - along, result.dist);
}
