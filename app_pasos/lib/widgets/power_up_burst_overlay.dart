import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/power_up.dart';

/// Overlay animado del corredor: cada power-up recibido lanza una "ráfaga"
/// (emoji grande que sube con brillo + partículas + toast con el nombre de
/// quien lo envía). No bloquea toques (IgnorePointer) y nunca reemplaza el
/// contenido de la pantalla. Ver docs/LIVE_CHEERS.md.
class PowerUpBurstOverlay extends StatefulWidget {
  final Stream<Map<String, dynamic>> events;
  final Widget child;

  const PowerUpBurstOverlay({
    super.key,
    required this.events,
    required this.child,
  });

  @override
  State<PowerUpBurstOverlay> createState() => _PowerUpBurstOverlayState();
}

class _PowerUpBurstOverlayState extends State<PowerUpBurstOverlay> {
  static const _maxBursts = 4;
  final List<_BurstData> _bursts = [];
  final math.Random _random = math.Random();
  StreamSubscription<Map<String, dynamic>>? _sub;
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    _sub = widget.events.listen(_onPowerUp);
  }

  @override
  void didUpdateWidget(covariant PowerUpBurstOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events != widget.events) {
      _sub?.cancel();
      _sub = widget.events.listen(_onPowerUp);
    }
  }

  void _onPowerUp(Map<String, dynamic> event) {
    if (!mounted) return;
    final type = PowerUpType.byId(event['type'] as String?);
    final emoji = (event['emoji'] as String?) ?? type?.emoji ?? '🔥';
    final color = type?.color ?? const Color(0xFFFF6B35);
    final sender = (event['senderName'] as String?) ?? 'Alguien';
    final text =
        type?.id == PowerUpType.voz.id
            ? '$sender: ${event['text'] ?? ''}'
            : (event['speech'] as String?) ?? '$sender te manda ánimo';
    HapticFeedback.mediumImpact();
    setState(() {
      if (_bursts.length >= _maxBursts) _bursts.removeAt(0);
      _bursts.add(
        _BurstData(
          id: _nextId++,
          emoji: emoji,
          color: color,
          text: text,
          // Posición horizontal aleatoria (fracción del ancho) para que
          // ráfagas simultáneas no se superpongan exactamente.
          x: 0.25 + _random.nextDouble() * 0.5,
          seed: _random.nextInt(1 << 20),
        ),
      );
    });
  }

  void _remove(int id) {
    if (!mounted) return;
    setState(() => _bursts.removeWhere((b) => b.id == id));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: Stack(
              children: [
                for (final b in _bursts)
                  _Burst(
                    key: ValueKey('burst_${b.id}'),
                    data: b,
                    onDone: () => _remove(b.id),
                  ),
                // Toast del ánimo más reciente.
                if (_bursts.isNotEmpty)
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: _CheerToast(
                      key: ValueKey('toast_${_bursts.last.id}'),
                      data: _bursts.last,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BurstData {
  final int id;
  final String emoji;
  final Color color;
  final String text;
  final double x;
  final int seed;

  _BurstData({
    required this.id,
    required this.emoji,
    required this.color,
    required this.text,
    required this.x,
    required this.seed,
  });
}

class _Burst extends StatefulWidget {
  final _BurstData data;
  final VoidCallback onDone;

  const _Burst({super.key, required this.data, required this.onDone});

  @override
  State<_Burst> createState() => _BurstState();
}

class _BurstState extends State<_Burst> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<Offset> _particleDirs;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(widget.data.seed);
    _particleDirs = List.generate(7, (i) {
      final angle = (i / 7) * 2 * math.pi + rnd.nextDouble() * 0.6;
      return Offset(math.cos(angle), math.sin(angle));
    });
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            // Sube desde el 80% al 25% de la altura con ease-out.
            final rise = Curves.easeOutCubic.transform(t);
            final cy = h * (0.8 - 0.55 * rise);
            final cx = w * widget.data.x;
            // Pop: 0.3 -> 1.5 (rebote) -> 1.1
            final scale =
                t < 0.25
                    ? 0.3 + Curves.easeOutBack.transform(t / 0.25) * 1.2
                    : 1.5 - 0.4 * ((t - 0.25) / 0.75);
            final opacity = t > 0.75 ? (1 - (t - 0.75) / 0.25) : 1.0;
            final glow = (t < 0.3 ? t / 0.3 : 1 - (t - 0.3) / 0.7).clamp(
              0.0,
              1.0,
            );
            // Partículas: salen del centro en el primer 60% de la animación.
            final pt = (t / 0.6).clamp(0.0, 1.0);
            final pDist = Curves.easeOut.transform(pt) * 90;
            final pOpacity = (1 - pt).clamp(0.0, 1.0);

            return Stack(
              children: [
                // Brillo de borde inferior (toda la pantalla "se enciende").
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, 1.2),
                        radius: 1.2,
                        colors: [
                          widget.data.color.withValues(alpha: 0.28 * glow),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                for (final d in _particleDirs)
                  Positioned(
                    left: cx + d.dx * pDist - 10,
                    top: cy + d.dy * pDist - 10,
                    child: Opacity(
                      opacity: pOpacity,
                      child: Text(
                        widget.data.emoji,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                Positioned(
                  left: cx - 50,
                  top: cy - 50,
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 100,
                        height: 100,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: widget.data.color.withValues(
                                alpha: 0.65 * glow,
                              ),
                              blurRadius: 40,
                              spreadRadius: 6,
                            ),
                          ],
                        ),
                        child: Text(
                          widget.data.emoji,
                          style: const TextStyle(fontSize: 54),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CheerToast extends StatefulWidget {
  final _BurstData data;

  const _CheerToast({super.key, required this.data});

  @override
  State<_CheerToast> createState() => _CheerToastState();
}

class _CheerToastState extends State<_CheerToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        final inT = Curves.easeOutBack.transform((t / 0.15).clamp(0.0, 1.0));
        final opacity = t > 0.8 ? 1 - (t - 0.8) / 0.2 : 1.0;
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -30 * (1 - inT)),
            child: child,
          ),
        );
      },
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xEE12172B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: widget.data.color, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: widget.data.color.withValues(alpha: 0.45),
                blurRadius: 18,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.data.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.data.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
