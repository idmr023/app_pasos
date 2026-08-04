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
    if (meters <= 0) return '--';
    return (meters / 1000).toStringAsFixed(1);
  }
}

class AuraCardPainter extends CustomPainter {
  final ui.Image? mapImage;
  final Map<String, dynamic> stats;
  final RouteCardTemplate template;
  final double devicePixelRatio;

  AuraCardPainter({
    this.mapImage,
    required this.stats,
    required this.template,
    this.devicePixelRatio = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawMapBackground(canvas, size);
    _drawOverlayGradient(canvas, size);
    switch (template.layoutType) {
      case 'cyberpunk':
        _drawCyberpunkLayout(canvas, size);
        break;
      case 'titan':
        _drawTitanLayout(canvas, size);
        break;
      case 'encuadre':
        _drawEncuadreLayout(canvas, size);
        break;
      case 'caligrafia':
        _drawCaligrafiaLayout(canvas, size);
        break;
      case 'semanal':
        _drawSemanalLayout(canvas, size);
        break;
      case 'split':
        _drawSplitLayout(canvas, size);
        break;
      case 'dashboard':
        _drawDashboardLayout(canvas, size);
        break;
      case 'pulse':
        _drawPulseLayout(canvas, size);
        break;
      case 'minimal':
        _drawMinimalLayout(canvas, size);
        break;
      case 'cinematic':
        _drawCinematicLayout(canvas, size);
        break;
    }
  }

  void _drawMapBackground(Canvas canvas, Size size) {
    if (mapImage != null) {
      final rect = Rect.fromLTWH(0, 0, size.width, size.height);
      canvas.drawImageRect(mapImage!, Rect.fromLTWH(0, 0, mapImage!.width.toDouble(), mapImage!.height.toDouble()), rect, Paint());
    } else {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = template.backgroundColor);
      final center = Offset(size.width / 2, size.height / 2);
      final textPainter = TextPainter(text: TextSpan(text: 'Cargando mapa...', style: TextStyle(color: Colors.white24, fontSize: 16)), textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));
    }
  }

  void _drawOverlayGradient(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.black.withValues(alpha: 0.0), Colors.black.withValues(alpha: 0.3), Colors.black.withValues(alpha: 0.6), Colors.black.withValues(alpha: 0.85)],
        stops: const [0.0, 0.3, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  void _drawText(Canvas canvas, String text, Offset position, TextStyle style, {TextAlign align = TextAlign.left}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
    );
    tp.layout(maxWidth: 400);
    tp.paint(canvas, position);
  }

  void _drawGlowText(Canvas canvas, String text, Offset position, TextStyle style, Color glowColor, double glowRadius) {
    canvas.saveLayer(
      Rect.fromLTWH(position.dx - glowRadius, position.dy - glowRadius, 400 + glowRadius * 2, 200),
      Paint(),
    );
    final glowStyle = style.copyWith(color: glowColor.withValues(alpha: 0.3));
    final glowTp = TextPainter(text: TextSpan(text: text, style: glowStyle), textDirection: TextDirection.ltr);
    glowTp.layout(maxWidth: 400);
    glowTp.paint(canvas, position);
    canvas.restore();
    final mainTp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr);
    mainTp.layout(maxWidth: 400);
    mainTp.paint(canvas, position);
  }

  void _drawCyberpunkLayout(Canvas canvas, Size size) {
    final km = AuraCardComposer.formatDistance((stats['distance'] ?? 0).toDouble());
    final pace = AuraCardComposer.formatPace((stats['averagePace'] ?? 0).toDouble());
    final dur = AuraCardComposer.formatDuration((stats['duration'] ?? 0).toInt());
    final elev = '${(stats['elevationGain'] ?? 0).toInt()}m';

    final panelRect = RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.08, size.height * 0.62, size.width * 0.84, size.height * 0.28), const Radius.circular(20));
    final panelPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.02)],
      ).createShader(panelRect.outerRect);
    canvas.drawRRect(panelRect, panelPaint);
    canvas.drawRRect(panelRect, Paint()..style = PaintingStyle.stroke..color = template.accentColor.withValues(alpha: 0.2)..strokeWidth = 1);

    _drawGlowText(canvas, km, Offset(size.width * 0.15, size.height * 0.64), template.kmValueStyle, template.glowColor, 12);
    _drawText(canvas, 'KM', Offset(size.width * 0.15, size.height * 0.64 + 80), template.kmLabelStyle);

    _drawGlowText(canvas, pace, Offset(size.width * 0.55, size.height * 0.64), template.paceValueStyle, template.glowColor, 8);
    _drawText(canvas, '/km', Offset(size.width * 0.55, size.height * 0.64 + 36), template.statLabelStyle);

    _drawText(canvas, dur, Offset(size.width * 0.15, size.height * 0.80), template.statValueStyle);
    _drawText(canvas, 'TIEMPO', Offset(size.width * 0.15, size.height * 0.80 + 28), template.statLabelStyle);

    _drawText(canvas, elev, Offset(size.width * 0.55, size.height * 0.80), template.statValueStyle);
    _drawText(canvas, 'ELEVACIÓN', Offset(size.width * 0.55, size.height * 0.80 + 28), template.statLabelStyle);

    if (stats['title'] != null && (stats['title'] as String).isNotEmpty) {
      _drawText(canvas, stats['title'], Offset(size.width * 0.08, size.height * 0.06), template.titleStyle.copyWith(fontSize: 16, color: Colors.white54));
    }
    _drawText(canvas, 'app pasos', Offset(size.width * 0.08, size.height * 0.94), TextStyle(fontSize: 11, color: Colors.white24, letterSpacing: 2));
  }

  void _drawTitanLayout(Canvas canvas, Size size) {
    final km = AuraCardComposer.formatDistance((stats['distance'] ?? 0).toDouble());
    final dur = AuraCardComposer.formatDuration((stats['duration'] ?? 0).toInt());
    final elev = '${(stats['elevationGain'] ?? 0).toInt()}m';

    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.38, size.width, 2), Paint()..color = Colors.white.withValues(alpha: 0.08));

    _drawText(canvas, km, Offset(size.width * 0.08, size.height * 0.42), template.kmValueStyle);
    _drawText(canvas, 'KILÓMETROS', Offset(size.width * 0.08, size.height * 0.42 + 100), template.kmLabelStyle);
    _drawText(canvas, dur, Offset(size.width * 0.08, size.height * 0.72), template.statValueStyle);
    _drawText(canvas, 'duración', Offset(size.width * 0.08, size.height * 0.72 + 28), template.statLabelStyle);

    _drawText(canvas, elev, Offset(size.width * 0.75, size.height * 0.88), template.statValueStyle.copyWith(fontSize: 16, color: Colors.white38));
    _drawText(canvas, 'elev.', Offset(size.width * 0.75 + 60, size.height * 0.88), template.statLabelStyle.copyWith(fontSize: 10));
    _drawText(canvas, 'app pasos', Offset(size.width * 0.08, size.height * 0.94), TextStyle(fontSize: 11, color: Colors.white24, letterSpacing: 2));
  }

  void _drawEncuadreLayout(Canvas canvas, Size size) {
    final km = AuraCardComposer.formatDistance((stats['distance'] ?? 0).toDouble());
    final pace = AuraCardComposer.formatPace((stats['averagePace'] ?? 0).toDouble());
    final dur = AuraCardComposer.formatDuration((stats['duration'] ?? 0).toInt());
    final elev = '${(stats['elevationGain'] ?? 0).toInt()}m';

    final margin = size.width * 0.04;
    final borderPaint = Paint()..style = PaintingStyle.stroke..color = template.primaryTextColor.withValues(alpha: 0.15)..strokeWidth = 1.5;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(margin, margin, size.width - margin * 2, size.height - margin * 2), const Radius.circular(16)), borderPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(margin * 2, margin * 2, size.width - margin * 4, size.height - margin * 4), const Radius.circular(12)), borderPaint);

    final panelW = (size.width - margin * 6) / 2;
    final panelY = size.height * 0.60;

    final p1 = RRect.fromRectAndRadius(Rect.fromLTWH(margin * 3, panelY, panelW, 90), const Radius.circular(10));
    canvas.drawRRect(p1, Paint()..color = template.primaryTextColor.withValues(alpha: 0.05));
    canvas.drawRRect(p1, Paint()..style = PaintingStyle.stroke..color = template.primaryTextColor.withValues(alpha: 0.1)..strokeWidth = 1);
    _drawText(canvas, km, Offset(margin * 3.5, panelY + 12), template.kmValueStyle.copyWith(fontSize: 32));
    _drawText(canvas, 'km', Offset(margin * 3.5, panelY + 48), template.kmLabelStyle);

    final p2 = RRect.fromRectAndRadius(Rect.fromLTWH(margin * 3 + panelW + margin, panelY, panelW, 90), const Radius.circular(10));
    canvas.drawRRect(p2, Paint()..color = template.primaryTextColor.withValues(alpha: 0.05));
    canvas.drawRRect(p2, Paint()..style = PaintingStyle.stroke..color = template.primaryTextColor.withValues(alpha: 0.1)..strokeWidth = 1);
    _drawText(canvas, pace, Offset(margin * 3 + panelW + margin + 12, panelY + 12), template.paceValueStyle.copyWith(fontSize: 28));
    _drawText(canvas, '/km', Offset(margin * 3 + panelW + margin + 12, panelY + 48), template.statLabelStyle);

    final p3 = RRect.fromRectAndRadius(Rect.fromLTWH(margin * 3, panelY + 110, panelW, 90), const Radius.circular(10));
    canvas.drawRRect(p3, Paint()..color = template.primaryTextColor.withValues(alpha: 0.05));
    _drawText(canvas, dur, Offset(margin * 3.5, panelY + 122), template.statValueStyle);
    _drawText(canvas, 'tiempo', Offset(margin * 3.5, panelY + 158), template.statLabelStyle);

    final p4 = RRect.fromRectAndRadius(Rect.fromLTWH(margin * 3 + panelW + margin, panelY + 110, panelW, 90), const Radius.circular(10));
    canvas.drawRRect(p4, Paint()..color = template.primaryTextColor.withValues(alpha: 0.05));
    _drawText(canvas, elev, Offset(margin * 3 + panelW + margin + 12, panelY + 122), template.statValueStyle);
    _drawText(canvas, 'elevación', Offset(margin * 3 + panelW + margin + 12, panelY + 158), template.statLabelStyle);

    if (stats['title'] != null && (stats['title'] as String).isNotEmpty) {
      _drawText(canvas, stats['title'], Offset(margin * 3, size.height * 0.05), template.titleStyle);
    }
    _drawText(canvas, 'app pasos', Offset(margin * 3, size.height * 0.94), TextStyle(fontSize: 11, color: Colors.black38, letterSpacing: 2));
  }

  void _drawCaligrafiaLayout(Canvas canvas, Size size) {
    final km = AuraCardComposer.formatDistance((stats['distance'] ?? 0).toDouble());
    final pace = AuraCardComposer.formatPace((stats['averagePace'] ?? 0).toDouble());
    final dur = AuraCardComposer.formatDuration((stats['duration'] ?? 0).toInt());

    final accentPaint = Paint()..color = template.accentColor.withValues(alpha: 0.15);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.15), 100, accentPaint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.15), 60, Paint()..color = template.accentColor.withValues(alpha: 0.08));

    if (stats['title'] != null && (stats['title'] as String).isNotEmpty) {
      _drawText(canvas, stats['title'], Offset(size.width * 0.10, size.height * 0.10), template.titleStyle);
    }
    _drawText(canvas, km, Offset(size.width * 0.10, size.height * 0.28), template.kmValueStyle);
    _drawText(canvas, 'kilómetros', Offset(size.width * 0.10, size.height * 0.28 + 60), template.kmLabelStyle);

    _drawText(canvas, pace, Offset(size.width * 0.10, size.height * 0.55), template.paceValueStyle);
    _drawText(canvas, 'ritmo promedio', Offset(size.width * 0.10 + 80, size.height * 0.55 + 4), template.statLabelStyle);

    _drawText(canvas, dur, Offset(size.width * 0.10, size.height * 0.68), template.statValueStyle);
    _drawText(canvas, 'duración', Offset(size.width * 0.10 + 80, size.height * 0.68 + 4), template.statLabelStyle);

    _drawText(canvas, 'app pasos', Offset(size.width * 0.10, size.height * 0.92), TextStyle(fontSize: 11, color: Colors.black38, letterSpacing: 2));
  }

  void _drawSemanalLayout(Canvas canvas, Size size) {
    final km = AuraCardComposer.formatDistance((stats['distance'] ?? 0).toDouble());
    final dur = AuraCardComposer.formatDuration((stats['duration'] ?? 0).toInt());
    final elev = '${(stats['elevationGain'] ?? 0).toInt()}m';

    _drawText(canvas, 'RESUMEN', Offset(size.width * 0.08, size.height * 0.06), template.titleStyle);
    _drawText(canvas, 'SEMANA', Offset(size.width * 0.08, size.height * 0.06 + 24), template.kmLabelStyle);

    _drawText(canvas, km, Offset(size.width * 0.08, size.height * 0.15), template.kmValueStyle);
    _drawText(canvas, 'km totales', Offset(size.width * 0.08, size.height * 0.15 + 56), template.kmLabelStyle);

    final barW = (size.width - size.width * 0.16) / 7;
    final barMaxH = size.height * 0.12;
    final barBottom = size.height * 0.44;
    final days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final values = [3.2, 5.1, 0.0, 6.8, 4.5, 12.4, 2.1];
    final maxVal = 12.4;

    for (int i = 0; i < 7; i++) {
      final x = size.width * 0.08 + i * barW + 4;
      final h = maxVal > 0 ? (values[i] / maxVal) * barMaxH : 0.0;
      final barPaint = Paint()
        ..color = h > 0 ? template.accentColor.withValues(alpha: 0.3 + (values[i] / maxVal) * 0.5) : Colors.white.withValues(alpha: 0.05);
      if (values[i] == maxVal) barPaint.color = template.accentColor;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, barBottom - h, barW - 8.0, h == 0 ? 2.0 : h), const Radius.circular(3)), barPaint);
      _drawText(canvas, days[i], Offset(x, barBottom + 6), TextStyle(fontSize: 10, color: values[i] > 0 ? template.secondaryTextColor : Colors.white24));
      if (values[i] > 0) {
        _drawText(canvas, values[i].toStringAsFixed(1), Offset(x - 4, barBottom - h - 18), TextStyle(fontSize: 8, color: template.secondaryTextColor));
      }
    }

    _drawText(canvas, dur, Offset(size.width * 0.08, size.height * 0.55), template.statValueStyle);
    _drawText(canvas, 'tiempo total', Offset(size.width * 0.08, size.height * 0.55 + 28), template.statLabelStyle);
    _drawText(canvas, elev, Offset(size.width * 0.50, size.height * 0.55), template.statValueStyle);
    _drawText(canvas, 'desnivel', Offset(size.width * 0.50, size.height * 0.55 + 28), template.statLabelStyle);

    _drawText(canvas, 'app pasos', Offset(size.width * 0.08, size.height * 0.94), TextStyle(fontSize: 11, color: Colors.white24, letterSpacing: 2));
  }

  void _drawSplitLayout(Canvas canvas, Size size) {
    final km = AuraCardComposer.formatDistance((stats['distance'] ?? 0).toDouble());
    final dur = AuraCardComposer.formatDuration((stats['duration'] ?? 0).toInt());

    _drawText(canvas, 'SPLITS', Offset(size.width * 0.08, size.height * 0.06), template.titleStyle);
    _drawText(canvas, '$km km', Offset(size.width * 0.08, size.height * 0.14), template.kmValueStyle.copyWith(fontSize: 28));
    _drawText(canvas, 'total', Offset(size.width * 0.08 + 100, size.height * 0.14 + 6), template.statLabelStyle);

    final splits = [
      {'km': 1, 'pace': '4:52', 'elev': 12},
      {'km': 2, 'pace': '5:01', 'elev': 18},
      {'km': 3, 'pace': '4:48', 'elev': 8},
      {'km': 4, 'pace': '5:12', 'elev': 25},
      {'km': 5, 'pace': '4:38', 'elev': 6},
    ];

    final startY = size.height * 0.26;
    final rowH = (size.height * 0.50) / splits.length;

    for (int i = 0; i < splits.length; i++) {
      final y = startY + i * rowH;
      if (i % 2 == 0) {
        canvas.drawRect(Rect.fromLTWH(size.width * 0.08, y, size.width * 0.84, rowH), Paint()..color = Colors.white.withValues(alpha: 0.03));
      }
      _drawText(canvas, '${splits[i]['km']}', Offset(size.width * 0.10, y + 12), TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.white38));
      _drawText(canvas, 'KM', Offset(size.width * 0.14, y + 14), TextStyle(fontSize: 8, color: Colors.white24));
      _drawText(canvas, '${splits[i]['pace']}', Offset(size.width * 0.40, y + 12), TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: template.paceValueStyle.color));
      _drawText(canvas, '+${splits[i]['elev']}m', Offset(size.width * 0.72, y + 14), TextStyle(fontSize: 12, color: Colors.white38));
    }

    _drawText(canvas, dur, Offset(size.width * 0.08, size.height * 0.86), template.statValueStyle);
    _drawText(canvas, 'tiempo', Offset(size.width * 0.08 + 60, size.height * 0.86 + 4), template.statLabelStyle);
    _drawText(canvas, 'app pasos', Offset(size.width * 0.08, size.height * 0.94), TextStyle(fontSize: 11, color: Colors.white24, letterSpacing: 2));
  }

  void _drawDashboardLayout(Canvas canvas, Size size) {
    final km = AuraCardComposer.formatDistance((stats['distance'] ?? 0).toDouble());
    final pace = AuraCardComposer.formatPace((stats['averagePace'] ?? 0).toDouble());
    final dur = AuraCardComposer.formatDuration((stats['duration'] ?? 0).toInt());
    final elev = '${(stats['elevationGain'] ?? 0).toInt()}m';
    final hr = '${stats['averageHeartRate'] ?? 0}';
    final cal = '${stats['calories'] ?? 0}';

    _drawText(canvas, 'DASHBOARD', Offset(size.width * 0.08, size.height * 0.06), template.titleStyle);

    final panels = [
      {'label': 'DISTANCIA', 'value': '$km km'},
      {'label': 'RITMO', 'value': pace},
      {'label': 'DURACIÓN', 'value': dur},
      {'label': 'ELEVACIÓN', 'value': elev},
      {'label': 'FC MEDIA', 'value': '$hr bpm'},
      {'label': 'CALORÍAS', 'value': cal},
    ];

    final cols = 3;
    final panelW = (size.width - size.width * 0.20) / cols;
    final panelH = size.height * 0.12;
    final startX = size.width * 0.08;
    final startY = size.height * 0.16;
    final gapX = size.width * 0.02;
    final gapY = size.height * 0.02;

    for (int i = 0; i < panels.length; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      final x = startX + col * (panelW + gapX);
      final y = startY + row * (panelH + gapY);

      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, panelW, panelH), const Radius.circular(10));
      canvas.drawRRect(rect, Paint()..color = Colors.white.withValues(alpha: 0.04));
      _drawText(canvas, panels[i]['value']!, Offset(x + 12, y + 12), template.kmValueStyle.copyWith(fontSize: 20));
      _drawText(canvas, panels[i]['label']!, Offset(x + 12, y + 40), template.statLabelStyle.copyWith(fontSize: 9));
    }

    _drawText(canvas, 'app pasos', Offset(size.width * 0.08, size.height * 0.94), TextStyle(fontSize: 11, color: Colors.white24, letterSpacing: 2));
  }

  void _drawPulseLayout(Canvas canvas, Size size) {
    final km = AuraCardComposer.formatDistance((stats['distance'] ?? 0).toDouble());
    final pace = AuraCardComposer.formatPace((stats['averagePace'] ?? 0).toDouble());
    final dur = AuraCardComposer.formatDuration((stats['duration'] ?? 0).toInt());
    final hr = '${stats['averageHeartRate'] ?? 0}';
    final maxHr = '${stats['maxHeartRate'] ?? 0}';

    _drawGlowText(canvas, hr, Offset(size.width * 0.08, size.height * 0.10), TextStyle(fontSize: 64, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -2), const Color(0xFFEF4444), 20);
    _drawText(canvas, 'bpm', Offset(size.width * 0.08, size.height * 0.10 + 72), TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Color(0xFFFCA5A5), letterSpacing: 2));

    final wavePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [const Color(0xFFEF4444).withValues(alpha: 0.3), const Color(0xFFEF4444).withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 50));
    final wavePath = Path();
    wavePath.moveTo(0, size.height * 0.45);
    wavePath.cubicTo(size.width * 0.15, size.height * 0.35, size.width * 0.35, size.height * 0.55, size.width * 0.5, size.height * 0.38);
    wavePath.cubicTo(size.width * 0.65, size.height * 0.20, size.width * 0.85, size.height * 0.50, size.width, size.height * 0.32);
    wavePath.lineTo(size.width, size.height * 0.50);
    wavePath.lineTo(0, size.height * 0.50);
    wavePath.close();
    canvas.drawPath(wavePath, wavePaint);

    _drawText(canvas, '$km km', Offset(size.width * 0.08, size.height * 0.56), template.kmValueStyle);
    _drawText(canvas, 'distancia', Offset(size.width * 0.08, size.height * 0.56 + 52), template.kmLabelStyle);
    _drawText(canvas, pace, Offset(size.width * 0.55, size.height * 0.56), template.paceValueStyle);
    _drawText(canvas, 'ritmo', Offset(size.width * 0.55, size.height * 0.56 + 52), template.statLabelStyle);
    _drawText(canvas, dur, Offset(size.width * 0.08, size.height * 0.74), template.statValueStyle);
    _drawText(canvas, 'duración', Offset(size.width * 0.08, size.height * 0.74 + 28), template.statLabelStyle);
    _drawText(canvas, 'máx $maxHr bpm', Offset(size.width * 0.55, size.height * 0.74), template.statValueStyle.copyWith(fontSize: 16));
    _drawText(canvas, 'frecuencia máxima', Offset(size.width * 0.55, size.height * 0.74 + 28), template.statLabelStyle);

    _drawText(canvas, 'app pasos', Offset(size.width * 0.08, size.height * 0.94), TextStyle(fontSize: 11, color: Colors.white24, letterSpacing: 2));
  }

  void _drawMinimalLayout(Canvas canvas, Size size) {
    final km = AuraCardComposer.formatDistance((stats['distance'] ?? 0).toDouble());
    final pace = AuraCardComposer.formatPace((stats['averagePace'] ?? 0).toDouble());
    final dur = AuraCardComposer.formatDuration((stats['duration'] ?? 0).toInt());

    if (stats['title'] != null && (stats['title'] as String).isNotEmpty) {
      _drawText(canvas, stats['title'], Offset(size.width * 0.08, size.height * 0.06), template.titleStyle);
    }

    final panelX = size.width * 0.60;
    final panelY = size.height * 0.66;
    final panelW = size.width * 0.34;
    final panelH = size.height * 0.26;
    final panelPaint = Paint()..color = Colors.white.withValues(alpha: 0.06);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(panelX, panelY, panelW, panelH), const Radius.circular(12)), panelPaint);

    _drawText(canvas, km, Offset(panelX + 16, panelY + 16), template.kmValueStyle);
    _drawText(canvas, 'km', Offset(panelX + 16 + (template.kmValueStyle.fontSize ?? 28) * 1.5, panelY + 22), template.kmLabelStyle);
    _drawText(canvas, pace, Offset(panelX + 16, panelY + 56), template.paceValueStyle);
    _drawText(canvas, '/km', Offset(panelX + 16 + 70, panelY + 60), template.statLabelStyle);
    _drawText(canvas, dur, Offset(panelX + 16, panelY + 90), template.statValueStyle);
    _drawText(canvas, 'app pasos', Offset(size.width * 0.08, size.height * 0.94), TextStyle(fontSize: 11, color: Colors.white24, letterSpacing: 2));
  }

  void _drawCinematicLayout(Canvas canvas, Size size) {
    final km = AuraCardComposer.formatDistance((stats['distance'] ?? 0).toDouble());
    final pace = AuraCardComposer.formatPace((stats['averagePace'] ?? 0).toDouble());
    final dur = AuraCardComposer.formatDuration((stats['duration'] ?? 0).toInt());
    final elev = '${(stats['elevationGain'] ?? 0).toInt()}m elev.';

    final bottomGrad = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.black.withValues(alpha: 0.0), Colors.black.withValues(alpha: 0.7), Colors.black.withValues(alpha: 0.9)],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromLTWH(0, size.height * 0.55, size.width, size.height * 0.45));
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.55, size.width, size.height * 0.45), bottomGrad);

    _drawGlowText(canvas, km, Offset(size.width * 0.08, size.height * 0.62), template.kmValueStyle, template.glowColor, 15);
    _drawText(canvas, 'kilómetros', Offset(size.width * 0.08, size.height * 0.62 + 70), template.kmLabelStyle);

    _drawText(canvas, pace, Offset(size.width * 0.55, size.height * 0.62), template.paceValueStyle);
    _drawText(canvas, 'ritmo', Offset(size.width * 0.55, size.height * 0.62 + 32), template.statLabelStyle);

    _drawText(canvas, dur, Offset(size.width * 0.08, size.height * 0.80), template.statValueStyle.copyWith(color: Colors.white));
    _drawText(canvas, 'duración', Offset(size.width * 0.08, size.height * 0.80 + 28), template.statLabelStyle);
    _drawText(canvas, elev, Offset(size.width * 0.55, size.height * 0.80), template.statValueStyle.copyWith(fontSize: 16, color: Color(0xFFFDE68A)));
    _drawText(canvas, 'desnivel', Offset(size.width * 0.55, size.height * 0.80 + 28), template.statLabelStyle);

    if (stats['title'] != null && (stats['title'] as String).isNotEmpty) {
      _drawText(canvas, stats['title'], Offset(size.width * 0.08, size.height * 0.93), template.titleStyle.copyWith(fontSize: 18, color: Colors.white70));
    }
    _drawText(canvas, 'app pasos', Offset(size.width * 0.72, size.height * 0.94), TextStyle(fontSize: 10, color: Colors.white24, letterSpacing: 2));
  }

  @override
  bool shouldRepaint(AuraCardPainter oldDelegate) => mapImage != oldDelegate.mapImage;
}
