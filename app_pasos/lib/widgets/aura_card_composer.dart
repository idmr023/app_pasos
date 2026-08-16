import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/route_card_template.dart';

class AuraCardComposer {
  static Future<ui.Image> loadImageFromBytes(Uint8List bytes) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }

  static String formatPace(double paceInSecPerKm) {
    if (paceInSecPerKm <= 0) return '--';
    final min = (paceInSecPerKm / 60).floor();
    final sec = (paceInSecPerKm % 60).round();
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  static String formatDuration(int seconds) {
    if (seconds <= 0) return '--';
    final h = (seconds ~/ 3600);
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}min';
  }

  static String formatDistance(double meters) {
    if (meters <= 0) return '0.0';
    return (meters / 1000).toStringAsFixed(1);
  }

  static String getDayOfWeekName(DateTime? date) {
    final d = date ?? DateTime.now();
    switch (d.weekday) {
      case 1: return 'L U N E S';
      case 2: return 'M A R T E S';
      case 3: return 'M I É R C O L E S';
      case 4: return 'J U E V E S';
      case 5: return 'V I E R N E S';
      case 6: return 'S Á B A D O';
      case 7: return 'D O M I N G O';
      default: return 'C A R R E R A';
    }
  }

  static String formatDateShort(DateTime? date) {
    final d = date ?? DateTime.now();
    final months = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class AuraCardPainter extends CustomPainter {
  final ui.Image? mapImage;
  final Map<String, dynamic> stats;
  final RouteCardTemplate template;
  final AuraMetricsConfig metricsConfig;
  final bool drawContent;

  AuraCardPainter({
    this.mapImage,
    required this.stats,
    required this.template,
    this.metricsConfig = const AuraMetricsConfig(),
    this.drawContent = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (metricsConfig.showMap) {
      _drawMapBackground(canvas, size);
    } else {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = template.backgroundColor,
      );
    }
    if (!drawContent) return;

    switch (template.type) {
      case TemplateType.cartografo:
        _drawCartografoLayout(canvas, size);
        break;
      case TemplateType.diario:
        _drawDiarioLayout(canvas, size);
        break;
      case TemplateType.timeline:
        _drawTimelineLayout(canvas, size);
        break;
      case TemplateType.distanciaRey:
      case TemplateType.cyberHud:
        // Estos moldes se construyen con widgets propios, no con este painter.
        break;
    }
  }

  void _drawMapBackground(Canvas canvas, Size size) {
    if (mapImage != null) {
      final rect = Rect.fromLTWH(0, 0, size.width, size.height);
      final srcRect = Rect.fromLTWH(0, 0, mapImage!.width.toDouble(), mapImage!.height.toDouble());
      canvas.drawImageRect(mapImage!, srcRect, rect, Paint());
    } else {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = template.backgroundColor);
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position,
    TextStyle style, {
    TextAlign align = TextAlign.left,
    double maxWidth = 800,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
    );
    tp.layout(maxWidth: maxWidth);
    tp.paint(canvas, position);
  }

  /// MOLDE 1: "El Cartógrafo" — Minimalismo puro.
  /// Sin títulos de marca, sin caja: los datos flotan sobre el mapa 3D.
  void _drawCartografoLayout(Canvas canvas, Size size) {
    // Sombreado inferior sutil SOLO para legibilidad del texto (no es una caja)
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
        stops: const [0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), gradientPaint);

    final km = AuraCardComposer.formatDistance((stats['distance'] ?? 0).toDouble());
    final pace = stats['pace'] as String? ?? '--';
    final dur = stats['duration'] as String? ?? '--';
    final elev = stats['elevationGain'] != null ? '+${(stats['elevationGain'] ?? 0).toInt()}m' : null;
    final cal = (stats['calories'] ?? 0) > 0 ? '${stats['calories']} kcal' : null;

    double cursorY = size.height * 0.70;

    // Kilómetros reducidos: ya no tapan el resto de los datos
    if (metricsConfig.showDistance) {
      _drawText(
        canvas,
        '$km KM',
        Offset(size.width * 0.08, cursorY),
        const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1),
      );
      cursorY += 58;
    }

    // Métricas en UNA sola fila flotante, texto limpio sin contenedor
    final items = <Map<String, String>>[
      if (metricsConfig.showPace && pace != '--') {'val': pace, 'lbl': 'RITMO /KM'},
      if (metricsConfig.showTime && dur != '--') {'val': dur, 'lbl': 'TIEMPO'},
      if (metricsConfig.showElevation && elev != null) {'val': elev, 'lbl': 'ELEVACIÓN'},
      if (metricsConfig.showCalories && cal != null) {'val': cal, 'lbl': 'CALORÍAS'},
    ];

    if (items.isNotEmpty) {
      cursorY += 12;
      final colWidth = (size.width * 0.84) / items.length.clamp(1, 4);
      for (int i = 0; i < items.length; i++) {
        final x = size.width * 0.08 + i * colWidth;
        _drawText(canvas, items[i]['val']!, Offset(x, cursorY),
            const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white));
        _drawText(canvas, items[i]['lbl']!, Offset(x, cursorY + 20),
            const TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.white54, letterSpacing: 1.2));
      }
    }
  }

  /// MOLDE 2: "El Diario" — Editorial.
  /// Día gigante sin cortes; datos técnicos apilados: Ritmo y debajo Tiempo.
  void _drawDiarioLayout(Canvas canvas, Size size) {
    final darkOverlay = Paint()..color = Colors.black.withValues(alpha: 0.55);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), darkOverlay);

    final DateTime? date = stats['startDate'] != null ? DateTime.tryParse(stats['startDate']) : null;
    final dayName = AuraCardComposer.getDayOfWeekName(date);
    final dateStr = AuraCardComposer.formatDateShort(date);

    _drawText(
      canvas,
      'VOL. 01 — RUNNING MAGAZINE',
      Offset(size.width * 0.08, size.height * 0.05),
      const TextStyle(fontSize: 10, fontWeight: FontWeight.w400, color: Colors.white54, letterSpacing: 4),
    );

    // Día gigante: se auto-ajusta al ancho disponible para nunca cortarse
    double dayFontSize = 56;
    TextPainter dayPainter = TextPainter(textDirection: TextDirection.ltr, maxLines: 1);
    while (dayFontSize > 20) {
      dayPainter.text = TextSpan(
        text: dayName,
        style: TextStyle(fontSize: dayFontSize, fontWeight: FontWeight.w300, color: Colors.white, letterSpacing: 4),
      );
      dayPainter.layout(maxWidth: size.width * 0.84);
      if (!dayPainter.didExceedMaxLines) break;
      dayFontSize -= 4;
    }
    final dayY = size.height * 0.11;
    dayPainter.paint(canvas, Offset(size.width * 0.08, dayY));

    final lineY = dayY + dayPainter.height + 14;
    final linePaint = Paint()..color = Colors.white.withValues(alpha: 0.3)..strokeWidth = 1;
    canvas.drawLine(Offset(size.width * 0.08, lineY), Offset(size.width * 0.92, lineY), linePaint);

    double cursorY = lineY + 20;

    if (metricsConfig.showDistance) {
      final km = AuraCardComposer.formatDistance((stats['distance'] ?? 0).toDouble());
      _drawText(canvas, '$km KM', Offset(size.width * 0.08, cursorY),
          const TextStyle(fontSize: 52, fontWeight: FontWeight.w200, color: Colors.white, letterSpacing: -2));
      cursorY += 76;
    }

    _drawText(canvas, dateStr, Offset(size.width * 0.08, cursorY),
        const TextStyle(fontSize: 13, fontWeight: FontWeight.w300, color: Colors.white70, letterSpacing: 2));
    cursorY += 30;

    // Datos técnicos agrupados: TIEMPO justo debajo de RITMO, mismo eje X
    final pace = stats['pace'] as String? ?? '--';
    final dur = stats['duration'] as String? ?? '--';
    const statStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w300, color: Colors.white54, letterSpacing: 2);

    if (metricsConfig.showPace && pace != '--') {
      _drawText(canvas, 'RITMO $pace /km', Offset(size.width * 0.08, cursorY), statStyle);
      cursorY += 22;
    }
    if (metricsConfig.showTime && dur != '--') {
      _drawText(canvas, 'TIEMPO $dur', Offset(size.width * 0.08, cursorY), statStyle);
      cursorY += 22;
    }
    if (metricsConfig.showCalories && (stats['calories'] ?? 0) > 0) {
      _drawText(canvas, 'CALORÍAS ${stats['calories']}', Offset(size.width * 0.08, cursorY), statStyle);
    }
  }

  /// MOLDE 5: "Línea de Tiempo" — Infografía vertical con hitos.
  void _drawTimelineLayout(Canvas canvas, Size size) {
    final darkOverlay = Paint()..color = Colors.black;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), darkOverlay);

    const accentColor = Color(0xFF38BDF8);

    _drawText(
      canvas,
      'CARRERA // STORYTELLING',
      Offset(size.width * 0.08, size.height * 0.05),
      const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accentColor, letterSpacing: 3),
    );

    final km = AuraCardComposer.formatDistance((stats['distance'] ?? 0).toDouble());
    if (metricsConfig.showDistance) {
      _drawText(
        canvas,
        '$km KM',
        Offset(size.width * 0.08, size.height * 0.10),
        const TextStyle(fontSize: 52, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -2),
      );
    }

    final lineX = size.width * 0.15;
    final startY = size.height * 0.28;
    final endY = size.height * 0.85;

    final timelinePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.5)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(lineX, startY), Offset(lineX, endY), timelinePaint);

    final pace = stats['pace'] as String? ?? '--';
    final dur = stats['duration'] as String? ?? '--';

    final events = <Map<String, String>>[
      {'time': '00:00', 'title': 'INICIO', 'desc': 'Salida de ruta'},
      if (metricsConfig.showPace && pace != '--')
        {'time': '$pace /km', 'title': 'PACE MÁXIMO', 'desc': 'Ritmo sostenido'},
      if (metricsConfig.showTime && dur != '--')
        {'time': dur, 'title': 'META', 'desc': 'Entrenamiento completado'},
    ];

    if (events.length < 2) {
      events.add({'time': '$km KM', 'title': 'META', 'desc': 'Entrenamiento completado'});
    }

    final stepY = events.length > 1 ? (endY - startY) / (events.length - 1) : 0.0;

    for (int i = 0; i < events.length; i++) {
      final event = events[i];
      final eventY = startY + i * stepY;

      final nodePaint = Paint()..color = accentColor.withValues(alpha: 0.7);
      canvas.drawCircle(Offset(lineX, eventY), 14, nodePaint);
      canvas.drawCircle(Offset(lineX, eventY), 7, Paint()..color = Colors.white);

      final glowPaint = Paint()
        ..color = accentColor.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(lineX, eventY), 10, glowPaint);

      final double textX = lineX + 30;
      _drawText(
        canvas,
        event['time']!,
        Offset(textX, eventY - 18),
        const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accentColor, letterSpacing: 1.5),
      );
      _drawText(
        canvas,
        event['title']!,
        Offset(textX, eventY - 2),
        const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
      );
      _drawText(
        canvas,
        event['desc']!,
        Offset(textX, eventY + 16),
        const TextStyle(fontSize: 10, color: Colors.white54),
      );
    }

    _drawText(
      canvas,
      'APP PASOS • DATA STORY',
      Offset(size.width * 0.08, size.height * 0.94),
      const TextStyle(fontSize: 10, color: Colors.white54, letterSpacing: 2),
    );
  }

  @override
  bool shouldRepaint(AuraCardPainter oldDelegate) =>
      mapImage != oldDelegate.mapImage || template != oldDelegate.template || metricsConfig != oldDelegate.metricsConfig;
}

