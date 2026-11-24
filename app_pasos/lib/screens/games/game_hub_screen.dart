import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../games/sprint/sprint_cosmetics.dart';
import '../../games/sprint/sprint_game.dart';
import '../../games/sprint/sprint_painter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/wallet_widgets.dart';
import '../wallet/wallet_screen.dart';
import 'game_leaderboard_screen.dart';
import 'sprint_play_screen.dart';

/// Hub del minijuego Sprint: intentos ganados con pasos, récord,
/// multiplicador de XP, botón de jugar y top del ranking.
class GameHubScreen extends StatefulWidget {
  const GameHubScreen({super.key});

  @override
  State<GameHubScreen> createState() => _GameHubScreenState();
}

class _GameHubScreenState extends State<GameHubScreen> {
  late final SprintGame _preview = SprintGame.preview();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _preview.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = context.read<AuthProvider>().token;
    final game = context.read<GameProvider>();
    if (token != null) game.setToken(token);
    await Future.wait([game.loadAll(), ensureWalletLoaded(context)]);
  }

  Future<void> _play({required bool official}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SprintPlayScreen(official: official)),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sprint'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.white,
        elevation: 0,
        actions: [
          const Center(child: WalletBalanceChip()),
          IconButton(
            tooltip: 'Ranking',
            icon: const Icon(Icons.leaderboard_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GameLeaderboardScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _hero(),
            const SizedBox(height: 16),
            if (game.error != null && !game.hasLoadedFuel) _errorCard(game),
            _fuelCard(game),
            const SizedBox(height: 16),
            _shieldCard(game),
            const SizedBox(height: 16),
            _playButtons(game),
            const SizedBox(height: 16),
            _statsRow(game),
            const SizedBox(height: 16),
            _multiplierCard(game),
            const SizedBox(height: 16),
            _howToPlay(),
            const SizedBox(height: 16),
            _leaderboardPreview(game),
          ],
        ),
      ),
    );
  }

  Widget _hero() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 190,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Selector<WalletProvider, (String, String?)>(
              selector: (_, w) => (w.equippedSkin, w.equippedTrail),
              builder: (context, eq, _) => CustomPaint(
                painter: SprintPainter(_preview, skin: SprintSkin.byId(eq.$1), trail: SprintTrail.byId(eq.$2)),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent, Colors.black.withValues(alpha: 0.5)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SPRINT', style: AppTheme.displayMedium.copyWith(color: Colors.white, letterSpacing: 3)),
                  Text('Esquiva vallas, conos y rivales',
                      style: AppTheme.bodyMedium.copyWith(color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child, Color? borderColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor ?? AppTheme.border),
      ),
      child: child,
    );
  }

  Widget _errorCard(GameProvider game) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _card(
        borderColor: AppTheme.error.withValues(alpha: 0.6),
        child: Row(children: [
          const Icon(Icons.wifi_off_rounded, color: AppTheme.error),
          const SizedBox(width: 12),
          Expanded(child: Text(game.error!, style: AppTheme.bodyMedium)),
          TextButton(onPressed: _load, child: const Text('Reintentar')),
        ]),
      ),
    );
  }

  Widget _fuelCard(GameProvider game) {
    final perAttempt = game.stepsPerAttempt <= 0 ? 2000 : game.stepsPerAttempt;
    final maxedOut = game.maxAttempts >= game.maxAttemptsPerDay;
    final progress = maxedOut ? 1.0 : ((perAttempt - game.stepsUntilNext) / perAttempt).clamp(0.0, 1.0);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.local_fire_department_rounded, color: AppTheme.secondary),
            const SizedBox(width: 8),
            Text('Intentos de hoy', style: AppTheme.titleLarge),
            const Spacer(),
            if (game.isLoading)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Text('${game.attempts}', style: AppTheme.counterMedium.copyWith(color: AppTheme.secondary)),
          ]),
          const SizedBox(height: 12),
          Row(
            children: List.generate(game.maxAttemptsPerDay, (i) {
              final Color color;
              if (i < game.usedToday) {
                color = AppTheme.darkGrey;
              } else if (i < game.maxAttempts) {
                color = AppTheme.secondary;
              } else {
                color = AppTheme.surfaceAlt;
              }
              return Expanded(
                child: Container(
                  height: 10,
                  margin: EdgeInsets.only(right: i == game.maxAttemptsPerDay - 1 ? 0 : 6),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          Text(
            'Pasos registrados hoy: ${formatGameNumber(game.stepsToday)}',
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppTheme.surfaceAlt,
              valueColor: const AlwaysStoppedAnimation(AppTheme.tertiary),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            maxedOut
                ? '¡Ganaste todos los intentos de hoy!'
                : 'Camina ${formatGameNumber(game.stepsUntilNext)} pasos más para ganar otro intento',
            style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
          ),
          const SizedBox(height: 4),
          Text(
            'Cada ${formatGameNumber(perAttempt)} pasos de tus retos = 1 intento (máx. ${game.maxAttemptsPerDay} al día).',
            style: AppTheme.bodySmall.copyWith(color: AppTheme.darkGrey),
          ),
        ],
      ),
    );
  }

  /// Boost de pasos reales: con ≥ N pasos hoy, escudo en las carreras oficiales.
  Widget _shieldCard(GameProvider game) {
    final active = game.hasShield;
    final required = game.shieldStepsRequired <= 0 ? 8000 : game.shieldStepsRequired;
    final progress = (game.shieldStepsToday / required).clamp(0.0, 1.0);
    const blue = Color(0xFF60A5FA);
    return _card(
      borderColor: active ? blue : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(active ? Icons.shield_rounded : Icons.shield_outlined, color: active ? blue : AppTheme.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(active ? '¡Escudo activo!' : 'Escudo de pasos', style: AppTheme.titleLarge),
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletScreen())),
            icon: const Icon(Icons.checkroom_rounded, size: 18),
            label: const Text('Personalizar'),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          active
              ? 'Hoy caminaste ${formatGameNumber(game.shieldStepsToday)} pasos: tus carreras oficiales empiezan con un escudo que perdona un choque.'
              : 'Camina ${formatGameNumber(required)} pasos hoy y tus carreras oficiales empezarán con un escudo (un choque gratis).',
          style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
        ),
        if (!active) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppTheme.surfaceAlt,
              valueColor: const AlwaysStoppedAnimation(blue),
            ),
          ),
          const SizedBox(height: 4),
          Text('${formatGameNumber(game.shieldStepsToday)} / ${formatGameNumber(required)} pasos',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.darkGrey)),
        ],
      ]),
    );
  }

  Widget _playButtons(GameProvider game) {
    final canPlay = game.attempts > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.secondary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: canPlay ? () => _play(official: true) : null,
          icon: const Icon(Icons.directions_run_rounded),
          label: Text(canPlay ? 'Correr (usa 1 intento)' : 'Sin intentos: ¡sal a caminar!'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: () => _play(official: false),
          icon: const Icon(Icons.school_rounded),
          label: const Text('Práctica libre (no guarda puntuación)'),
        ),
      ],
    );
  }

  Widget _statsRow(GameProvider game) {
    Widget stat(IconData icon, Color color, String value, String label) {
      return Expanded(
        child: _card(
          child: Column(children: [
            Icon(icon, color: color),
            const SizedBox(height: 6),
            Text(value, style: AppTheme.titleLarge.copyWith(color: AppTheme.white)),
            Text(label, style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
          ]),
        ),
      );
    }

    return Row(children: [
      stat(Icons.emoji_events_rounded, AppTheme.gold, formatGameNumber(game.bestScore), 'Récord'),
      const SizedBox(width: 10),
      stat(Icons.trending_up_rounded, AppTheme.tertiary, '${game.bestLevelToday}', 'Nivel hoy'),
      const SizedBox(width: 10),
      stat(Icons.leaderboard_rounded, AppTheme.primary, game.myRank == null ? '—' : '#${game.myRank}', 'Ranking'),
    ]);
  }

  Widget _multiplierCard(GameProvider game) {
    final active = game.hasMultiplier;
    return _card(
      borderColor: active ? AppTheme.tertiary : null,
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: (active ? AppTheme.tertiary : AppTheme.darkGrey).withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text('x${game.multiplierValue.toStringAsFixed(1)}',
              style: TextStyle(
                  color: active ? AppTheme.tertiary : AppTheme.grey, fontWeight: FontWeight.w900, fontSize: 13)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(active ? '¡Bonus de XP desbloqueado hoy!' : 'Bonus de XP',
                  style: AppTheme.titleMedium.copyWith(color: active ? AppTheme.tertiary : AppTheme.white)),
              const SizedBox(height: 4),
              Text(
                'Las carreras oficiales que llegan al nivel ${game.multiplierLevel} dan XP: '
                'puntos ÷ 10 × ${game.multiplierValue.toStringAsFixed(1)} (máx. 500 por carrera).',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _howToPlay() {
    Widget row(IconData icon, Color color, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: AppTheme.bodyMedium)),
          ]),
        );

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cómo se juega', style: AppTheme.titleLarge),
          const SizedBox(height: 8),
          row(Icons.swipe_rounded, AppTheme.primary, 'Toca un lado o desliza para cambiar de carril'),
          row(Icons.keyboard_double_arrow_up_rounded, AppTheme.primary, 'Desliza hacia arriba para saltar las vallas'),
          row(Icons.warning_amber_rounded, AppTheme.secondary, 'Los conos y los rivales no se pueden saltar: esquívalos'),
          row(Icons.monetization_on_rounded, AppTheme.gold, 'Encadena monedas para subir el combo (hasta x5)'),
          row(Icons.bolt_rounded, const Color(0xFF22D3EE), 'La bebida energética da TURBO: puntos x2 y arrasas obstáculos'),
          row(Icons.speed_rounded, AppTheme.tertiary, 'Cada 350 m subes de nivel y corres más rápido'),
        ],
      ),
    );
  }

  Widget _leaderboardPreview(GameProvider game) {
    final top = game.leaderboard.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Text('Top corredores', style: AppTheme.titleLarge),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GameLeaderboardScreen()),
            ),
            child: const Text('Ver ranking'),
          ),
        ]),
        const SizedBox(height: 4),
        if (top.isEmpty)
          _card(
            child: Text(
              game.isLoadingLeaderboard ? 'Cargando ranking…' : 'Aún no hay carreras. ¡Sé el primero!',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
            ),
          )
        else
          ...top.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GameLeaderboardTile(entry: e),
              )),
      ],
    );
  }
}
