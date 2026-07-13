import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/challenge_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/step_ring.dart';
import '../widgets/player_avatar.dart';
import '../widgets/neon_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    final auth = context.read<AuthProvider>();
    if (auth.token != null) {
      context.read<ChallengeProvider>().setToken(auth.token!);
      context.read<ChallengeProvider>().loadChallenges();
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final challengeProvider = context.watch<ChallengeProvider>();
    final user = auth.user;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.background,
              Color(0xFF0A0A1A),
              AppTheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async => _loadData(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(user),
                  const SizedBox(height: 16),
                  _buildDailyRing(),
                  const SizedBox(height: 16),
                  _buildChallengesSection(challengeProvider),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: challengeProvider.challenges.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => Navigator.pushNamed(context, '/challenge-create'),
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildHeader(user) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      child: Row(
        children: [
          PlayerAvatar(
            radius: 28,
            avatarType: user?.avatar ?? 'runner',
            displayName: null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? 'Usuario',
                  style: AppTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.local_fire_department, size: 14, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Text('3 días seguidos', style: AppTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.darkGrey),
            onPressed: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildDailyRing() {
    return GlassCard(
      width: double.infinity,
      child: Column(
        children: [
          Text('HOY', style: AppTheme.labelLarge),
          const SizedBox(height: 16),
          StepRing(
            size: 160,
            progress: 0.45,
            color: AppTheme.primary,
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '4,523',
                  style: AppTheme.counterLarge,
                ),
                Text(
                  'de 10,000',
                  style: AppTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Meta diaria: 10,000 pasos',
            style: AppTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildChallengesSection(ChallengeProvider challengeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TUS RETOS', style: AppTheme.labelLarge),
        const SizedBox(height: 12),
        if (challengeProvider.isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          )
        else if (challengeProvider.challenges.isEmpty)
          _buildEmptyState()
        else
          ...challengeProvider.challenges.map((c) => _buildChallengeCard(c)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return GlassCard(
      width: double.infinity,
      child: Column(
        children: [
          const Icon(Icons.emoji_events_outlined, size: 48, color: AppTheme.darkGrey),
          const SizedBox(height: 16),
          Text('No tienes retos activos', style: AppTheme.bodyLarge),
          const SizedBox(height: 4),
          Text('Crea uno o únete a un amigo', style: AppTheme.bodyMedium),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: NeonButton(
              label: 'CREAR RETO',
              icon: Icons.add,
              onPressed: () => Navigator.pushNamed(context, '/challenge-create'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/challenge-join'),
              icon: const Icon(Icons.login),
              label: const Text('UNIRME'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeCard(challenge) {
    final currentUser = context.read<AuthProvider>().user;
    final isCreator = challenge.creator?.id == currentUser?.id;
    final otherUser = isCreator ? challenge.opponent : challenge.creator;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => Navigator.pushNamed(context, '/challenge-room', arguments: challenge.id),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: challenge.status == 'active'
                  ? AppTheme.secondary.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.emoji_events,
              color: challenge.status == 'active' ? AppTheme.secondary : AppTheme.darkGrey,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reto: ${challenge.code}',
                  style: AppTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  otherUser != null ? 'vs ${otherUser.displayName}' : 'Esperando oponente...',
                  style: AppTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: challenge.status == 'active'
                  ? AppTheme.secondary.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: challenge.status == 'active'
                    ? AppTheme.secondary.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Text(
              challenge.status == 'active' ? 'ACTIVO' : 'ESPERANDO',
              style: TextStyle(
                color: challenge.status == 'active' ? AppTheme.secondary : AppTheme.darkGrey,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
