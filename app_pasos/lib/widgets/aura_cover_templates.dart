import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/cover_style.dart';
import '../models/route.dart';
import '../models/route_card_template.dart';
import 'aura_card_builder.dart';

/// Portadas v4 (Revista, Neón Nocturno, Minimal, Polaroid, Podio, Dorsal,
/// Foto + Mapa, Atardecer).
///
/// Todas las medidas usan la unidad `u = ancho / 100`, así la portada se ve
/// idéntica en la previsualización y en el PNG exportado (que se captura con
/// un `pixelRatio` que la lleva a 1080 px de ancho).
class AuraCoverTemplate extends StatelessWidget {
  final TemplateType type;
  final AuraData data;
  final AuraMetricsConfig config;
  final CoverStyle style;

  const AuraCoverTemplate({
    super.key,
    required this.type,
    required this.data,
    required this.config,
    required this.style,
  });

  static String defaultFont(TemplateType type) {
    switch (type) {
      case TemplateType.revista:
        return 'Playfair Display';
      case TemplateType.neonNocturno:
        return 'Orbitron';
      case TemplateType.polaroid:
        return 'Permanent Marker';
      case TemplateType.podio:
        return 'Oswald';
      case TemplateType.dorsal:
      case TemplateType.atardecer:
        return 'Bebas Neue';
      default:
        return 'Montserrat';
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final c = CoverContext(
        data: data,
        config: config,
        style: style,
        accent: style.accent ?? type.accent,
        font: style.fontFamily ?? defaultFont(type),
        u: constraints.maxWidth / 100,
        h: constraints.maxHeight,
      );
      switch (type) {
        case TemplateType.revista:
          return _Revista(c);
        case TemplateType.neonNocturno:
          return _NeonNocturno(c);
        case TemplateType.minimal:
          return _Minimal(c);
        case TemplateType.polaroid:
          return _Polaroid(c);
        case TemplateType.podio:
          return _Podio(c);
        case TemplateType.dorsal:
          return _Dorsal(c);
        case TemplateType.fotoMapa:
          return _FotoMapa(c);
        case TemplateType.atardecer:
          return _Atardecer(c);
        default:
          return const SizedBox.shrink();
      }
    });
  }
}

/// Datos ya resueltos (acento, fuente, título) que comparten las portadas.
class CoverContext {
  final AuraData data;
  final AuraMetricsConfig config;
  final CoverStyle style;
  final Color accent;
  final String font;
  final double u;
  final double h;

  const CoverContext({
    required this.data,
    required this.config,
    required this.style,
    required this.accent,
    required this.font,
    required this.u,
    required this.h,
  });

  String get title {
    final custom = style.customTitle?.trim() ?? '';
    return custom.isNotEmpty ? custom : data.title;
  }

  String get km {
    final d = data.distanceKm;
    return d.toStringAsFixed(d >= 100 ? 0 : (d >= 10 ? 1 : 2));
  }

  String get date => coverDate(data.date);

  bool get showMap => config.showMap && data.coordinates.length >= 2;

  /// Estilo de texto con la fuente elegida. [size] en unidades `u`.
  TextStyle f(
    double size, {
    Color color = Colors.white,
    FontWeight weight = FontWeight.w700,
    double spacing = 0,
    double height = 1.1,
    List<Shadow>? shadows,
    String? family,
  }) {
    return GoogleFonts.getFont(
      family ?? font,
      fontSize: size * u,
      color: color,
      fontWeight: weight,
      letterSpacing: spacing * u,
      height: height,
      shadows: shadows,
    );
  }

  /// Estilo neutro (Inter) para etiquetas pequeñas.
  TextStyle label(double size, {Color color = Colors.white70, double spacing = 0.3, FontWeight weight = FontWeight.w600}) {
    return GoogleFonts.inter(
      fontSize: size * u,
      color: color,
      fontWeight: weight,
      letterSpacing: spacing * u,
      height: 1.2,
    );
  }

  List<(String, String)> stats({bool includeDistance = false}) =>
      coverStatList(data, config, includeDistance: includeDistance);
}

const _months = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];
const _weekdays = ['LUNES', 'MARTES', 'MIÉRCOLES', 'JUEVES', 'VIERNES', 'SÁBADO', 'DOMINGO'];

String coverDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
String coverWeekday(DateTime d) => _weekdays[d.weekday - 1];

