import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../providers/league_provider.dart';

const _divisionIcons = <String, IconData>{
  'bronce': Icons.directions_walk_rounded,
  'plata': Icons.directions_run_rounded,
  'oro': Icons.local_fire_department_rounded,
  'platino': Icons.bolt_rounded,
  'diamante': Icons.diamond_rounded,
  'leyenda': Icons.auto_awesome_rounded,
};

IconData divisionIcon(String key) => _divisionIcons[key] ?? Icons.shield_rounded;

/// Escudo de división. Con [animated] respira y un brillo recorre el borde.
class LeagueDivisionBadge extends StatefulWidget {
  final LeagueDivision division;
  final double size;
  final bool animated;
  final bool dimmed;

  const LeagueDivisionBadge({
    super.key,
    required this.division,
    this.size = 64,
    this.animated = false,
    this.dimmed = false,
  });

  @override
  State<LeagueDivisionBadge> createState() => _LeagueDivisionBadgeState();
}

class _LeagueDivisionBadgeState extends State<LeagueDivisionBadge> with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _syncController();
  }

  @override
  void didUpdateWidget(covariant LeagueDivisionBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animated != widget.animated) _syncController();
  }

  void _syncController() {
    if (widget.animated && _controller == null) {
      _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
    } else if (!widget.animated && _controller != null) {
      _controller!.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _badge(double t) {
    final color = widget.dimmed ? widget.division.color.withValues(alpha: 0.35) : widget.division.color;
    final pulse = widget.animated ? 1 + 0.05 * math.sin(t * 2 * math.pi) : 1.0;
    return Transform.scale(
      scale: pulse,
      child: SizedBox(
        width: widget.size,
        height: widget.size * 1.12,
        child: CustomPaint(
          painter: _ShieldPainter(color: color, shine: widget.animated ? t : null),
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: widget.size * 0.08),
              child: Icon(
                divisionIcon(widget.division.key),
                size: widget.size * 0.46,
                color: Colors.white.withValues(alpha: widget.dimmed ? 0.5 : 0.95),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return _badge(0);
    return AnimatedBuilder(animation: controller, builder: (_, __) => _badge(controller.value));
  }
}

class _ShieldPainter extends CustomPainter {
  final Color color;
  final double? shine; // 0..1 posición del brillo, null = sin brillo

  _ShieldPainter({required this.color, this.shine});

  Path _shield(Size s) {
    final w = s.width, h = s.height;
    return Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.16)
      ..lineTo(w, h * 0.5)
      ..quadraticBezierTo(w * 0.95, h * 0.86, w * 0.5, h)
      ..quadraticBezierTo(w * 0.05, h * 0.86, 0, h * 0.5)
      ..lineTo(0, h * 0.16)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _shield(size);
    final rect = Offset.zero & size;
    final hsl = HSLColor.fromColor(color);
    final light = hsl.withLightness((hsl.lightness + 0.18).clamp(0.0, 1.0)).toColor();
    final dark = hsl.withLightness((hsl.lightness - 0.22).clamp(0.0, 1.0)).toColor();

    canvas.drawShadow(path, Colors.black, 4, false);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [light, color, dark],
        ).createShader(rect),
    );

    final s = shine;
    if (s != null) {
      canvas.save();
      canvas.clipPath(path);
      final x = -size.width + s * size.width * 3;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0)],
            stops: const [0.35, 0.5, 0.65],
          ).createShader(Rect.fromLTWH(x, 0, size.width, size.height)),
      );
      canvas.restore();
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.045
        ..color = Colors.white.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(covariant _ShieldPainter old) => old.color != color || old.shine != shine;
}
