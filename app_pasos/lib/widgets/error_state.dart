import 'package:flutter/material.dart';
import '../config/theme.dart';

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String? title;

  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.title = 'Error',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(title ?? 'Error', style: AppTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('REINTENTAR'),
            ),
          ],
        ),
      ),
    );
  }
}