/// Lista (etiqueta, valor) de las métricas activas. Omite valores vacíos/0.
List<(String, String)> coverStatList(AuraData d, AuraMetricsConfig c, {bool includeDistance = false}) {
  final out = <(String, String)>[];
  if (includeDistance && c.showDistance) out.add(('DISTANCIA', '${d.distanceKm.toStringAsFixed(2)} km'));
  if (c.showPace && d.pace != '--' && d.pace.isNotEmpty) out.add(('RITMO', '${d.pace} /km'));
  if (c.showTime && d.duration != '--' && d.duration.isNotEmpty) out.add(('TIEMPO', d.duration));
  if (c.showElevation && d.elevationGain > 0) out.add(('DESNIVEL', '+${d.elevationGain} m'));
  if (c.showCalories && d.calories > 0) out.add(('CALORÍAS', '${d.calories} kcal'));
  if (c.showHeartRate && d.heartRate > 0) out.add(('FC MEDIA', '${d.heartRate} bpm'));
  return out;
}

Color coverOnColor(Color c) => c.computeLuminance() > 0.5 ? Colors.black : Colors.white;

// ───────────────────────── Piezas compartidas ─────────────────────────

/// Foto del usuario (bytes en memoria) con encuadre, zoom, desenfoque y
/// oscurecido. Si no hay foto, pinta [fallback].
class CoverPhotoLayer extends StatelessWidget {
  final CoverStyle style;
  final Widget fallback;

  const CoverPhotoLayer({super.key, required this.style, required this.fallback});

  @override
  Widget build(BuildContext context) {
    final bytes = style.photoBytes;
    if (bytes == null) return fallback;

    Widget img = Image.memory(
      bytes,
      fit: style.photoFit,
      alignment: style.photoAlignment,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
    );
    final scale = style.photoZoom * (style.photoBlur > 0 ? 1.06 : 1.0);
    if (scale != 1) {
      img = Transform.scale(scale: scale, alignment: style.photoAlignment, child: img);
    }
    if (style.photoBlur > 0) {
      img = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: style.photoBlur, sigmaY: style.photoBlur),
        child: img,
      );
    }
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          img,
          if (style.photoDarken > 0)
            ColoredBox(color: Colors.black.withValues(alpha: style.photoDarken.clamp(0.0, 0.9))),
        ],
      ),
    );
  }
}

/// Dibuja la ruta GPS proyectada (equirectangular con corrección cos(lat))
/// preservando proporciones, con glow opcional y marcadores inicio/fin.
class CoverRoutePainter extends CustomPainter {
  final List<Coordinate> points;
  final Color color;
  final Color? glowColor;
  final double strokeWidth;
  final double padding;
  final bool showEndpoints;

