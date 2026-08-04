import 'package:flutter/material.dart';
import '../config/theme.dart';

class ScreenTopBar extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final bool showBack;

  const ScreenTopBar({
    super.key,
    required this.title,
    this.actions,
    this.onBack,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white70),
              onPressed: onBack ?? () => Navigator.pop(context),
            ),
          if (showBack) const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: AppTheme.titleLarge.copyWith(letterSpacing: 1.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}
