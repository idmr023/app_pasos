import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/challenge_provider.dart';
import '../providers/step_provider.dart';
import '../providers/xp_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/player_avatar.dart';
import '../widgets/neon_button.dart';
import '../widgets/animated_counter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshData() {
    final auth = context.read<AuthProvider>();
    if (auth.token == null) return;

    final token = auth.token!;
    context.read<ChallengeProvider>().setToken(token);
    context.read<ChallengeProvider>().loadChallenges();
    context.read<ChallengeProvider>().loadFinishedChallenges();
    context.read<StepProvider>().setToken(token);
    context.read<StepProvider>().loadTodaySteps();
    context.read<XpProvider>().setToken(token);
    context.read<XpProvider>().loadXp();
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
    final stepProv = context.watch<StepProvider>();
    final user = auth.user;
    final hasChallenges = challengeProvider.challenges.isNotEmpty;

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
            onRefresh: () async => _refreshData(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(user)),
                SliverToBoxAdapter(child: _buildTodaySteps(stepProv.todaySteps)),
                SliverToBoxAdapter(child: _buildTabs()),
                SliverToBoxAdapter(child: _buildChallengesSection(challengeProvider, hasChallenges)),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: hasChallenges
          ? FloatingActionButton(
              onPressed: () => Navigator.pushNamed(context, '/challenge-create'),
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildHeader(user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/profile'),
              child: PlayerAvatar(
                radius: 28,
                avatarType: user?.avatar ?? 'runner',
                displayName: null,
              ),
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
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: AppTheme.darkGrey),
              onPressed: _logout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaySteps(int steps) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GlassCard(
        width: double.infinity,
        child: Column(
          children: [
            Text('PASOS DE HOY', style: AppTheme.labelLarge),
            const SizedBox(height: 16),
            AnimatedCounter(
              value: steps,
              style: AppTheme.counterLarge,
            ),
            const SizedBox(height: 8),
            Text('tus pasos registrados hoy', style: AppTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.darkGrey,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'ACTIVOS'),
            Tab(text: 'FINALIZADOS'),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengesSection(ChallengeProvider challengeProv, bool hasChallenges) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (challengeProv.isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          else if (!hasChallenges)
            _buildEmptyState()
          else
            _buildChallengeList(),
        ],
      ),
    );
  }

  Widget _buildChallengeList() {
    final challengeProv = context.watch<ChallengeProvider>();
    final challenges = _tabController.index == 0
        ? challengeProv.challenges
        : challengeProv.finishedChallenges;

    if (challenges.isEmpty && _tabController.index == 1) {
      return GlassCard(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(Icons.check_circle_outline, size: 48, color: AppTheme.darkGrey),
              const SizedBox(height: 16),
              Text('No hay retos finalizados', style: AppTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    if (challenges.isEmpty) return const SizedBox.shrink();

    return Column(
      children: challenges.map((c) => _buildChallengeCard(c)).toList(),
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
    final isFinished = challenge.status == 'finished';
    final userWon = challenge.winner == currentUser?.id;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => Navigator.pushNamed(context, '/challenge-room', arguments: challenge.id),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isFinished
                  ? AppTheme.gold.withValues(alpha: 0.1)
                  : challenge.status == 'active'
                      ? AppTheme.secondary.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isFinished ? Icons.emoji_events : Icons.emoji_events,
              color: isFinished ? AppTheme.gold : challenge.status == 'active' ? AppTheme.secondary : AppTheme.darkGrey,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${challenge.code}',
                      style: AppTheme.titleMedium,
                    ),
                    if (challenge.duration > 0) ...[
                      const SizedBox(width: 8),
                      Text('${challenge.duration}d', style: TextStyle(color: AppTheme.darkGrey, fontSize: 11)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isFinished
                      ? (otherUser != null ? 'vs ${otherUser.displayName}' : 'vs ?')
                      : (otherUser != null ? 'vs ${otherUser.displayName}' : 'Esperando oponente...'),
                  style: AppTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (isFinished)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: userWon ? AppTheme.gold.withValues(alpha: 0.15) : AppTheme.darkGrey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: userWon ? AppTheme.gold.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Text(
                userWon ? 'GANASTE' : 'PERDISTE',
                style: TextStyle(
                  color: userWon ? AppTheme.gold : AppTheme.darkGrey,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            )
          else
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