  CoverRoutePainter({
    required this.points,
    required this.color,
    this.glowColor,
    this.strokeWidth = 4,
    this.padding = 0.08,
    this.showEndpoints = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final step = math.max(1, points.length ~/ 1500);
    final pts = <Coordinate>[for (var i = 0; i < points.length; i += step) points[i], points.last];

    var minLat = double.infinity, maxLat = -double.infinity;
    var minLng = double.infinity, maxLng = -double.infinity;
    for (final p in pts) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLng = math.min(minLng, p.lng);
      maxLng = math.max(maxLng, p.lng);
    }
    final cosLat = math.cos(((minLat + maxLat) / 2) * math.pi / 180);
    final spanX = (maxLng - minLng) * cosLat;
    final spanY = maxLat - minLat;
    if (spanX <= 0 && spanY <= 0) return;

    final pad = math.min(size.width, size.height) * padding + strokeWidth;
    final availW = size.width - pad * 2;
    final availH = size.height - pad * 2;
    if (availW <= 0 || availH <= 0) return;
    final scale = math.min(
      spanX > 0 ? availW / spanX : double.infinity,
      spanY > 0 ? availH / spanY : double.infinity,
    );
    final offX = (size.width - spanX * scale) / 2;
    final offY = (size.height - spanY * scale) / 2;

    Offset project(Coordinate p) => Offset(
          offX + (p.lng - minLng) * cosLat * scale,
          offY + (maxLat - p.lat) * scale,
        );

    final path = Path();
    final first = project(pts.first);
    path.moveTo(first.dx, first.dy);
    for (var i = 1; i < pts.length; i++) {
      final o = project(pts[i]);
      path.lineTo(o.dx, o.dy);
    }

    final glow = glowColor;
    if (glow != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = glow.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * 2),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    if (showEndpoints) {
      final r = strokeWidth * 1.3;
      canvas.drawCircle(first, r, Paint()..color = const Color(0xFF22C55E));
      canvas.drawCircle(first, r * 0.45, Paint()..color = Colors.white);
      final last = project(pts.last);
      canvas.drawCircle(last, r, Paint()..color = const Color(0xFFF97316));
      canvas.drawCircle(last, r * 0.45, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(CoverRoutePainter old) =>
      old.points != points ||
      old.color != color ||
      old.glowColor != glowColor ||
      old.strokeWidth != strokeWidth ||
      old.padding != padding;
}

Widget _route(CoverContext c, {required Color color, Color? glow, double stroke = 1, double padding = 0.08, bool endpoints = true}) {
  return CustomPaint(
    painter: CoverRoutePainter(
      points: c.data.coordinates,
      color: color,
      glowColor: glow,
      strokeWidth: stroke * c.u,
      padding: padding,
      showEndpoints: endpoints,
    ),
    child: const SizedBox.expand(),
  );
}

/// Código de barras decorativo (determinista según la distancia).
class _BarcodePainter extends CustomPainter {
  final int seed;
  final Color color;
  _BarcodePainter(this.seed, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final paint = Paint()..color = color;
    var x = 0.0;
    while (x < size.width) {
      final w = size.width * (0.01 + rnd.nextDouble() * 0.035);
      if (rnd.nextBool()) canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      x += w + size.width * 0.012;
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter old) => old.seed != seed || old.color != color;
}

/// Confeti determinista (Podio).
class _ConfettiPainter extends CustomPainter {
  final List<Color> colors;
  _ConfettiPainter(this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    for (var i = 0; i < 46; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height * 0.62;
      final w = size.width * (0.012 + rnd.nextDouble() * 0.014);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rnd.nextDouble() * math.pi);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: w, height: w * 2.2),
        Paint()..color = colors[i % colors.length].withValues(alpha: 0.85),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}

/// Grilla en perspectiva estilo synthwave (Neón Nocturno).
class _NeonGridPainter extends CustomPainter {
  final Color color;
  _NeonGridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final horizon = size.height * 0.62;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = size.width * 0.003;
    for (var i = 0; i < 12; i++) {
      final t = i / 11;
      final y = horizon + (size.height - horizon) * t * t;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    final cx = size.width / 2;
    for (var i = -8; i <= 8; i++) {
      canvas.drawLine(Offset(cx + i * size.width * 0.02, horizon), Offset(cx + i * size.width * 0.22, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_NeonGridPainter old) => old.color != color;
}

/// Sol retro con franjas (Atardecer).
class _RetroSunPainter extends CustomPainter {
  final Color accent;
  _RetroSunPainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final r = size.width / 2;
    canvas.saveLayer(rect, Paint());
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFFFFE66D), accent, const Color(0xFFFF2E88)],
        ).createShader(rect),
    );
    final clear = Paint()..blendMode = BlendMode.clear;
    for (var i = 0; i < 6; i++) {
      final y = center.dy + r * (0.1 + i * 0.16);
      final h = r * (0.025 + i * 0.012);
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, h), clear);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RetroSunPainter old) => old.accent != accent;
}

/// Línea punteada horizontal (Dorsal).
class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height;
    final dash = size.width / 60;
    for (var x = 0.0; x < size.width; x += dash * 2) {
      canvas.drawLine(Offset(x, size.height / 2), Offset(x + dash, size.height / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}

// ───────────────────────── 1. Portada Revista ─────────────────────────

class _Revista extends StatelessWidget {
  final CoverContext c;
  const _Revista(this.c);

  @override
  Widget build(BuildContext context) {
    final u = c.u;
    final shadow = [Shadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 2 * u)];
    final stats = c.stats();
    return Stack(
      fit: StackFit.expand,
      children: [
        CoverPhotoLayer(
          style: c.style,
          fallback: Stack(fit: StackFit.expand, children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.lerp(c.accent, Colors.black, 0.35)!, const Color(0xFF0A0A0A)],
                ),
              ),
            ),
            if (c.showMap)
              Opacity(opacity: 0.35, child: _route(c, color: Colors.white, stroke: 1.4, padding: 0.12, endpoints: false)),
          ]),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.transparent, Colors.transparent, Colors.black87],
              stops: [0, 0.3, 0.55, 1],
            ),
          ),
        ),
        // Cabecera de revista
        Positioned(
          top: 5 * u,
          left: 5 * u,
          right: 5 * u,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Text('EDICIÓN · ${c.date}', style: c.label(2.6, color: Colors.white)),
                const Spacer(),
                Text('Nº ${c.data.distanceKm.round()}', style: c.label(2.6, color: Colors.white)),
              ]),
              SizedBox(height: 1 * u),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  c.title.toUpperCase(),
                  maxLines: 1,
                  style: c.f(20, weight: FontWeight.w900, height: 0.95, shadows: shadow),
                ),
              ),
              SizedBox(height: 1 * u),
              Container(height: 0.8 * u, color: c.accent),
            ],
          ),
        ),
        // Sello circular "día"
        Positioned(
          right: 6 * u,
          top: 36 * u,
          child: Transform.rotate(
            angle: 0.25,
            child: Container(
              width: 20 * u,
              height: 20 * u,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
              child: Text(
                '${coverWeekday(c.data.date)}\nRUN',
                textAlign: TextAlign.center,
                style: c.label(2.4, color: coverOnColor(c.accent), weight: FontWeight.w900),
              ),
            ),
          ),
        ),
        // Titulares de portada
        Positioned(
          left: 5 * u,
          right: 34 * u,
          bottom: 7 * u,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (c.config.showDistance) ...[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(c.km, style: c.f(22, color: c.accent, weight: FontWeight.w900, height: 0.9, shadows: shadow)),
                ),
                Text('KILÓMETROS QUE CUENTAN', style: c.label(2.8, color: Colors.white, weight: FontWeight.w800)),
                SizedBox(height: 2.5 * u),
              ],
              for (final s in stats.take(4)) ...[
                Text(s.$2, style: c.f(6, shadows: shadow)),
                Text(s.$1, style: c.label(2.2, color: Colors.white70)),
                SizedBox(height: 1.2 * u),
              ],
            ],
          ),
        ),
        if (c.showMap && c.style.hasPhoto)
          Positioned(
            right: 5 * u,
            bottom: 17 * u,
            width: 26 * u,
            height: 26 * u,
            child: _route(c, color: Colors.white, glow: c.accent, stroke: 0.7),
          ),
        Positioned(
          right: 5 * u,
          bottom: 5 * u,
          child: Container(
            padding: EdgeInsets.all(0.8 * u),
            color: Colors.white,
            width: 22 * u,
            height: 9 * u,
            child: CustomPaint(painter: _BarcodePainter((c.data.distanceKm * 100).round(), Colors.black)),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── 2. Neón Nocturno ─────────────────────────

class _NeonNocturno extends StatelessWidget {
  final CoverContext c;
  const _NeonNocturno(this.c);

  @override
  Widget build(BuildContext context) {
    final u = c.u;
    const cyan = Color(0xFF00F0FF);
    final glow = [
      Shadow(color: c.accent, blurRadius: 1.5 * u),
      Shadow(color: c.accent, blurRadius: 5 * u),
    ];
    final stats = c.stats();
    return Stack(
      fit: StackFit.expand,
      children: [
        CoverPhotoLayer(
          style: c.style,
          fallback: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF000000), Color(0xFF12002B), Color(0xFF2A0845)],
              ),
            ),
          ),
        ),
        if (c.style.hasPhoto) ColoredBox(color: const Color(0xFF12002B).withValues(alpha: 0.4)),
        CustomPaint(painter: _NeonGridPainter(c.accent)),
        Positioned(
          top: 6 * u,
          left: 6 * u,
          right: 6 * u,
          child: Row(children: [
            Text('NIGHT RUN', style: c.f(4, color: c.accent, spacing: 0.8, shadows: glow)),
            const Spacer(),
            Text(c.date, style: c.label(2.6, color: cyan)),
          ]),
        ),
        if (c.showMap)
          Positioned(
            top: 16 * u,
            left: 8 * u,
            right: 8 * u,
            height: 72 * u,
            child: _route(c, color: Colors.white, glow: c.accent, stroke: 1.1),
          ),
        Positioned(
          left: 6 * u,
          right: 6 * u,
          bottom: 10 * u,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (c.config.showDistance)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(c.km, style: c.f(20, weight: FontWeight.w900, shadows: glow)),
                      SizedBox(width: 2 * u),
                      Text('KM', style: c.f(6, color: cyan, shadows: [Shadow(color: cyan, blurRadius: 3 * u)])),
                    ],
                  ),
                ),
              Text(
                c.title.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: c.f(4.4, spacing: 0.4),
              ),
              SizedBox(height: 4 * u),
              Wrap(
                spacing: 2 * u,
                runSpacing: 2 * u,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < stats.length; i++)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 3 * u, vertical: 1.6 * u),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10 * u),
                        border: Border.all(color: i.isEven ? c.accent : cyan, width: 0.4 * u),
                        boxShadow: [BoxShadow(color: (i.isEven ? c.accent : cyan).withValues(alpha: 0.5), blurRadius: 2.5 * u)],
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(stats[i].$2, style: c.label(3.6, color: Colors.white, weight: FontWeight.w800)),
                        Text(stats[i].$1, style: c.label(2, color: Colors.white60)),
                      ]),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── 3. Minimal ─────────────────────────

