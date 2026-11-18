import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'sprint_cosmetics.dart';
import 'sprint_game.dart';

/// Render vectorial del Sprint: estadio nocturno, pista con perspectiva,
/// obstáculos, corredores, partículas y textos flotantes.
///
/// Se repinta escuchando a [SprintGame] (no reconstruye widgets por frame).
/// [skin] y [trail] vienen de lo equipado en la tienda de pasos.
class SprintPainter extends CustomPainter {
  final SprintGame game;
  final SprintSkin skin;
  final SprintTrail? trail;

  SprintPainter(this.game, {this.skin = SprintSkin.classic, this.trail}) : super(repaint: game);

  // Distancia focal de la proyección (metros).
  static const double _focal = 8;
  static const double _nearZ = -2.6;

  static const Color _track = Color(0xFFC2462F);
  static const Color _trackFar = Color(0xFF6E2D2A);
  static const Color _grassA = Color(0xFF1F7A43);
  static const Color _grassB = Color(0xFF1A6B3B);
  static const Color _fog = Color(0xFF2A2550);

  static const List<Color> _rivalJerseys = [
    Color(0xFFEF4444),
    Color(0xFFA855F7),
    Color(0xFFFACC15),
    Color(0xFF14B8A6),
  ];
  static const List<Color> _boardColors = [
    Color(0xFF3B82F6),
    Color(0xFFFF6B35),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
  ];

  static final List<_Dot> _crowd = _buildCrowd();
  static final List<Offset> _stars = _buildStars();

  static List<_Dot> _buildCrowd() {
    final rng = math.Random(3);
    return List.generate(260, (_) => _Dot(rng.nextDouble(), rng.nextDouble(), rng.nextInt(6), rng.nextDouble()));
  }

  static List<Offset> _buildStars() {
    final rng = math.Random(11);
    return List.generate(40, (_) => Offset(rng.nextDouble(), rng.nextDouble()));
  }

  // ── Proyección ────────────────────────────────────────────────────
  late double _w, _h, _cx, _horizon, _ground, _laneW, _camX;

  double _p(double z) => _focal / (_focal + math.max(z, -_focal * 0.85));

  /// Punto en pantalla para carril [lane] (continuo), profundidad [z], altura [y].
  Offset _pt(double lane, double z, [double y = 0]) {
    final p = _p(z);
    return Offset(
      _cx + (lane - 1 - _camX) * _laneW * p,
      _horizon + (_ground - _horizon) * p - y * _ppm(z),
    );
  }

  /// Píxeles por metro a profundidad [z]. Un carril mide 2 m.
  double _ppm(double z) => _laneW / 2 * _p(z);

