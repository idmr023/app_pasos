import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/challenge_provider.dart';
import '../providers/wallet_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/neon_button.dart';
import '../widgets/wallet_widgets.dart';

class ChallengeJoinScreen extends StatefulWidget {
  const ChallengeJoinScreen({super.key});

  @override
  State<ChallengeJoinScreen> createState() => _ChallengeJoinScreenState();
}

class _ChallengeJoinScreenState extends State<ChallengeJoinScreen> {
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ensureWalletLoaded(context);
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El código debe tener 6 caracteres'), backgroundColor: AppTheme.error),
      );
      return;
    }

    final challengeProvider = context.read<ChallengeProvider>();
    final wallet = context.read<WalletProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final success = await challengeProvider.joinChallenge(code);

    if (!mounted) return;

    if (success) {
      final joined = challengeProvider.currentChallenge!;
      if (joined.hasWager) {
        if (joined.balanceAfter != null) wallet.setBalance(joined.balanceAfter!);
        wallet.refreshBalance();
        messenger.showSnackBar(SnackBar(
          content: Text('Apostaste ${formatPasos(joined.wager)} pasos. ¡El ganador se lleva ${formatPasos(joined.pot)}!'),
          backgroundColor: AppTheme.secondary,
        ));
      }
      Navigator.pushReplacementNamed(context, '/challenge-room', arguments: joined.id);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(challengeProvider.error ?? 'Error al unirse'), backgroundColor: AppTheme.error),
      );
    }
  }

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
              Color(0xFF00101A),
              AppTheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Consumer<ChallengeProvider>(
            builder: (context, challengeProvider, _) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.tertiary.withValues(alpha: 0.1),
                        ),
                        child: const Icon(Icons.group_add, size: 64, color: AppTheme.tertiary),
                      ),
                      const SizedBox(height: 24),
                      Text('Ingresa el código', style: AppTheme.headlineLarge),
                      const SizedBox(height: 8),
                      Text('Código de 6 caracteres que te compartió tu amigo', style: AppTheme.bodyMedium, textAlign: TextAlign.center),
                      const SizedBox(height: 32),
                      GlassCard(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        child: TextFormField(
                          controller: _codeController,
                          textAlign: TextAlign.center,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 6,
                          style: AppTheme.displayMedium.copyWith(
                            color: AppTheme.tertiary,
                            letterSpacing: 16,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '------',
                            hintStyle: AppTheme.displayMedium.copyWith(
                              color: Colors.white.withValues(alpha: 0.06),
                              letterSpacing: 16,
                            ),
                            filled: false,
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Consumer<WalletProvider>(
                        builder: (context, wallet, _) => Text(
                          'Si el reto tiene apuesta, se descontará de tu saldo'
                          '${wallet.hasLoaded ? ' (${formatPasos(wallet.balance)} pasos)' : ''}.',
                          textAlign: TextAlign.center,
                          style: AppTheme.bodySmall.copyWith(color: AppTheme.gold),
                        ),
                      ),
                      const SizedBox(height: 24),
                      NeonButton(
                        label: 'UNIRSE AL RETO',
                        icon: Icons.login,
                        color: AppTheme.tertiary,
                        onPressed: challengeProvider.isLoading ? null : _join,
                        isLoading: challengeProvider.isLoading,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
