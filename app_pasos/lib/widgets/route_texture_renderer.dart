import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/route.dart';

/// Renderiza la ruta GPS del usuario como una textura neón (ui.Image)
/// pensada para usarse como `ImageShader` dentro de un `ShaderMask`.
///
/// La imagen resultante tiene:
/// - Una base oscura sutil (para que la silueta del texto quede visible).
/// - El trazado GPS dibujado en 3 pasadas: glow difuso, cuerpo teal y núcleo blanco.
class RouteTextureRenderer {
  static const Color neonTeal = Color(0xFF00F5D4);
  static const Color neonPurple = Color(0xFF7B2CBF);

  /// Devuelve null si no hay suficientes coordenadas para trazar un path.
  static Future<ui.Image?> render({
    required List<Coordinate> coordinates,
    double width = 1080,
    double height = 1440,
  }) async {
    if (coordinates.length < 2) return null;

    final path = _buildNormalizedPath(coordinates, Size(width, height));
    if (path == null) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    // 1. Base oscura: el texto queda visible incluso donde no pasa la ruta
    final basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF16161F), Color(0xFF1E1B2E)],
      ).createShader(Rect.fromLTWH(0, 0, width, height));
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), basePaint);

    // 2. Glow exterior morado (blur amplio)
    canvas.drawPath(
      path,
      Paint()
        ..color = neonPurple.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 42
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 38),
    );

    // 3. Glow medio teal (blur medio)
    canvas.drawPath(
      path,
      Paint()
        ..color = neonTeal.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // 4. Núcleo blanco-caliente: el "río" propiamente dicho
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final picture = recorder.endRecording();
    return picture.toImage(width.round(), height.round());
  }

  /// Normaliza lat/lng a un [Path] que encaja en [size] preservando
  /// la proporción geográfica, con padding lateral.
  static Path? _buildNormalizedPath(List<Coordinate> coords, Size size) {
    double minLat = coords.first.lat, maxLat = coords.first.lat;
    double minLng = coords.first.lng, maxLng = coords.first.lng;

    for (final c in coords) {
      if (c.lat < minLat) minLat = c.lat;
      if (c.lat > maxLat) maxLat = c.lat;
      if (c.lng < minLng) minLng = c.lng;
      if (c.lng > maxLng) maxLng = c.lng;
    }

    final latSpan = maxLat - minLat;
    final lngSpan = maxLng - minLng;
    if (latSpan <= 0 && lngSpan <= 0) return null;

    // Área útil con padding del 12%
    const padFraction = 0.12;
    final usableW = size.width * (1 - padFraction * 2);
    final usableH = size.height * (1 - padFraction * 2);

    // Escala uniforme para no deformar la ruta
    final scaleX = lngSpan > 0 ? usableW / lngSpan : double.infinity;
    final scaleY = latSpan > 0 ? usableH / latSpan : double.infinity;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final routeW = lngSpan * scale;
    final routeH = latSpan * scale;
    final offsetX = (size.width - routeW) / 2;
    final offsetY = (size.height - routeH) / 2;

    final path = Path();
    for (int i = 0; i < coords.length; i++) {
      final c = coords[i];
      final x = offsetX + (c.lng - minLng) * scale;
      // Invertir Y: latitud mayor = arriba
      final y = offsetY + (maxLat - c.lat) * scale;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path;
  }
}
