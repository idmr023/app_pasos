import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/power_up.dart';
import '../providers/tracking_provider.dart';

/// Barra de power-ups del espectador: botones de ánimo con anillo de
/// cooldown animado (espejo del rate limit del servidor) + botón de ánimo de
/// voz (texto corto que el corredor escucha por TTS). Ver docs/LIVE_CHEERS.md.
class PowerUpBar extends StatefulWidget {
  final TrackingProvider provider;

  const PowerUpBar({super.key, required this.provider});

  @override
  State<PowerUpBar> createState() => _PowerUpBarState();
}

class _PowerUpBarState extends State<PowerUpBar>
    with SingleTickerProviderStateMixin {
  // value 0 = recién enviado (anillo lleno), 1 = cooldown terminado.
  late final AnimationController _cooldown = AnimationController(
    vsync: this,
    duration: PowerUpType.cooldown,
    value: 1,
  );
  DateTime? _syncedUntil;
  String? _lastSentId;

  @override
  void dispose() {
    _cooldown.dispose();
    super.dispose();
  }

  /// Sincroniza el anillo con `provider.powerUpCooldownUntil` (que también
  /// se ajusta si el servidor responde POWERUP_COOLDOWN).
  void _syncCooldown() {
    final until = widget.provider.powerUpCooldownUntil;
    if (until == _syncedUntil) return;
    _syncedUntil = until;
    if (until == null) {
      _cooldown.value = 1;
      return;
    }
    final remaining = until.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      _cooldown.value = 1;
      return;
    }
    final total = PowerUpType.cooldown.inMilliseconds;
    final remainingMs = math.min(remaining.inMilliseconds, total);
    _cooldown.value = 1 - remainingMs / total;
    _cooldown.animateTo(1, duration: Duration(milliseconds: remainingMs));
  }

  bool get _coolingDown => _cooldown.value < 1;

  Future<void> _send(PowerUpType type, {String? text}) async {
    if (_coolingDown) {
      HapticFeedback.selectionClick();
      return;
    }
    final ok = await widget.provider.sendPowerUp(type, text: text);
    if (!mounted) return;
    if (ok) {
      HapticFeedback.heavyImpact();
      setState(() => _lastSentId = type.id);
    }
  }

  Future<void> _openVoiceCheer() async {
    if (_coolingDown) {
      HapticFeedback.selectionClick();
      return;
    }
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _VoiceCheerDialog(),
    );
    if (text == null || text.isEmpty || !mounted) return;
    await _send(PowerUpType.voz, text: text);
  }

  @override
  Widget build(BuildContext context) {
    // No tocar el AnimationController durante build: se sincroniza tras el
    // frame (el bar se reconstruye con cada notifyListeners del provider).
    if (widget.provider.powerUpCooldownUntil != _syncedUntil) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncCooldown();
      });
    }
    final enabled = !widget.provider.trackingStopped;
    return AnimatedBuilder(
      animation: _cooldown,
      builder: (context, _) {
        final progress = _cooldown.value;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              for (final type in PowerUpType.quick) ...[
                _PowerUpButton(
                  key: ValueKey('powerUp_${type.id}'),
                  type: type,
                  progress: progress,
                  enabled: enabled,
                  popped: _lastSentId == type.id && progress < 0.15,
                  onTap: () => _send(type),
                ),
                const SizedBox(width: 8),
              ],
              _PowerUpButton(
                key: const ValueKey('powerUp_voz'),
                type: PowerUpType.voz,
                progress: progress,
                enabled: enabled,
                popped: _lastSentId == PowerUpType.voz.id && progress < 0.15,
                onTap: _openVoiceCheer,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PowerUpButton extends StatelessWidget {
  final PowerUpType type;
  final double progress; // 0..1 del cooldown (1 = listo)
  final bool enabled;
  final bool popped;
  final VoidCallback onTap;

  const _PowerUpButton({
    super.key,
    required this.type,
    required this.progress,
    required this.enabled,
    required this.popped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ready = enabled && progress >= 1;
    return Tooltip(
      message: type.label,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: popped ? 1.25 : 1,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              child: SizedBox(
                width: 46,
                height: 46,
                child: CustomPaint(
                  painter: _CooldownRingPainter(
                    progress: enabled ? progress : 1,
                    color: type.color,
                  ),
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: ready ? 1 : 0.45,
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        type.emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              type.label,
              style: TextStyle(
                fontSize: 9,
                color: ready ? Colors.white70 : Colors.white30,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fondo circular + anillo que se rellena a medida que pasa el cooldown.
class _CooldownRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CooldownRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 2;
    final ready = progress >= 1;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color =
            ready
                ? color.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.06),
    );
    final ring =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
    canvas.drawCircle(
      center,
      radius,
      ring..color = Colors.white.withValues(alpha: 0.12),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      ring..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _CooldownRingPainter old) =>
      old.progress != progress || old.color != color;
}

/// "Energía del público": total de ánimos, nº de fans y top supporter.
class CrowdEnergyChip extends StatelessWidget {
  final int total;
  final int supporters;
  final Map<String, dynamic>? topSupporter;

  const CrowdEnergyChip({
    super.key,
    required this.total,
    required this.supporters,
    this.topSupporter,
  });

  @override
  Widget build(BuildContext context) {
    final topName = topSupporter?['name'];
    final topCount = topSupporter?['count'];
    final text =
        total == 0
            ? 'Energía del público: aún sin ánimos'
            : '$total ${total == 1 ? 'ánimo' : 'ánimos'} · '
                '$supporters ${supporters == 1 ? 'fan' : 'fans'}'
                '${topName != null ? ' · Top: $topName ($topCount)' : ''}';
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder:
          (child, anim) => ScaleTransition(scale: anim, child: child),
      child: Container(
        key: ValueKey('crowdEnergy_$total'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: total > 0 ? 0.16 : 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: total > 0 ? 0.5 : 0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                key: const ValueKey('crowdEnergyText'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo del ánimo de voz. Es un StatefulWidget para que el
/// TextEditingController viva lo mismo que el diálogo (disponerlo justo tras
/// `pop` fallaba durante la animación de cierre).
class _VoiceCheerDialog extends StatefulWidget {
  const _VoiceCheerDialog();

  @override
  State<_VoiceCheerDialog> createState() => _VoiceCheerDialogState();
}

class _VoiceCheerDialogState extends State<_VoiceCheerDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('🎙️ Ánimo de voz'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'El corredor lo escuchará en voz alta.',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('voiceCheerField'),
            controller: _controller,
            autofocus: true,
            maxLength: PowerUpType.maxCustomLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: '¡Vamos, que ya casi llegas!',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('voiceCheerSend'),
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}
