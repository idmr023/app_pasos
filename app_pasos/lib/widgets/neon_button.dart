import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'loading_states.dart';

class NeonButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final bool isLoading;
  final double width;

  const NeonButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color = AppTheme.primary,
    this.isLoading = false,
    this.width = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: onPressed != null && !isLoading
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.4),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: isLoading
            ? const InlineSpinner()
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(label, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
      ),
    );
  }
}
