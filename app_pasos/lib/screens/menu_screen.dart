import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/xp_provider.dart';
import '../widgets/league_summary_card.dart';
import '../widgets/player_avatar.dart';
import 'analytics_screen.dart';
import 'games/game_hub_screen.dart';
import 'wallet/wallet_screen.dart';
import 'main_shell.dart';
import 'routes/routes_screen.dart';
import 'profile_screen.dart';

/// Tab "Explorar": hub con acceso a todo lo que no tiene tab propia
/// (juego, rutas/portadas, perfil, estadísticas, ajustes).
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final xp = context.watch<XpProvider>();
    final user = auth.user;
    final percent =
        ((xp.progress['percent'] as num?)?.toDouble() ?? 0).clamp(0, 100) /
        100;

    final tiles = <_HubTile>[
      _HubTile(
        icon: Icons.sports_esports,
        label: 'Sprint',
        subtitle: 'Juega con tus pasos',
        colors: const [Color(0xFFFF416C), Color(0xFFFF4B2B)],
        onTap: () => _push(context, const GameHubScreen()),
      ),
      _HubTile(
        icon: Icons.account_balance_wallet_outlined,
        label: 'Billetera',
        subtitle: 'Gasta tus pasos en la tienda',
        colors: const [Color(0xFF00C9A7), Color(0xFF00897B)],
        onTap: () => _push(context, const WalletScreen()),
      ),
      _HubTile(
        icon: Icons.map_outlined,
        label: 'Rutas y portadas',
        subtitle: 'Strava, diseños y fotos',
        colors: const [Color(0xFF00B4DB), Color(0xFF0083B0)],
        onTap: () => _push(context, const RoutesScreen()),
      ),
      _HubTile(
        icon: Icons.insights_outlined,
        label: 'Estadísticas',
        subtitle: 'Semanas y meses',
        colors: const [Color(0xFF7F00FF), Color(0xFFE100FF)],
        onTap: () => _push(context, const AnalyticsScreen()),
      ),
      _HubTile(
        icon: Icons.person_outline,
        label: 'Mi perfil',
        subtitle: 'Nivel, logros, avatar',
        colors: const [Color(0xFFFF512F), Color(0xFFDD2476)],
        onTap: () => _push(context, const ProfileScreen()),
      ),
      _HubTile(
        icon: Icons.emoji_events_outlined,
        label: 'Retos',
        subtitle: 'Activos y finalizados',
        colors: const [Color(0xFFF7971E), Color(0xFFFFD200)],
        onTap: () => MainShellScope.of(context)?.goToTab(0),
      ),
      _HubTile(
        icon: Icons.live_tv,
        label: 'Carrera en vivo',
        subtitle: 'Comparte tu GPS',
        colors: const [Color(0xFF11998E), Color(0xFF38EF7D)],
        onTap: () => MainShellScope.of(context)?.goToTab(2),
      ),
      _HubTile(
        icon: Icons.settings_outlined,
        label: 'Ajustes',
        subtitle: 'Cuenta y sesión',
        colors: const [Color(0xFF434343), Color(0xFF6B6B6B)],
        onTap: () => _showSettings(context),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: _Header(
                name: user?.displayName ?? 'Atleta',
                avatar: user?.avatar,
                level: xp.level,
                title: xp.title,
                percent: percent.toDouble(),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: LeagueSummaryCard(),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Explorar',
                style: TextStyle(
                  color: AppTheme.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.05,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _StaggeredIn(index: i, child: tiles[i]),
                childCount: tiles.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, anim, __, child) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  static void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.darkGrey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(
                    Icons.person_outline,
                    color: AppTheme.primary,
                  ),
                  title: const Text('Editar perfil'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _push(context, const ProfileScreen());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppTheme.error),
                  title: const Text('Cerrar sesión'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final navigator = Navigator.of(context);
                    await context.read<AuthProvider>().logout();
                    navigator.pushNamedAndRemoveUntil('/login', (_) => false);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String name;
  final String? avatar;
  final int level;
  final String title;
  final double percent;

  const _Header({
    required this.name,
    required this.avatar,
    required this.level,
    required this.title,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.25),
            AppTheme.secondary.withValues(alpha: 0.15),
          ],
        ),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          PlayerAvatar(
            radius: 30,
            avatarType: avatar,
            displayName: name,
            showGlow: true,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Hola, $name!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Nivel $level${title.isNotEmpty ? ' · $title' : ''}',
                  style: const TextStyle(color: AppTheme.grey, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: percent),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder:
                      (_, value, __) => ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: value,
                          minHeight: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          valueColor: const AlwaysStoppedAnimation(
                            AppTheme.primary,
                          ),
                        ),
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(percent * 100).round()}% hacia el nivel ${level + 1}',
                  style: const TextStyle(color: AppTheme.grey, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HubTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  const _HubTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  @override
  State<_HubTile> createState() => _HubTileState();
}

class _HubTileState extends State<_HubTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.colors,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.colors.last.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 26),
              ),
              const Spacer(),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Entrada escalonada (fade + slide) para las tarjetas del grid.
class _StaggeredIn extends StatelessWidget {
  final int index;
  final Widget child;

  const _StaggeredIn({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + index * 70),
      curve: Curves.easeOutBack,
      builder:
          (_, t, c) => Opacity(
            opacity: t.clamp(0, 1).toDouble(),
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 24),
              child: c,
            ),
          ),
      child: child,
    );
  }
}
