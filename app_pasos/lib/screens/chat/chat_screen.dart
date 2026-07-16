import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../widgets/glass_card.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text('COACH IA', style: AppTheme.titleLarge.copyWith(letterSpacing: 2)),
            const SizedBox(height: 4),
            Text('Tu asistente de fitness', style: AppTheme.bodyMedium),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _buildBotMessage('¡Hola! Soy tu coach virtual. Estoy aquí para ayudarte con tus rutinas, responder preguntas sobre ejercicios y darte consejos de fitness.'),
                  const SizedBox(height: 12),
                  _buildBotMessage('Por ahora estoy en desarrollo, pero pronto podré ayudarte con:'),
                  const SizedBox(height: 12),
                  _buildBotMessage('• Rutinas personalizadas\n• Técnica de ejercicios\n• Nutrición básica\n• Seguimiento de progreso\n• Motivación diaria'),
                ],
              ),
            ),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      enabled: false,
                      style: AppTheme.bodyLarge,
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  Icon(Icons.send, color: AppTheme.darkGrey),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotMessage(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Text(text, style: AppTheme.bodyLarge),
      ),
    );
  }
}