class _Minimal extends StatelessWidget {
  final CoverContext c;
  const _Minimal(this.c);

  @override
  Widget build(BuildContext context) {
    final u = c.u;
    final photo = c.style.hasPhoto;
    final ink = photo ? Colors.white : const Color(0xFF111111);
    final soft = ink.withValues(alpha: 0.55);
    final stats = c.stats();
    return Stack(
      fit: StackFit.expand,
      children: [
        CoverPhotoLayer(style: c.style, fallback: const ColoredBox(color: Color(0xFFF4F1EA))),
        Padding(
          padding: EdgeInsets.all(8 * u),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(coverWeekday(c.data.date), style: c.label(2.8, color: ink, weight: FontWeight.w800, spacing: 0.6)),
                      Text(c.date, style: c.label(2.6, color: soft)),
                    ]),
                  ),
                  if (c.showMap)
                    SizedBox(
                      width: 24 * u,
                      height: 24 * u,
                      child: _route(c, color: c.accent == ink ? ink : c.accent, stroke: 0.6, endpoints: false),
                    ),
                ],
              ),
              const Spacer(),
              if (c.config.showDistance) ...[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(c.km, style: c.f(34, color: ink, weight: FontWeight.w800, height: 0.9, spacing: -1)),
                ),
                Text('kilómetros', style: c.f(4.5, color: soft, weight: FontWeight.w500)),
                SizedBox(height: 5 * u),
              ],
              Container(height: 0.3 * u, color: c.accent == ink ? soft : c.accent),
              SizedBox(height: 4 * u),
              Wrap(
                runSpacing: 4 * u,
                children: [
                  for (final s in stats)
                    SizedBox(
                      width: 42 * u,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.$1, style: c.label(2.4, color: soft, spacing: 0.5)),
                        SizedBox(height: 0.6 * u),
                        Text(s.$2, style: c.f(6, color: ink, weight: FontWeight.w600)),
                      ]),
                    ),
                ],
              ),
              SizedBox(height: 7 * u),
              Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: c.f(4.6, color: ink, weight: FontWeight.w600)),
              SizedBox(height: 1 * u),
              Text('APP PASOS', style: c.label(2.2, color: soft, spacing: 1)),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── 4. Polaroid ─────────────────────────