/// Painter decorativo del molde Cyber HUD (crosshairs + esquinas).
class CyberHudPainter extends CustomPainter {
  final Color primaryColor;
  final Color accentColor;

  CyberHudPainter({required this.primaryColor, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paintHud = Paint()
      ..color = primaryColor.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const margin = 20.0;
    const corner = 24.0;

    canvas.drawPath(Path()..moveTo(margin, margin + corner)..lineTo(margin, margin)..lineTo(margin + corner, margin), paintHud);
    canvas.drawPath(Path()..moveTo(size.width - margin - corner, margin)..lineTo(size.width - margin, margin)..lineTo(size.width - margin, margin + corner), paintHud);
    canvas.drawPath(Path()..moveTo(margin, size.height - margin - corner)..lineTo(margin, size.height - margin)..lineTo(margin + corner, size.height - margin), paintHud);
    canvas.drawPath(Path()..moveTo(size.width - margin - corner, size.height - margin)..lineTo(size.width - margin, size.height - margin)..lineTo(size.width - margin, size.height - margin - corner), paintHud);

    final crossPaint = Paint()..color = accentColor.withValues(alpha: 0.3)..strokeWidth = 0.8;
    final center = Offset(size.width / 2, size.height * 0.35);
    canvas.drawLine(Offset(center.dx - 20, center.dy), Offset(center.dx + 20, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, center.dy - 20), Offset(center.dx, center.dy + 20), crossPaint);
    canvas.drawCircle(center, 35, crossPaint);
  }

  @override
  bool shouldRepaint(covariant CyberHudPainter oldDelegate) => false;
}