  @override
  void paint(Canvas canvas, Size size) {
    _w = size.width;
    _h = size.height;
    _cx = _w / 2;
    _horizon = _h * 0.30;
    _ground = _h * 0.86;
    _laneW = _w * 0.30;
    _camX = (game.playerX - 1) * 0.35;

    canvas.save();
    if (game.shake > 0) {
      final m = game.shake * 14;
      canvas.translate(math.sin(game.time * 90) * m, math.cos(game.time * 77) * m);
    }

    _drawSky(canvas);
    _drawStadium(canvas);
    _drawGround(canvas);
    _drawTrack(canvas);
    _drawBoards(canvas);
    _drawFog(canvas);
    _drawWorld(canvas);
    _drawParticles(canvas);
    _drawPopups(canvas);
    if (game.isTurbo || game.effectiveSpeed > 30) _drawSpeedLines(canvas);

    canvas.restore();

    if (game.isOver && game.shake > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFFEF4444).withValues(alpha: (game.shake * 0.7).clamp(0.0, 0.35)),
      );
    }
    _drawVignette(canvas, size);
  }

  // ── Fondo ─────────────────────────────────────────────────────────
  void _drawSky(Canvas canvas) {
    final rect = Rect.fromLTWH(-20, -20, _w + 40, _horizon + 20);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF050813), Color(0xFF141B3A), Color(0xFF3A2A5E)],
          stops: [0, 0.6, 1],
        ).createShader(rect),
    );
    final star = Paint()..color = Colors.white;
    for (var i = 0; i < _stars.length; i++) {
      final s = _stars[i];
      final tw = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(game.time * 2 + i));
      star.color = Colors.white.withValues(alpha: 0.5 * tw);
      canvas.drawCircle(Offset(s.dx * _w - _camX * 8, s.dy * _horizon * 0.6), 0.6 + (i % 3) * 0.4, star);
    }
  }

  void _drawStadium(Canvas canvas) {
    final shift = -_camX * _laneW * 0.18;
    final standTop = _horizon - _h * 0.085;

    // Torres de luz (detrás de las gradas)
    for (final fx in [0.1, 0.9]) {
      final x = fx * _w + shift * 0.6;
      final top = _horizon - _h * 0.2;
      canvas.drawRect(Rect.fromLTWH(x - 2, top, 4, _horizon - top), Paint()..color = const Color(0xFF2B3350));
      final lamp = Rect.fromCenter(center: Offset(x, top), width: _w * 0.11, height: _h * 0.022);
      canvas.drawCircle(
        lamp.center,
        _w * 0.2,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFFFF6D5).withValues(alpha: 0.35),
            const Color(0xFFFFF6D5).withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: lamp.center, radius: _w * 0.2)),
      );
      canvas.drawRRect(RRect.fromRectAndRadius(lamp, const Radius.circular(3)), Paint()..color = const Color(0xFFFFF8E1));
    }

    // Gradas
    final stands = Path()
      ..moveTo(-20, _horizon + 2)
      ..lineTo(-20, standTop + _h * 0.02)
      ..quadraticBezierTo(_w / 2 + shift, standTop - _h * 0.025, _w + 20, standTop + _h * 0.02)
      ..lineTo(_w + 20, _horizon + 2)
      ..close();
    canvas.drawPath(
      stands,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B2140), Color(0xFF0E1226)],
        ).createShader(Rect.fromLTWH(0, standTop - _h * 0.03, _w, _horizon - standTop + _h * 0.03)),
    );

    // Público (puntos de colores que "saltan")
    const crowdColors = [
      Color(0xFF3B82F6),
      Color(0xFFFF6B35),
      Color(0xFFF8FAFC),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
    ];
    final dot = Paint();
    final bandH = _horizon - standTop;
    for (final d in _crowd) {
      final x = (d.fx * (_w + 40) - 20 + shift) % (_w + 40) - 20;
      final bounce = math.max(0.0, math.sin(game.time * 6 + d.phase * 20)) * 1.4;
      final y = standTop + 4 + d.fy * (bandH - 8) - bounce;
      dot.color = crowdColors[d.color].withValues(alpha: 0.35 + d.fy * 0.45);
      canvas.drawCircle(Offset(x, y), 1.1 + d.fy * 0.9, dot);
    }
    // Muro del estadio
    canvas.drawRect(
      Rect.fromLTWH(-20, _horizon - 3, _w + 40, 4),
      Paint()..color = const Color(0xFF3B82F6).withValues(alpha: 0.6),
    );
  }

  void _drawGround(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(-20, _horizon, _w + 40, _h - _horizon + 20), Paint()..color = _grassB);
    // Franjas de césped que se desplazan con la distancia (parallax principal)
    const band = 8.0;
    final offset = game.distance % (band * 2);
    final paint = Paint()..color = _grassA;
    for (var z = -offset - band * 2; z < SprintGame.drawFarZ; z += band * 2) {
      final z0 = math.max(z, _nearZ);
      final z1 = z + band;
      if (z1 <= _nearZ) continue;
      final y0 = _pt(1, z0).dy;
      final y1 = _pt(1, z1).dy;
      canvas.drawRect(Rect.fromLTRB(-20, y1, _w + 20, y0), paint);
    }
  }

  void _quad(Canvas canvas, Offset a, Offset b, Offset c, Offset d, Paint paint) {
    canvas.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(c.dx, c.dy)
        ..lineTo(d.dx, d.dy)
        ..close(),
      paint,
    );
  }

  void _drawTrack(Canvas canvas) {
    const far = SprintGame.drawFarZ;
    const edgeL = -0.62, edgeR = 2.62;
    // Bordillo blanco exterior
    _quad(canvas, _pt(edgeL - 0.08, far), _pt(edgeR + 0.08, far), _pt(edgeR + 0.08, _nearZ),
        _pt(edgeL - 0.08, _nearZ), Paint()..color = const Color(0xFFE2E8F0));
    final top = _pt(1, far).dy;
    _quad(
      canvas,
      _pt(edgeL, far),
      _pt(edgeR, far),
      _pt(edgeR, _nearZ),
      _pt(edgeL, _nearZ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [_trackFar, _track],
          stops: const [0, 0.55],
        ).createShader(Rect.fromLTRB(0, top, _w, _h)),
    );

    // Textura: líneas transversales cada 5 m (marcas de distancia)
    final mark = Paint();
    final offset = game.distance % 5;
    for (var z = 5 - offset; z < far; z += 5) {
      final index = ((game.distance + z) / 5).round();
      final strong = index % 10 == 0;
      final w = (strong ? 0.18 : 0.05);
      mark.color = Colors.white.withValues(alpha: strong ? 0.55 : 0.08);
      _quad(canvas, _pt(edgeL, z + w), _pt(edgeR, z + w), _pt(edgeR, z - w), _pt(edgeL, z - w), mark);
    }

    // Líneas de carril
    final line = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (final u in [-0.5, 0.5, 1.5, 2.5]) {
      const hw = 0.035;
      _quad(canvas, _pt(u - hw, far), _pt(u + hw, far), _pt(u + hw, _nearZ), _pt(u - hw, _nearZ), line);
    }
  }

  void _drawBoards(Canvas canvas) {
    const spacing = 14.0, length = 9.0, height = 0.75;
    final offset = game.distance % spacing;
    final boards = <double>[];
    for (var z = SprintGame.drawFarZ - offset; z > _nearZ - spacing; z -= spacing) {
      boards.add(z);
    }
    for (final z in boards) {
      final idx = ((game.distance + z) / spacing).round();
      for (final side in [-1.05, 3.05]) {
        final z0 = math.max(z, _nearZ);
        final z1 = z + length;
        if (z1 <= _nearZ) continue;
        final color = _boardColors[(idx + (side < 0 ? 0 : 2)) % _boardColors.length];
        _quad(canvas, _pt(side, z1, height), _pt(side, z0, height), _pt(side, z0), _pt(side, z1),
            Paint()..color = color.withValues(alpha: 0.9));
        // Franja luminosa
        _quad(canvas, _pt(side, z1, height * 0.62), _pt(side, z0, height * 0.62), _pt(side, z0, height * 0.42),
            _pt(side, z1, height * 0.42), Paint()..color = Colors.white.withValues(alpha: 0.35));
      }
    }
  }

  void _drawFog(Canvas canvas) {
    final rect = Rect.fromLTRB(-20, _horizon - 2, _w + 20, _horizon + _h * 0.09);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_fog.withValues(alpha: 0.85), _fog.withValues(alpha: 0)],
        ).createShader(rect),
    );
  }

  void _drawVignette(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.35)],
          stops: const [0.65, 1],
        ).createShader(rect),
    );
  }

  void _drawSpeedLines(Canvas canvas) {
    final vp = Offset(_cx, _horizon);
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6;
    final color = game.isTurbo ? const Color(0xFF22D3EE) : Colors.white;
    final strength = game.isTurbo ? 0.5 : 0.18;
    for (var i = 0; i < 18; i++) {
      final a = i / 18 * math.pi * 2 + 0.17;
      final t = (game.time * 2.2 + i * 0.37) % 1.0;
      final r0 = _w * (0.55 + t * 0.6);
      final r1 = r0 + _w * 0.12;
      final dir = Offset(math.cos(a), math.sin(a) * 0.8);
      paint.color = color.withValues(alpha: strength * (1 - t));
      canvas.drawLine(vp + dir * r0, vp + dir * r1, paint);
    }
  }

  // ── Mundo (orden por profundidad) ─────────────────────────────────
  void _drawWorld(Canvas canvas) {
    final visible = game.entities
        .where((e) => !e.hidden && e.z < SprintGame.drawFarZ && e.z > _nearZ)
        .toList()
      ..sort((a, b) => b.z.compareTo(a.z));
    var playerDrawn = false;
    for (final e in visible) {
      if (!playerDrawn && e.z <= 0.1) {
        _drawPlayer(canvas);
        playerDrawn = true;
      }
      final fade = ((SprintGame.drawFarZ - e.z) / 18).clamp(0.0, 1.0);
      _drawEntity(canvas, e, fade);
    }
    if (!playerDrawn) _drawPlayer(canvas);
  }

  void _shadow(Canvas canvas, Offset at, double s, double widthM, [double alpha = 0.35]) {
    canvas.drawOval(
      Rect.fromCenter(center: at, width: widthM * s, height: widthM * s * 0.28),
      Paint()..color = Colors.black.withValues(alpha: alpha),
    );
  }

  void _drawEntity(Canvas canvas, SprintEntity e, double fade) {
    final base = _pt(e.lane.toDouble(), e.z);
    final s = _ppm(e.z);
    if (fade < 1) {
      canvas.saveLayer(
        Rect.fromCenter(center: base.translate(0, -1.1 * s), width: 3.2 * s, height: 3.4 * s),
        Paint()..color = Colors.white.withValues(alpha: fade),
      );
    }
    switch (e.kind) {
      case SprintEntityKind.hurdle:
        _drawHurdle(canvas, base, s);
        break;
      case SprintEntityKind.cone:
        _drawCone(canvas, base, s);
        break;
      case SprintEntityKind.rival:
        _shadow(canvas, base, s, 0.8);
        final jersey = _rivalJerseys[(e.seed * _rivalJerseys.length).floor() % _rivalJerseys.length];
        _drawRunner(canvas, base, s, game.time * 13 + e.seed * 10, jersey, const Color(0xFF1F2937),
            const Color(0xFFC58C5C), lean: 0);
        break;
      case SprintEntityKind.coin:
        _drawCoin(canvas, base, s, e.seed);
        break;
      case SprintEntityKind.drink:
        _drawDrink(canvas, base, s, e.seed);
        break;
    }
    if (fade < 1) canvas.restore();
  }

  void _drawHurdle(Canvas canvas, Offset base, double s) {
    _shadow(canvas, base, s, 1.7, 0.25);
    final post = Paint()..color = const Color(0xFFCBD5E1);
    for (final dx in [-0.72, 0.72]) {
      canvas.drawRect(Rect.fromLTWH(base.dx + (dx - 0.04) * s, base.dy - 0.92 * s, 0.08 * s, 0.92 * s), post);
      canvas.drawRect(Rect.fromLTWH(base.dx + (dx - 0.12) * s, base.dy - 0.06 * s, 0.24 * s, 0.06 * s), post);
    }
    final bar = Rect.fromLTWH(base.dx - 0.8 * s, base.dy - 0.98 * s, 1.6 * s, 0.2 * s);
    canvas.drawRRect(RRect.fromRectAndRadius(bar, Radius.circular(0.03 * s)), Paint()..color = Colors.white);
    final stripe = Paint()..color = const Color(0xFF111827);
    for (var i = 0; i < 5; i += 2) {
      canvas.drawRect(Rect.fromLTWH(bar.left + bar.width * (i + 0.5) / 6, bar.top, bar.width / 6, bar.height), stripe);
    }
  }

  void _drawCone(Canvas canvas, Offset base, double s) {
    _shadow(canvas, base, s, 1.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: base.translate(0, -0.05 * s), width: 0.95 * s, height: 0.1 * s), Radius.circular(0.03 * s)),
      Paint()..color = const Color(0xFFC2410C),
    );
    final top = base.translate(0, -1.05 * s);
    final cone = Path()
      ..moveTo(base.dx - 0.4 * s, base.dy - 0.1 * s)
      ..lineTo(top.dx - 0.07 * s, top.dy)
      ..quadraticBezierTo(top.dx, top.dy - 0.05 * s, top.dx + 0.07 * s, top.dy)
      ..lineTo(base.dx + 0.4 * s, base.dy - 0.1 * s)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..shader = const LinearGradient(colors: [Color(0xFFFF8A4C), Color(0xFFEA580C), Color(0xFF9A3412)], stops: [0, 0.55, 1])
            .createShader(Rect.fromLTRB(base.dx - 0.4 * s, top.dy, base.dx + 0.4 * s, base.dy)),
    );
    canvas.save();
    canvas.clipPath(cone);
    canvas.drawRect(Rect.fromLTRB(base.dx - s, base.dy - 0.68 * s, base.dx + s, base.dy - 0.5 * s),
        Paint()..color = Colors.white.withValues(alpha: 0.92));
    canvas.restore();
  }

  void _drawCoin(Canvas canvas, Offset base, double s, double seed) {
    final bob = math.sin(game.time * 4 + seed * 3) * 0.08;
    final c = base.translate(0, -(0.85 + bob) * s);
    final r = 0.3 * s;
    _shadow(canvas, base, s, 0.5, 0.22);
    canvas.drawCircle(c, r * 1.8, Paint()..color = const Color(0xFFFFD166).withValues(alpha: 0.16));
    final spin = math.cos(game.time * 5 + seed * 4).abs().clamp(0.18, 1.0);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(spin, 1);
    final rect = Rect.fromCircle(center: Offset.zero, radius: r);
    canvas.drawCircle(Offset.zero, r, Paint()..color = const Color(0xFFB7791F));
    canvas.drawCircle(
      Offset.zero,
      r * 0.86,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF1A8), Color(0xFFF5B82E), Color(0xFFD98E04)],
        ).createShader(rect),
    );
    // Huella de pie estilizada (moneda de "pasos")
    final mark = Paint()..color = const Color(0xFFB7791F);
    canvas.drawOval(Rect.fromCenter(center: Offset(0, r * 0.12), width: r * 0.55, height: r * 0.8), mark);
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(Offset((i - 1) * r * 0.2, -r * 0.45 + (i == 1 ? -r * 0.05 : 0)), r * 0.09, mark);
    }
    canvas.restore();
  }

  void _drawDrink(Canvas canvas, Offset base, double s, double seed) {
    final bob = math.sin(game.time * 3.5 + seed * 3) * 0.1;
    final c = base.translate(0, -(0.95 + bob) * s);
    _shadow(canvas, base, s, 0.6, 0.25);
    final pulse = 0.5 + 0.5 * math.sin(game.time * 6);
    canvas.drawCircle(
        c, 0.75 * s, Paint()..color = const Color(0xFF22D3EE).withValues(alpha: 0.14 + pulse * 0.12));
    final body = Rect.fromCenter(center: c, width: 0.4 * s, height: 0.66 * s);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(0.07 * s)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF0E7490), Color(0xFF22D3EE), Color(0xFF0891B2)],
          stops: [0, 0.45, 1],
        ).createShader(body),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(body.left + 0.03 * s, body.top - 0.05 * s, body.width - 0.06 * s, 0.07 * s),
          Radius.circular(0.03 * s)),
      Paint()..color = const Color(0xFFE2E8F0),
    );
    final bolt = Path()
      ..moveTo(c.dx + 0.05 * s, c.dy - 0.22 * s)
      ..lineTo(c.dx - 0.1 * s, c.dy + 0.03 * s)
      ..lineTo(c.dx + 0.0 * s, c.dy + 0.03 * s)
      ..lineTo(c.dx - 0.05 * s, c.dy + 0.22 * s)
      ..lineTo(c.dx + 0.11 * s, c.dy - 0.04 * s)
      ..lineTo(c.dx + 0.01 * s, c.dy - 0.04 * s)
      ..close();
    canvas.drawPath(bolt, Paint()..color = const Color(0xFFFDE047));
  }

  void _drawPlayer(Canvas canvas) {
    final base = _pt(game.playerX, 0);
    final s = _ppm(0);
    final jumpH = game.jumpHeight;
    _shadow(canvas, base, s, 0.9 * (1 - jumpH / (SprintGame.jumpPeak * 2.2)), 0.4);
    final feet = base.translate(0, -jumpH * s);
    if (trail != null && !game.crashed) _drawTrail(canvas, trail!, jumpH);
    if (game.shields > 0 || game.shieldFlash > 0) {
      final center = feet.translate(0, -0.95 * s);
      final pulse = 0.5 + 0.5 * math.sin(game.time * 5);
      final alpha = game.shields > 0 ? 0.35 + pulse * 0.25 : game.shieldFlash;
      canvas.drawCircle(
        center,
        1.05 * s,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.06 * s
          ..color = const Color(0xFF60A5FA).withValues(alpha: alpha.clamp(0.0, 1.0)),
      );
    }
    if (game.isTurbo) {
      final pulse = 0.5 + 0.5 * math.sin(game.time * 14);
      final center = feet.translate(0, -0.95 * s);
      canvas.drawCircle(
        center,
        1.1 * s,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFF22D3EE).withValues(alpha: 0.35 + pulse * 0.2),
            const Color(0xFF22D3EE).withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: center, radius: 1.1 * s)),
      );
    }
    _drawRunner(
      canvas,
      feet,
      s,
      game.isJumping ? math.pi / 2 : game.runPhase,
      skin.jersey,
      skin.shorts,
      const Color(0xFFE0AC7E),
      lean: game.lean,
      bib: true,
      tilt: game.crashed ? math.min(game.overTimer * 4, 1.2) : 0,
      shoeAccent: skin.shoeAccent,
    );
  }

  /// Estela detrás del corredor (hacia la cámara), con ligero vaivén.
  void _drawTrail(Canvas canvas, SprintTrail trail, double jumpH) {
    const count = 10;
    final paint = Paint();
    for (var i = count; i >= 1; i--) {
      final z = -i * 0.22;
      final lag = math.sin(game.time * 6 - i * 0.5) * 0.04 * i / count;
      final p = _pt(game.playerX + lag, z, 0.25 + jumpH * (1 - i / count));
      final t = 1 - i / (count + 1);
      final color = trail.colors[(i + (game.time * 8).floor()) % trail.colors.length];
      paint.color = color.withValues(alpha: 0.55 * t);
      canvas.drawCircle(p, _ppm(z) * (0.06 + 0.1 * t), paint);
    }
  }

  /// Corredor visto de espaldas. [feet] es el punto de apoyo; [s] px/m.
  void _drawRunner(Canvas canvas, Offset feet, double s, double phase, Color jersey, Color shorts, Color skin,
      {double lean = 0, bool bib = false, double tilt = 0, Color shoeAccent = const Color(0xFFFF6B35)}) {
    canvas.save();
    canvas.translate(feet.dx, feet.dy);
    canvas.rotate(lean * 0.16 + tilt);

    final limb = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Piernas
    for (final side in [-1.0, 1.0]) {
      final ph = phase + (side < 0 ? 0 : math.pi);
      final lift = math.max(0.0, math.sin(ph));
      final hip = Offset(side * 0.11 * s, -0.92 * s);
      final foot = Offset(side * 0.13 * s, -(0.02 + lift * 0.42) * s);
      final knee = Offset(side * 0.17 * s, (hip.dy + foot.dy) / 2 + lift * 0.08 * s);
      limb
        ..color = skin
        ..strokeWidth = 0.12 * s;
      canvas.drawPath(Path()..moveTo(hip.dx, hip.dy)..lineTo(knee.dx, knee.dy)..lineTo(foot.dx, foot.dy), limb);
      // Zapatilla (la suela se ve cuando el pie sube)
      final shoe = Rect.fromCenter(center: foot, width: 0.17 * s, height: (0.09 + lift * 0.05) * s);
      canvas.drawRRect(RRect.fromRectAndRadius(shoe, Radius.circular(0.04 * s)), Paint()..color = const Color(0xFFF8FAFC));
      canvas.drawRect(
          Rect.fromLTWH(shoe.left, shoe.top, shoe.width, shoe.height * 0.45), Paint()..color = shoeAccent);
    }

    // Short
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-0.2 * s, -1.04 * s, 0.4 * s, 0.22 * s), Radius.circular(0.05 * s)),
      Paint()..color = shorts,
    );

    // Brazos (oscilan opuestos a las piernas)
    for (final side in [-1.0, 1.0]) {
      final ph = phase + (side < 0 ? math.pi : 0);
      final swing = math.sin(ph);
      final shoulder = Offset(side * 0.22 * s, -1.43 * s);
      final elbow = Offset(side * 0.3 * s, -(1.2 + swing * 0.06) * s);
      final hand = Offset(side * 0.24 * s, -(1.08 + swing * 0.2) * s);
      limb
        ..color = skin
        ..strokeWidth = 0.09 * s;
      canvas.drawPath(
          Path()..moveTo(shoulder.dx, shoulder.dy)..lineTo(elbow.dx, elbow.dy)..lineTo(hand.dx, hand.dy), limb);
    }

    // Torso (camiseta)
    final torso = Path()
      ..moveTo(-0.25 * s, -1.5 * s)
      ..lineTo(0.25 * s, -1.5 * s)
      ..lineTo(0.21 * s, -1.0 * s)
      ..lineTo(-0.21 * s, -1.0 * s)
      ..close();
    canvas.drawPath(torso, Paint()..color = jersey);
    canvas.drawRect(Rect.fromLTWH(-0.25 * s, -1.5 * s, 0.5 * s, 0.05 * s),
        Paint()..color = Colors.white.withValues(alpha: 0.25));
    if (bib) {
      final b = Rect.fromLTWH(-0.12 * s, -1.38 * s, 0.24 * s, 0.17 * s);
      canvas.drawRRect(RRect.fromRectAndRadius(b, Radius.circular(0.02 * s)), Paint()..color = Colors.white);
      final ink = Paint()..color = const Color(0xFF0F172A);
      canvas.drawRect(Rect.fromLTWH(b.left + b.width * 0.2, b.top + b.height * 0.3, b.width * 0.6, b.height * 0.14), ink);
      canvas.drawRect(Rect.fromLTWH(b.left + b.width * 0.3, b.top + b.height * 0.6, b.width * 0.4, b.height * 0.12), ink);
    }

    // Cuello y cabeza
    canvas.drawRect(Rect.fromLTWH(-0.05 * s, -1.58 * s, 0.1 * s, 0.1 * s), Paint()..color = skin);
    final head = Offset(0, -1.7 * s);
    canvas.drawCircle(head, 0.13 * s, Paint()..color = skin);
    canvas.drawArc(Rect.fromCircle(center: head.translate(0, 0.01 * s), radius: 0.135 * s), math.pi * 0.95, math.pi * 1.1,
        true, Paint()..color = const Color(0xFF1F1A17));
    canvas.drawCircle(head.translate(0, 0.03 * s), 0.11 * s, Paint()..color = const Color(0xFF2A211C));
    canvas.drawRect(Rect.fromLTWH(-0.135 * s, -1.76 * s, 0.27 * s, 0.04 * s), Paint()..color = jersey.withValues(alpha: 0.9));

    canvas.restore();
  }

  // ── Efectos ───────────────────────────────────────────────────────
  void _drawParticles(Canvas canvas) {
    final paint = Paint();
    for (final p in game.particles) {
      if (p.z < _nearZ) continue;
      final pos = _pt(p.x, p.z, p.y);
      final a = (p.life / p.maxLife).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: p.color.a * a);
      canvas.drawCircle(pos, math.max(0.8, p.size * _ppm(p.z) * (0.5 + a * 0.5)), paint);
    }
  }

  void _drawPopups(Canvas canvas) {
    for (final p in game.popups) {
      final t = 1 - p.life / p.maxLife;
      final alpha = (p.life / p.maxLife * 2).clamp(0.0, 1.0);
      final scale = t < 0.15 ? 0.6 + t / 0.15 * 0.5 : 1.1 - math.min(0.1, (t - 0.15));
      final pos = _pt(p.x, 0.3, p.y + 0.0);
      final tp = TextPainter(
        text: TextSpan(
          text: p.text,
          style: TextStyle(
            color: p.color.withValues(alpha: alpha),
            fontSize: p.size * scale,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            shadows: [Shadow(color: Colors.black.withValues(alpha: 0.6 * alpha), blurRadius: 6, offset: const Offset(0, 2))],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant SprintPainter oldDelegate) =>
      oldDelegate.game != game || oldDelegate.skin != skin || oldDelegate.trail != trail;
}

class _Dot {
  final double fx, fy, phase;
  final int color;
  const _Dot(this.fx, this.fy, this.color, this.phase);
}