class _Polaroid extends StatelessWidget {
  final CoverContext c;
  const _Polaroid(this.c);

  @override
  Widget build(BuildContext context) {
    final u = c.u;
    final stats = c.stats();
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.lerp(c.accent, Colors.white, 0.3)!, Color.lerp(c.accent, Colors.black, 0.4)!],
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0, -0.42),
          child: Transform.rotate(
            angle: -0.06,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 78 * u,
                  padding: EdgeInsets.fromLTRB(4 * u, 4 * u, 4 * u, 3 * u),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 4 * u, offset: Offset(0, 1.5 * u))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: CoverPhotoLayer(
                          style: c.style,
                          fallback: Stack(fit: StackFit.expand, children: [
                            const ColoredBox(color: Color(0xFF1E1E24)),
                            if (c.showMap) _route(c, color: c.accent, glow: c.accent, stroke: 1),
                          ]),
                        ),
                      ),
                      SizedBox(height: 3 * u),
                      Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: c.f(6, color: Colors.black87, weight: FontWeight.w400)),
                      Text(
                        c.config.showDistance ? '${c.km} km · ${c.date}' : c.date,
                        style: c.f(3.6, color: Colors.black54, weight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: -3 * u,
                  left: 27 * u,
                  child: Transform.rotate(
                    angle: 0.06,
                    child: Container(width: 24 * u, height: 7 * u, color: Colors.white.withValues(alpha: 0.55)),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (stats.isNotEmpty)
          Align(
            alignment: const Alignment(0.1, 0.88),
            child: Transform.rotate(
              angle: 0.035,
              child: Container(
                width: 66 * u,
                padding: EdgeInsets.all(4 * u),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3B0),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3 * u, offset: Offset(0, 1 * u))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final s in stats.take(4))
                      Text('• ${s.$2}  ${s.$1.toLowerCase()}', style: c.f(3.8, color: const Color(0xFF3A3A3A), weight: FontWeight.w400, height: 1.35)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ───────────────────────── 5. Podio ─────────────────────────

class _Podio extends StatelessWidget {
  final CoverContext c;
  const _Podio(this.c);

  @override
  Widget build(BuildContext context) {
    final u = c.u;
    final stats = c.stats();
    final gold = c.accent;
    final goldDark = Color.lerp(gold, Colors.black, 0.45)!;
    final textOnGold = Color.lerp(gold, Colors.black, 0.75)!;

    // Orden visual del podio: 2º - 1º - 3º
    (String, String)? statAt(int i) => i < stats.length ? stats[i] : null;
    final blocks = [
      (place: 2, height: 22.0, color: const Color(0xFFC9CED6), stat: statAt(1)),
      (place: 1, height: 32.0, color: gold, stat: statAt(0)),
      (place: 3, height: 16.0, color: const Color(0xFFCD7F32), stat: statAt(2)),
    ];

    return Stack(
      fit: StackFit.expand,
      children: [
        CoverPhotoLayer(
          style: c.style,
          fallback: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.4),
                radius: 1.1,
                colors: [Color(0xFF3A2A05), Color(0xFF0B0B10)],
              ),
            ),
          ),
        ),
        CustomPaint(painter: _ConfettiPainter([gold, const Color(0xFFFF3B30), const Color(0xFF3B82F6), Colors.white])),
        if (c.showMap)
          Positioned(
            top: 4 * u,
            left: 4 * u,
            right: 4 * u,
            height: 80 * u,
            child: Opacity(opacity: 0.3, child: _route(c, color: gold, stroke: 1, endpoints: false)),
          ),
        // Cintas de la medalla
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 30 * u,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.rotate(angle: 0.35, child: Container(width: 10 * u, height: 34 * u, color: const Color(0xFF1D4ED8))),
              SizedBox(width: 6 * u),
              Transform.rotate(angle: -0.35, child: Container(width: 10 * u, height: 34 * u, color: const Color(0xFFDC2626))),
            ],
          ),
        ),
        // Medalla
        Positioned(
          top: 22 * u,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 50 * u,
              height: 50 * u,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color.lerp(gold, Colors.white, 0.45)!, gold, goldDark],
                ),
                border: Border.all(color: Color.lerp(gold, Colors.white, 0.6)!, width: 1.2 * u),
                boxShadow: [BoxShadow(color: gold.withValues(alpha: 0.5), blurRadius: 8 * u)],
              ),
              child: Container(
                margin: EdgeInsets.all(3 * u),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: goldDark.withValues(alpha: 0.6), width: 0.5 * u)),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, color: textOnGold, size: 6 * u),
                    if (c.config.showDistance) ...[
                      Text(c.km, style: c.f(12, color: textOnGold, weight: FontWeight.w900, height: 1)),
                      Text('KM', style: c.f(4, color: textOnGold, spacing: 1)),
                    ] else
                      Text('META', style: c.f(8, color: textOnGold, weight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 77 * u,
          left: 6 * u,
          right: 6 * u,
          child: Column(children: [
            Text(c.title.toUpperCase(), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: c.f(6.5, spacing: 0.3)),
            Text(c.date, style: c.label(2.8, color: gold)),
          ]),
        ),
        Positioned(
          left: 6 * u,
          right: 6 * u,
          bottom: 0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final b in blocks)
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (b.stat != null) ...[
                        FittedBox(fit: BoxFit.scaleDown, child: Text(b.stat!.$2, style: c.f(4.8))),
                        Text(b.stat!.$1, style: c.label(2.2, color: Colors.white60)),
                        SizedBox(height: 1.2 * u),
                      ],
                      Container(
                        height: b.height * u,
                        alignment: Alignment.topCenter,
                        padding: EdgeInsets.only(top: 1.5 * u),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [b.color, Color.lerp(b.color, Colors.black, 0.5)!],
                          ),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(1.5 * u)),
                        ),
                        child: Text('${b.place}', style: c.f(9, color: Colors.black.withValues(alpha: 0.6), weight: FontWeight.w900)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── 6. Dorsal Retro ─────────────────────────

class _Dorsal extends StatelessWidget {
  final CoverContext c;
  const _Dorsal(this.c);

  @override
  Widget build(BuildContext context) {
    final u = c.u;
    final stats = c.stats().take(3).toList();
    const paper = Color(0xFFFAF6EC);
    const ink = Color(0xFF1B1B1B);
    Widget pin() => Container(
          width: 2.6 * u,
          height: 2.6 * u,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFBDBDBD),
            border: Border.all(color: Colors.black26, width: 0.3 * u),
          ),
        );

    return Stack(
      fit: StackFit.expand,
      children: [
        CoverPhotoLayer(style: c.style, fallback: const ColoredBox(color: Color(0xFF2B2D31))),
        Positioned(
          top: 7 * u,
          left: 0,
          right: 0,
          child: Text(c.date, textAlign: TextAlign.center, style: c.label(3, color: Colors.white70, spacing: 0.8)),
        ),
        Align(
          alignment: const Alignment(0, -0.3),
          child: Transform.rotate(
            angle: -0.035,
            child: Container(
              width: 86 * u,
              decoration: BoxDecoration(
                color: paper,
                borderRadius: BorderRadius.circular(2 * u),
                boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 5 * u, offset: Offset(0, 2 * u))],
              ),
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 2.2 * u),
                        decoration: BoxDecoration(
                          color: c.accent,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(2 * u)),
                        ),
                        child: Text(
                          'APP PASOS RUN · ${c.data.date.year}',
                          textAlign: TextAlign.center,
                          style: c.f(4.4, color: coverOnColor(c.accent), spacing: 0.6),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6 * u),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            c.config.showDistance ? c.km : '${c.data.date.day}${c.data.date.month}',
                            style: c.f(34, color: ink, weight: FontWeight.w900, height: 1.05),
                          ),
                        ),
                      ),
                      if (c.config.showDistance) Text('KILÓMETROS', style: c.label(2.6, color: Colors.black54, spacing: 1)),
                      SizedBox(height: 1.5 * u),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6 * u),
                        child: Text(
                          c.title.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: c.f(5, color: ink, spacing: 0.3),
                        ),
                      ),
                      SizedBox(height: 2.5 * u),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4 * u),
                        child: SizedBox(height: 0.35 * u, width: double.infinity, child: CustomPaint(painter: _DashedLinePainter(Colors.black38))),
                      ),
                      SizedBox(height: 2.5 * u),
                      if (stats.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (final s in stats)
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Column(children: [
                                    Text(s.$2, style: c.f(5, color: ink)),
                                    Text(s.$1, style: c.label(2.1, color: Colors.black54)),
                                  ]),
                                ),
                              ),
                          ],
                        ),
                      SizedBox(height: 2.5 * u),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 1.4 * u),
                        color: c.accent.withValues(alpha: 0.14),
                        child: Text('CORREDOR OFICIAL', textAlign: TextAlign.center, style: c.label(2.3, color: ink, spacing: 1.2)),
                      ),
                    ],
                  ),
                  Positioned(top: 8 * u, left: 2 * u, child: pin()),
                  Positioned(top: 8 * u, right: 2 * u, child: pin()),
                  Positioned(bottom: 6 * u, left: 2 * u, child: pin()),
                  Positioned(bottom: 6 * u, right: 2 * u, child: pin()),
                ],
              ),
            ),
          ),
        ),
        if (c.showMap)
          Positioned(
            bottom: 6 * u,
            left: 10 * u,
            right: 10 * u,
            height: 30 * u,
            child: _route(c, color: Colors.white, glow: c.accent, stroke: 0.8),
          ),
      ],
    );
  }
}

