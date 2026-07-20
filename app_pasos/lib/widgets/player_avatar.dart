import 'package:flutter/material.dart';
import '../config/theme.dart';

class PlayerAvatar extends StatelessWidget {
  final double radius;
  final String? avatarType;
  final String? displayName;
  final bool isLeading;
  final bool showGlow;
  final Color? glowColor;
  final String? subtitle;

  const PlayerAvatar({
    super.key,
    this.radius = 32,
    this.avatarType,
    this.displayName,
    this.isLeading = false,
    this.showGlow = true,
    this.glowColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final color = glowColor ?? (isLeading ? AppTheme.gold : AppTheme.primary);
    final icon = _getIcon(avatarType ?? 'runner');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: radius * 2 + (showGlow ? 8 : 0),
          height: radius * 2 + (showGlow ? 8 : 0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: showGlow
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: isLeading ? 0.5 : 0.3),
                      blurRadius: radius * 0.6,
                      spreadRadius: radius * 0.1,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (showGlow)
                CustomPaint(
                  size: Size(radius * 2 + 8, radius * 2 + 8),
                  painter: _GlowRingPainter(
                    color: color,
                    progress: 1.0,
                    strokeWidth: 2,
                  ),
                ),
              CircleAvatar(
                radius: radius,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, size: radius, color: color),
              ),
              if (isLeading)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Icon(
                    Icons.emoji_events,
                    color: AppTheme.gold,
                    size: radius * 0.6,
                    shadows: [
                      Shadow(
                        color: AppTheme.gold.withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (displayName != null) ...[
          const SizedBox(height: 6),
          Text(
            displayName!,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: radius * 0.4,
            ),
          ),
        ],
        if (subtitle != null)
          Text(
            subtitle!,
            style: TextStyle(
              color: AppTheme.darkGrey,
              fontSize: radius * 0.3,
            ),
          ),
      ],
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'crown':    return Icons.emoji_events;
      case 'fire':     return Icons.local_fire_department;
      case 'star':     return Icons.star;
      case 'walker':   return Icons.directions_walk;
      case 'marathon': return Icons.directions_run;
      case 'ultra':    return Icons.terrain;
      case 'legend':   return Icons.auto_awesome;
      case 'titan':    return Icons.flash_on;
      default:         return Icons.directions_run;
    }
  }
}

class _GlowRingPainter extends CustomPainter {
  final Color color;
  final double progress;
  final double strokeWidth;

  _GlowRingPainter({
    required this.color,
    required this.progress,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
