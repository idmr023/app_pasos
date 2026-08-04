import 'package:flutter/material.dart';
import '../config/theme.dart';

class AppLoading extends StatelessWidget {
  final double size;

  const AppLoading({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(color: AppTheme.primary),
      ),
    );
  }
}

class InlineSpinner extends StatelessWidget {
  final Color color;
  final double size;

  const InlineSpinner({
    super.key,
    this.color = Colors.white,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color.withValues(alpha: 0.8),
      ),
    );
  }
}