// ───────────────────────── 7. Foto + Mapa ─────────────────────────

class _FotoMapa extends StatelessWidget {
  final CoverContext c;
  const _FotoMapa(this.c);

  @override
  Widget build(BuildContext context) {
    final u = c.u;
    final split = c.h * 0.55;
    final stats = c.stats();
    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            SizedBox(
              height: split,
              width: double.infinity,
              child: CoverPhotoLayer(
                style: c.style,
                fallback: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [c.accent, Color.lerp(c.accent, Colors.black, 0.7)!],
                    ),
                  ),
                ),
              ),
            ),
            Container(height: 0.8 * u, color: c.accent),
            Expanded(
              child: Container(
                color: const Color(0xFF0E1116),
                padding: EdgeInsets.fromLTRB(5 * u, 9 * u, 5 * u, 5 * u),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: c.showMap
                          ? DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(2 * u),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: _route(c, color: c.accent, glow: c.accent, stroke: 0.9),
                            )
                          : Center(child: Icon(Icons.directions_run, color: c.accent, size: 20 * u)),
                    ),
                    SizedBox(width: 4 * u),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final s in stats.take(4)) ...[
                            Text(s.$1, style: c.label(2.2, color: Colors.white54)),
                            FittedBox(fit: BoxFit.scaleDown, child: Text(s.$2, style: c.f(5.2))),
                            SizedBox(height: 2 * u),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        // Título sobre la foto
        Positioned(
          top: 6 * u,
          left: 6 * u,
          right: 6 * u,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              c.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: c.f(7, weight: FontWeight.w800, shadows: [Shadow(color: Colors.black54, blurRadius: 2 * u)]),
            ),
            Text(c.date, style: c.label(2.8, color: Colors.white)),
          ]),
        ),
        // Badge de distancia sobre el corte
        if (c.config.showDistance)
          Positioned(
            top: split - 6 * u,
            left: 5 * u,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 3.5 * u, vertical: 1.5 * u),
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: BorderRadius.circular(2 * u),
                boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 3 * u)],
              ),
              child: Text('${c.km} KM', style: c.f(7, color: coverOnColor(c.accent), weight: FontWeight.w900)),
            ),
          ),
      ],
    );
  }
}

