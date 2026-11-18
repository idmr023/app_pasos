import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../config/theme.dart';
import '../../games/sprint/sprint_cosmetics.dart';
import '../../games/sprint/sprint_game.dart';
import '../../games/sprint/sprint_painter.dart';
import '../../providers/game_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/xp_provider.dart';

/// Formatea enteros con separador de miles (12.345).
String formatGameNumber(int value) {
  final s = value.abs().toString();
  final buf = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Pantalla de juego del Sprint.
///
/// [official] = true consume un intento: al terminar (o abandonar) la
/// puntuación se envía a `POST /api/game/play`. En modo práctica no se
/// guarda nada.
class SprintPlayScreen extends StatefulWidget {
  final bool official;

  const SprintPlayScreen({super.key, required this.official});

  @override
  State<SprintPlayScreen> createState() => _SprintPlayScreenState();
}

class _SprintPlayScreenState extends State<SprintPlayScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late SprintGame _game;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  final FocusNode _focus = FocusNode();
  final math.Random _seedRng = math.Random();

  late bool _official;
  bool _overHandled = false;
  bool _showOver = false;
  bool _submitting = false;
  String? _submitError;
  GameSubmitResult? _result;
  int _bestAtStart = 0;
  bool _ownsWakelock = false;

  // Gestos
  Offset? _pointerStart;
  bool _gestureUsed = false;

  @override
  void initState() {
    super.initState();
    _official = widget.official;
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick);
    _newGame();
    _enableWakelock();
  }

  Future<void> _enableWakelock() async {
    try {
      // Si otra función (tracking en vivo) ya lo tiene activo, no lo tocamos.
      if (await WakelockPlus.enabled) return;
      await WakelockPlus.enable();
      _ownsWakelock = true;
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _game.dispose();
    _focus.dispose();
    if (_ownsWakelock) {
      WakelockPlus.disable().catchError((Object _) {});
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  void _newGame() {
    final provider = context.read<GameProvider>();
    _bestAtStart = provider.bestScore;
    final old = _initialized ? _game : null;
    // Boost de pasos reales: las carreras oficiales empiezan con un escudo.
    final shields = _official && provider.hasShield ? 1 : 0;
    _game = SprintGame(seed: _seedRng.nextInt(1 << 30), bestScore: _bestAtStart, shields: shields)
      ..onEvent = _onEvent;
    _initialized = true;
    // Se libera tras el frame: el painter/AnimatedBuilder anteriores aún lo escuchan.
    if (old != null) WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    _overHandled = false;
    _showOver = false;
    _submitting = false;
    _submitError = null;
    _result = null;
    _restartTicker();
  }

  bool _initialized = false;

  void _restartTicker() {
    if (_ticker.isActive) _ticker.stop();
    _last = Duration.zero;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero ? 0.0 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _game.update(dt);
    if (_game.isOver) {
      if (!_overHandled) {
        _overHandled = true;
        _onGameOver();
      }
      if (!_showOver && (!_game.crashed || _game.overTimer > 0.8)) {
        setState(() => _showOver = true);
      }
      // Deja terminar las partículas y luego libera la CPU.
      if (_game.overTimer > 1.6) {
        _ticker.stop();
      }
    }
  }

  void _onEvent(SprintEventType type) {
    switch (type) {
      case SprintEventType.laneChange:
        HapticFeedback.selectionClick();
        break;
      case SprintEventType.coin:
        HapticFeedback.lightImpact();
        break;
      case SprintEventType.drink:
      case SprintEventType.levelUp:
      case SprintEventType.smash:
      case SprintEventType.newBest:
        HapticFeedback.mediumImpact();
        break;
      case SprintEventType.crash:
        HapticFeedback.heavyImpact();
        break;
      default:
        break;
    }
  }

  void _onGameOver() {
    setState(() {});
    if (_official) _submit();
  }

  Future<void> _submit() async {
    final provider = context.read<GameProvider>();
    final xpProvider = context.read<XpProvider>();
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final result = await provider.submitScore(
        level: _game.level,
        score: _game.score,
        obstaclesDodged: _game.dodged,
        distance: _game.distance.floor(),
        coins: _game.coins,
        maxCombo: _game.maxCombo,
        durationMs: _game.durationMs,
      );
      if (result.xpAwarded > 0) xpProvider.loadXp();
      if (!mounted) return;
      setState(() {
        _result = result;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e.toString().replaceFirst('Exception: ', '');
        _submitting = false;
      });
    }
  }

  // ── Control ───────────────────────────────────────────────────────
  void _pause() {
    if (_game.isRunning || _game.status == SprintStatus.countdown) {
      _game.pause();
      _ticker.stop();
      setState(() {});
    }
  }

  void _resume() {
    if (_game.isPaused) {
      _game.resume();
      _restartTicker();
      setState(() {});
      _focus.requestFocus();
    }
  }

  bool get _needsExitConfirm => _official && !_game.isOver && _game.distance >= 1;

  Future<void> _requestExit() async {
    if (!_needsExitConfirm) {
      Navigator.of(context).pop();
      return;
    }
    _pause();
    final abandon = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('¿Abandonar la carrera?'),
        content: const Text('Tu puntuación actual se guardará y se usará un intento.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Seguir corriendo')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abandonar', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (abandon == true) {
      _game.forfeit();
      _restartTicker();
    } else {
      _resume();
    }
  }

  void _playAgain() {
    final provider = context.read<GameProvider>();
    if (_official && provider.attempts <= 0) _official = false;
    setState(_newGame);
    _focus.requestFocus();
  }

  void _onPointerDown(PointerDownEvent e) {
    _pointerStart = e.localPosition;
    _gestureUsed = false;
  }

  void _onPointerMove(PointerMoveEvent e) {
    final start = _pointerStart;
    if (start == null || _gestureUsed) return;
    final d = e.localPosition - start;
    const threshold = 26.0;
    if (d.distance < threshold) return;
    _gestureUsed = true;
    if (d.dx.abs() > d.dy.abs()) {
      d.dx < 0 ? _game.moveLeft() : _game.moveRight();
    } else if (d.dy < 0) {
      _game.jump();
    } else {
      _game.drop();
    }
  }

  void _onPointerUp(PointerUpEvent e, double width) {
    if (!_gestureUsed && _pointerStart != null) {
      e.localPosition.dx < width / 2 ? _game.moveLeft() : _game.moveRight();
    }
    _pointerStart = null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      _game.moveLeft();
    } else if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD) {
      _game.moveRight();
    } else if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW || key == LogicalKeyboardKey.space) {
      _game.jump();
    } else if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS) {
      _game.drop();
    } else if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.keyP) {
      _game.isPaused ? _resume() : _pause();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ── UI ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              fit: StackFit.expand,
              children: [
                Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: (e) => _onPointerUp(e, constraints.maxWidth),
                  child: RepaintBoundary(
                    child: Selector<WalletProvider, (String, String?)>(
                      selector: (_, w) => (w.equippedSkin, w.equippedTrail),
                      builder: (context, eq, _) => CustomPaint(
                        painter: SprintPainter(
                          _game,
                          skin: SprintSkin.byId(eq.$1),
                          trail: SprintTrail.byId(eq.$2),
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: AnimatedBuilder(animation: _game, builder: (context, _) => _buildHud()),
                ),
                _buildTopBar(),
                if (_game.isPaused) _buildPauseOverlay(),
                if (_game.isOver && _showOver) _buildGameOverOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: AnimatedBuilder(
            animation: _game,
            builder: (context, _) => _game.isOver
                ? const SizedBox.shrink()
                : Material(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Pausa',
                      icon: const Icon(Icons.pause_rounded, color: Colors.white),
                      onPressed: _pause,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildHud() {
    final g = _game;
    final best = math.max(_bestAtStart, g.score);
    return SafeArea(
      child: Stack(
        children: [
          // Puntuación y récord
          Positioned(
            left: 16,
            top: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatGameNumber(g.score),
                    style: AppTheme.counterMedium.copyWith(color: Colors.white, shadows: _shadows)),
                Text('Récord ${formatGameNumber(best)}',
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.gold, shadows: _shadows)),
                const SizedBox(height: 8),
                Row(children: [
                  _chip(Icons.straighten_rounded, '${formatGameNumber(g.distance.floor())} m', Colors.white),
                  const SizedBox(width: 6),
                  _chip(Icons.monetization_on_rounded, '${g.coins}', AppTheme.gold),
                  if (g.shields > 0) ...[
                    const SizedBox(width: 6),
                    _chip(Icons.shield_rounded, 'x${g.shields}', const Color(0xFF60A5FA)),
                  ],
                ]),
                const SizedBox(height: 6),
                if (g.multiplier > 1) _multiplierChip(g),
                if (g.isTurbo) ...[const SizedBox(height: 6), _turboBar(g)],
              ],
            ),
          ),
          // Nivel
          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: Center(child: _levelIndicator(g)),
          ),
          if (!_official)
            Positioned(
              top: 60,
              right: 14,
              child: _chip(Icons.school_rounded, 'PRÁCTICA', AppTheme.grey),
            ),
          if (g.status == SprintStatus.countdown || (g.isRunning && g.elapsed < 0.6)) _countdown(g),
          if (g.levelBanner > 0) _levelBanner(g),
          if (g.status == SprintStatus.countdown) _hint(),
        ],
      ),
    );
  }

  static const _shadows = [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))];

  Widget _chip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _multiplierChip(SprintGame g) {
    return Container(
      width: 96,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('x${g.multiplier}  COMBO ${g.combo}',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: g.comboFraction,
              minHeight: 3,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _turboBar(SprintGame g) {
    return Container(
      width: 96,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0891B2).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.bolt_rounded, color: Colors.white, size: 13),
            Text(' TURBO x2', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: g.turboFraction,
              minHeight: 3,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _levelIndicator(SprintGame g) {
    return Container(
      width: 92,
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Text('NIVEL ${g.level}',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: g.levelProgress,
            minHeight: 3,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation(AppTheme.tertiary),
          ),
        ),
      ]),
    );
  }

  Widget _countdown(SprintGame g) {
    final text = g.status == SprintStatus.countdown ? '${g.countdown.ceil()}' : '¡YA!';
    final frac = g.status == SprintStatus.countdown ? g.countdown - g.countdown.floor() : 1 - g.elapsed / 0.6;
    return Center(
      child: Transform.scale(
        scale: 0.8 + frac * 0.5,
        child: Opacity(
          opacity: frac.clamp(0.0, 1.0),
          child: Text(
            text,
            style: AppTheme.displayLarge.copyWith(
              fontSize: 84,
              color: g.status == SprintStatus.countdown ? Colors.white : AppTheme.tertiary,
              shadows: _shadows,
            ),
          ),
        ),
      ),
    );
  }

  Widget _levelBanner(SprintGame g) {
    final t = g.levelBanner / 1.8;
    return Align(
      alignment: const Alignment(0, -0.45),
      child: Opacity(
        opacity: (t * 2).clamp(0.0, 1.0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('NIVEL ${g.level}',
              style: AppTheme.displayMedium.copyWith(color: AppTheme.gold, fontSize: 40, shadows: _shadows)),
          Text('¡Más rápido!',
              style: AppTheme.titleMedium.copyWith(color: Colors.white, shadows: _shadows)),
        ]),
      ),
    );
  }

  Widget _hint() {
    return Align(
      alignment: const Alignment(0, 0.95),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'Toca izquierda/derecha o desliza para cambiar de carril.\nDesliza hacia arriba para saltar las vallas.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
        ),
      ),
    );
  }

  Widget _scrim({required Widget child}) {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }

  Widget _buildPauseOverlay() {
    return _scrim(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pause_circle_filled_rounded, color: Colors.white, size: 64),
          const SizedBox(height: 12),
          Text('Pausa', style: AppTheme.headlineLarge.copyWith(color: Colors.white)),
          const SizedBox(height: 24),
          SizedBox(
            width: 220,
            child: ElevatedButton.icon(
              onPressed: _resume,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Continuar'),
            ),
          ),
          if (!_official) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: 220,
              child: OutlinedButton.icon(
                onPressed: _playAgain,
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Reiniciar'),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: 220,
            child: TextButton(
              onPressed: _requestExit,
              child: Text(_needsExitConfirm ? 'Abandonar carrera' : 'Salir',
                  style: const TextStyle(color: AppTheme.grey)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    final g = _game;
    final provider = context.watch<GameProvider>();
    final isNewBest = _official ? (_result?.isNewBest ?? false) : g.score > _bestAtStart && g.score > 0;
    final canPlayOfficial = _official && provider.attempts > 0;
    final secs = g.elapsed.floor();
    final time = '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';

    return _scrim(
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(g.crashed ? '¡Choque!' : 'Carrera terminada',
                  style: AppTheme.headlineMedium.copyWith(color: Colors.white)),
              const SizedBox(height: 4),
              Text(_official ? 'Carrera oficial' : 'Práctica (no se guarda)',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
              const SizedBox(height: 14),
              Text(formatGameNumber(g.score), style: AppTheme.counterLarge.copyWith(color: Colors.white)),
              Text('puntos', style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
              if (isNewBest) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.emoji_events_rounded, color: AppTheme.gold, size: 16),
                    SizedBox(width: 6),
                    Text('¡Nuevo récord!', style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.35,
                children: [
                  _stat('Distancia', '${formatGameNumber(g.distance.floor())} m'),
                  _stat('Nivel', '${g.level}'),
                  _stat('Monedas', '${g.coins}'),
                  _stat('Combo máx.', '${g.maxCombo}'),
                  _stat('Esquivados', '${g.dodged}'),
                  _stat('Tiempo', time),
                ],
              ),
              const SizedBox(height: 14),
              if (_official) _submissionStatus(provider),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _playAgain,
                  icon: const Icon(Icons.replay_rounded),
                  label: Text(canPlayOfficial
                      ? 'Otra carrera (${provider.attempts} ${provider.attempts == 1 ? 'intento' : 'intentos'})'
                      : 'Practicar otra vez'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Volver'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _submissionStatus(GameProvider provider) {
    if (_submitting) {
      return const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 10),
        Text('Guardando puntuación…', style: TextStyle(color: AppTheme.grey)),
      ]);
    }
    if (_submitError != null) {
      return Column(children: [
        Text(_submitError!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.error)),
        TextButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reintentar envío'),
        ),
      ]);
    }
    final result = _result;
    if (result == null) return const SizedBox.shrink();
    final xpText = result.xpAwarded > 0
        ? '+${result.xpAwarded} XP ganados'
        : 'Llega al nivel ${provider.multiplierLevel} para ganar XP';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.auto_awesome_rounded,
              size: 18, color: result.xpAwarded > 0 ? AppTheme.tertiary : AppTheme.grey),
          const SizedBox(width: 6),
          Flexible(
            child: Text(xpText,
                style: TextStyle(
                    color: result.xpAwarded > 0 ? AppTheme.tertiary : AppTheme.grey, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          'Intentos restantes hoy: ${result.attemptsLeft}',
          style: const TextStyle(color: AppTheme.grey, fontSize: 12),
        ),
      ]),
    );
  }

  Widget _stat(String label, String value) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppTheme.grey, fontSize: 11)),
      ]),
    );
  }
}
