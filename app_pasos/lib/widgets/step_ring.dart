import 'dart:math';
import 'package:flutter/material.dart';
import '../config/theme.dart';

class StepRing extends StatelessWidget {
  final double size;
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final Widget? center;
  final bool animate;

  const StepRing({
    super.key,
    this.size = 120,
    required this.progress,
    this.color = AppTheme.primary,
    this.trackColor = AppTheme.darkGrey,
    this.strokeWidth = 8,
    this.center,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: progress.clamp(0.0, 1.0),
              color: color,
              trackColor: trackColor,
              strokeWidth: strokeWidth,
            ),
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.6), color],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class DualStepRing extends StatelessWidget {
  final double size;
  final double userProgress;
  final double opponentProgress;
  final double userSteps;
  final double opponentSteps;
  final String userName;
  final String opponentName;

  const DualStepRing({
    super.key,
    this.size = 200,
    required this.userProgress,
    required this.opponentProgress,
    required this.userSteps,
    required this.opponentSteps,
    required this.userName,
    required this.opponentName,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _DualRingPainter(
              userProgress: userProgress.clamp(0.0, 1.0),
              opponentProgress: opponentProgress.clamp(0.0, 1.0),
              userColor: AppTheme.primary,
              opponentColor: AppTheme.secondary,
              strokeWidth: 8,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatSteps(userSteps.toInt()),
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: size * 0.12,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.primary,
                ),
              ),
              SizedBox(height: size * 0.02),
              Text(
                'VS',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: size * 0.06,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: size * 0.02),
              Text(
                _formatSteps(opponentSteps.toInt()),
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: size * 0.12,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatSteps(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}K';
    }
    return n.toString();
  }
}

class _DualRingPainter extends CustomPainter {
  final double userProgress;
  final double opponentProgress;
  final Color userColor;
  final Color opponentColor;
  final double strokeWidth;

  _DualRingPainter({
    required this.userProgress,
    required this.opponentProgress,
    required this.userColor,
    required this.opponentColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.6
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final userPaint = Paint()
      ..color = userColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final oppPaint = Paint()
      ..color = opponentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final userSweep = 2 * pi * userProgress;
    final oppSweep = 2 * pi * opponentProgress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      userSweep,
      false,
      userPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2 + 0.1,
      oppSweep.clamp(0, 2 * pi - 0.2),
      false,
      oppPaint,
    );
  }

  @override
  bool shouldRepaint(_DualRingPainter oldDelegate) =>
      oldDelegate.userProgress != userProgress ||
      oldDelegate.opponentProgress != opponentProgress;
}
