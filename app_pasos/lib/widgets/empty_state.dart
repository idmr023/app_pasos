import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'glass_card.dart';

class EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? action;

  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppTheme.darkGrey),
          const SizedBox(height: 16),
          Text(title, style: AppTheme.bodyLarge, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: AppTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null)
            action!
          else if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add, size: 18),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