// ───────────────────────── 8. Atardecer ─────────────────────────

class _Atardecer extends StatelessWidget {
  final CoverContext c;
  const _Atardecer(this.c);

  @override
  Widget build(BuildContext context) {
    final u = c.u;
    final stats = c.stats().take(3).toList();
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [const Color(0xFF2B1055), const Color(0xFF7B2869), c.accent, const Color(0xFFFFD36E)],
      stops: const [0, 0.38, 0.72, 1],
    );
    final shadow = [Shadow(color: const Color(0xFF2B1055).withValues(alpha: 0.6), blurRadius: 3 * u)];
    return Stack(
      fit: StackFit.expand,
      children: [
        CoverPhotoLayer(style: c.style, fallback: DecoratedBox(decoration: BoxDecoration(gradient: gradient))),
        if (c.style.hasPhoto)
          Opacity(opacity: 0.55, child: DecoratedBox(decoration: BoxDecoration(gradient: gradient))),
        Positioned(
          top: 20 * u,
          left: 22 * u,
          width: 56 * u,
          height: 56 * u,
          child: CustomPaint(painter: _RetroSunPainter(c.accent)),
        ),
        if (c.showMap)
          Positioned(
            top: 16 * u,
            left: 12 * u,
            right: 12 * u,
            height: 64 * u,
            child: _route(c, color: Colors.white, glow: const Color(0xFF2B1055), stroke: 1, endpoints: false),
          ),
        Positioned(
          top: 6 * u,
          left: 0,
          right: 0,
          child: Text(coverWeekday(c.data.date), textAlign: TextAlign.center, style: c.label(3, color: Colors.white, spacing: 1.5)),
        ),
        Positioned(
          left: 6 * u,
          right: 6 * u,
          bottom: 8 * u,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (c.config.showDistance) ...[
                FittedBox(fit: BoxFit.scaleDown, child: Text(c.km, style: c.f(30, height: 0.9, shadows: shadow))),
                Text('KILÓMETROS', style: c.label(3, color: Colors.white, spacing: 1.5, weight: FontWeight.w800)),
                SizedBox(height: 2 * u),
              ],
              Text(c.title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: c.f(6.5, shadows: shadow)),
              SizedBox(height: 4 * u),
              if (stats.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(vertical: 2.5 * u),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(3 * u),
                    border: Border.all(color: Colors.white38, width: 0.3 * u),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final s in stats)
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(children: [
                              Text(s.$2, style: c.label(3.8, color: Colors.white, weight: FontWeight.w800)),
                              Text(s.$1, style: c.label(2.1, color: Colors.white70)),
                            ]),
                          ),
                        ),
                    ],
                  ),
                ),
              SizedBox(height: 2 * u),
              Text(c.date, style: c.label(2.6, color: Colors.white70)),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Overlays (todas las plantillas) ─────────────────────────

