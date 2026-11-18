import 'package:flutter/material.dart';

/// Catálogo de power-ups ("Ánimo en vivo") que los espectadores mandan al
/// corredor. Debe coincidir con `POWER_UP_TYPES` en
/// `backend/utils/powerUps.js` (el servidor valida el tipo y genera el texto
/// hablado). Ver docs/LIVE_CHEERS.md.
class PowerUpType {
  final String id;
  final String emoji;
  final String label;
  final Color color;

  const PowerUpType(this.id, this.emoji, this.label, this.color);

  static const turbo = PowerUpType('turbo', '🔥', 'Turbo', Color(0xFFFF6B35));
  static const agua = PowerUpType('agua', '💧', 'Agua', Color(0xFF29B6F6));
  static const aplausos = PowerUpType(
    'aplausos',
    '👏',
    'Aplausos',
    Color(0xFFFFCA28),
  );
  static const ultimoKm = PowerUpType(
    'ultimoKm',
    '🏁',
    'Último km',
    Color(0xFFE0E0E0),
  );
  static const ritmo = PowerUpType(
    'ritmo',
    '⚡',
    'Sube ritmo',
    Color(0xFFFFEB3B),
  );
  static const fuerza = PowerUpType(
    'fuerza',
    '💪',
    'Tú puedes',
    Color(0xFFAB47BC),
  );
  static const voz = PowerUpType('voz', '🎙️', 'Voz', Color(0xFF66BB6A));

  /// Botones rápidos de la barra (el de voz se muestra aparte).
  static const quick = [turbo, agua, aplausos, ultimoKm, ritmo, fuerza];
  static const all = [...quick, voz];

  static PowerUpType? byId(String? id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Igual que el cooldown del servidor (POWER_UP_COOLDOWN_MS).
  static const cooldown = Duration(seconds: 5);

  /// Largo máximo del ánimo de voz (MAX_CUSTOM_CHEER_LENGTH).
  static const maxCustomLength = 80;
}
