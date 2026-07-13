import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/challenge_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/neon_button.dart';

class ChallengeCreateScreen extends StatefulWidget {
  const ChallengeCreateScreen({super.key});

  @override
  State<ChallengeCreateScreen> createState() => _ChallengeCreateScreenState();
}

class _ChallengeCreateScreenState extends State<ChallengeCreateScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.background,
              Color(0xFF0A1A0A),
              AppTheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Consumer<ChallengeProvider>(
            builder: (context, challengeProvider, _) {
              if (challengeProvider.isLoading) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
              }

              if (challengeProvider.currentChallenge != null) {
                return _buildChallengeCreated(challengeProvider);
              }

              return _buildCreateForm(challengeProvider);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeCreated(ChallengeProvider challengeProvider) {
    final challenge = challengeProvider.currentChallenge!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.gold.withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.emoji_events, size: 64, color: AppTheme.gold),
            ),
            const SizedBox(height: 24),
            Text('RETO CREADO', style: AppTheme.headlineLarge.copyWith(letterSpacing: 4)),
            const SizedBox(height: 8),
            Text('Comparte este código con tu amigo', style: AppTheme.bodyMedium),
            const SizedBox(height: 32),
            GlassCard(
              width: double.infinity,
              child: Column(
                children: [
                  Text(challenge.code, style: AppTheme.displayMedium.copyWith(color: AppTheme.primary, letterSpacing: 16)),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: challenge.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Código copiado'), backgroundColor: AppTheme.secondary),
                      );
                    },
                    icon: const Icon(Icons.copy, color: AppTheme.darkGrey),
                    label: const Text('Copiar código', style: TextStyle(color: AppTheme.darkGrey)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            NeonButton(
              label: 'IR AL RETO',
              icon: Icons.arrow_forward,
              color: AppTheme.primary,
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/challenge-room', arguments: challenge.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateForm(ChallengeProvider challengeProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.add_circle_outline, size: 64, color: AppTheme.primary),
            ),
            const SizedBox(height: 24),
            Text('Crear un nuevo reto', style: AppTheme.headlineLarge),
            const SizedBox(height: 8),
            Text('Recibirás un código para compartir con tu amigo', style: AppTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 40),
            NeonButton(
              label: 'CREAR RETO',
              icon: Icons.emoji_events,
              onPressed: () => challengeProvider.createChallenge(),
            ),
          ],
        ),
      ),
    );
  }
}