/// Foto pequeña + stickers arrastrables encima de cualquier plantilla.
class CoverOverlays extends StatelessWidget {
  final CoverStyle style;
  final Color accent;

  /// Si no es null, los stickers se pueden arrastrar (solo en el editor).
  final void Function(int index, Alignment alignment)? onStickerMoved;

  const CoverOverlays({super.key, required this.style, required this.accent, this.onStickerMoved});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final u = w / 100;
      final inset = style.insetBytes;
      return Stack(
        fit: StackFit.expand,
        children: [
          if (inset != null)
            Align(
              alignment: style.insetAlignment,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 5 * u, vertical: 14 * u),
                child: Transform.rotate(
                  angle: style.insetAlignment.x > 0 ? 0.06 : -0.06,
                  child: Container(
                    width: 30 * u,
                    height: 30 * u,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.white, width: 1.2 * u),
                      boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 3 * u)],
                    ),
                    child: Image.memory(inset, fit: BoxFit.cover, gaplessPlayback: true),
                  ),
                ),
              ),
            ),
          for (var i = 0; i < style.stickers.length; i++)
            Align(
              alignment: style.stickers[i].alignment,
              child: _sticker(i, u, w, h),
            ),
        ],
      );
    });
  }

  Widget _sticker(int i, double u, double w, double h) {
    final s = style.stickers[i];
    final Widget child = s.isBadge
        ? Transform.rotate(
            angle: -0.08,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 3 * u, vertical: 1.2 * u),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(1.5 * u),
                border: Border.all(color: coverOnColor(accent), width: 0.4 * u),
                boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 2 * u)],
              ),
              child: Text(s.text, style: GoogleFonts.bebasNeue(fontSize: 6 * u, color: coverOnColor(accent), letterSpacing: 0.4 * u)),
            ),
          )
        : Text(s.text, style: TextStyle(fontSize: 13 * u));
    final move = onStickerMoved;
    if (move == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (d) {
        final a = s.alignment;
        move(
          i,
          Alignment(
            (a.x + d.delta.dx / (w * 0.42)).clamp(-1.0, 1.0),
            (a.y + d.delta.dy / (h * 0.45)).clamp(-1.0, 1.0),
          ),
        );
      },
      child: child,
    );
  }
}
