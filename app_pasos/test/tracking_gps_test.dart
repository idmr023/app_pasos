import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:app_pasos/utils/distance_accumulator.dart';
import 'package:app_pasos/utils/gpx.dart';

/// Recorrido sintético: costa con curvas suaves desde Lima hacia el sur.
/// Devuelve lat/lng a [meters] metros del inicio.
({double lat, double lng}) _pathAt(double meters) {
  const lat0 = -12.30, lng0 = -76.85;
  const mPerDeg = 111320.0;
  final cosLat = math.cos(lat0 * math.pi / 180);
  // Rumbo que oscila suavemente (curvas de ~1,5 km).
  var x = 0.0, y = 0.0;
  const step = 5.0;
  for (var d = 0.0; d < meters; d += step) {
    final heading = math.pi * 0.75 + 0.35 * math.sin(d / 1500);
    final s = math.min(step, meters - d);
    x += s * math.cos(heading);
    y += s * math.sin(heading);
  }
  return (lat: lat0 + y / mPerDeg, lng: lng0 + x / (mPerDeg * cosLat));
}

void main() {
  group('DistanceAccumulator — 35 km en arena, bolsillo, mala señal', () {
    test('error < 3 % con ruido correlacionado, fixes malos y 6 huecos de 4 min', () {
      final rnd = math.Random(42);
      const totalMeters = 35000.0;
      const speed = 1000 / 390; // 6:30 /km
      final acc = DistanceAccumulator();
      final start = DateTime.utc(2026, 12, 1, 5);

      // Precalcular la trayectoria cada 3 s (incremental para no recorrer desde 0).
      var noiseX = 0.0, noiseY = 0.0;
      final gaps = [3000, 7000, 12000, 18000, 24000, 30000]; // metros donde se pierde señal 4 min
      var t = 0.0;
      var lastMeters = 0.0;
      var pos = _pathAt(0);
      while (lastMeters < totalMeters) {
        t += 3;
        final m = math.min(totalMeters, t * speed);
        // Avanza la trayectoria en pequeños pasos desde el último punto.
        pos = _pathAt(m);
        lastMeters = m;

        final inGap = gaps.any((g) => m > g && m < g + speed * 240);
        if (inGap) continue;

        // 10 % de fixes con precisión pésima (se ignoran para distancia).
        final bad = rnd.nextDouble() < 0.10;
        final accuracy = bad ? 35 + rnd.nextDouble() * 40 : 5 + rnd.nextDouble() * 15;
        // Ruido GPS correlacionado (AR(1)), como el de un receptor real.
        noiseX = 0.95 * noiseX + (rnd.nextDouble() - 0.5) * accuracy * 0.25;
        noiseY = 0.95 * noiseY + (rnd.nextDouble() - 0.5) * accuracy * 0.25;
        const mPerDeg = 111320.0;
        acc.add(
          lat: pos.lat + noiseY / mPerDeg,
          lng: pos.lng + noiseX / (mPerDeg * math.cos(pos.lat * math.pi / 180)),
          accuracy: accuracy,
          timestamp: start.add(Duration(milliseconds: (t * 1000).round())),
          speed: speed,
        );
      }

      final errorPct = (acc.meters - totalMeters).abs() / totalMeters * 100;
      expect(errorPct, lessThan(3), reason: 'medido ${acc.km.toStringAsFixed(2)} km');
      expect(acc.bridgedGaps, greaterThanOrEqualTo(6));
    });

    test('parado en un avituallamiento 5 min no suma distancia', () {
      final rnd = math.Random(7);
      final acc = DistanceAccumulator();
      final start = DateTime.utc(2026);
      var nx = 0.0, ny = 0.0;
      for (var i = 0; i < 100; i++) {
        nx = 0.9 * nx + (rnd.nextDouble() - 0.5) * 2;
        ny = 0.9 * ny + (rnd.nextDouble() - 0.5) * 2;
        acc.add(
          lat: -12.0 + ny / 111320,
          lng: -77.0 + nx / 108000,
          accuracy: 8,
          timestamp: start.add(Duration(seconds: i * 3)),
          speed: 0.1,
        );
      }
      expect(acc.meters, lessThan(30));
    });

    test('salto imposible (teletransporte GPS) no suma', () {
      final acc = DistanceAccumulator();
      final t0 = DateTime.utc(2026);
      acc.add(lat: -12, lng: -77, accuracy: 5, timestamp: t0);
      acc.add(lat: -12.1, lng: -77, accuracy: 5, timestamp: t0.add(const Duration(seconds: 10)));
      expect(acc.meters, 0);
    });
  });

  group('GPX', () {
    const gpx = '''<?xml version="1.0"?>
<gpx version="1.1" creator="test"><metadata><name>Ruta Arena 35K</name></metadata>
<trk><trkseg>
<trkpt lat="-12.0000" lon="-77.0000"><ele>10</ele></trkpt>
<trkpt lon="-77.0000" lat="-12.0090"><ele>30</ele></trkpt>
<trkpt lat='-12.0180' lon='-77.0000'><ele>15</ele></trkpt>
<trkpt lat="-12.0270" lon="-77.0000"/>
</trkseg></trk></gpx>''';

    test('parsea trkpt con atributos en cualquier orden, comillas simples y sin ele', () {
      final r = parseGpx(gpx);
      expect(r.name, 'Ruta Arena 35K');
      expect(r.points.length, 4);
      expect(r.totalKm, closeTo(3.0, 0.03));
      expect(r.elevationGain, closeTo(20, 0.01));
      expect(r.elevationLoss, closeTo(15, 0.01));
    });

    test('rechaza archivos que no son GPX', () {
      expect(() => parseGpx('hola'), throwsA(isA<GpxParseException>()));
    });

    test('progreso: proyecta la posición y calcula lo que falta', () {
      final r = parseGpx(gpx);
      // A mitad del 2º tramo, 20 m al este de la ruta.
      final p = progressOnRoute(r, -12.0135, -76.99982);
      expect(p, isNotNull);
      expect(p!.alongMeters, closeTo(1501, 20));
      expect(p.remainingMeters, closeTo(r.totalMeters - 1501, 20));
      expect(p.offRouteMeters, closeTo(20, 3));
      expect(p.isOffRoute, isFalse);
    });

    test('ida y vuelta: con progreso previo no salta al tramo de ida', () {
      final pts = [
        const GpxPoint(-12.0, -77.0),
        const GpxPoint(-12.018, -77.0),
        const GpxPoint(-12.0, -77.0001), // vuelve casi por el mismo camino
      ];
      final r = GpxRoute('ida y vuelta', pts);
      // Mismo lugar físico (km 0,5 de ida ≈ km 3,5 de vuelta).
      final onReturn = progressOnRoute(r, -12.0045, -77.00005, previousAlong: 3300);
      expect(onReturn!.alongMeters, greaterThan(3000));
    });

    test('simplified reduce puntos y conserva extremos y distancia', () {
      final many = List.generate(5000, (i) => GpxPoint(-12 - i * 0.00007, -77));
      final r = GpxRoute('larga', many);
      final s = r.simplified(1000);
      expect(s.points.length, lessThanOrEqualTo(1000));
      expect(s.points.first.lat, many.first.lat);
      expect(s.points.last.lat, many.last.lat);
      expect(s.totalMeters, closeTo(r.totalMeters, 1));
    });
  });
}
