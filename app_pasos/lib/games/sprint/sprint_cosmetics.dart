import 'package:flutter/material.dart';

/// Equipación del corredor del Sprint (artículos `skin_*` de la tienda de pasos).
class SprintSkin {
  final String id;
  final Color jersey;
  final Color shorts;
  final Color shoeAccent;

  const SprintSkin(this.id, this.jersey, this.shorts, this.shoeAccent);

  static const classic = SprintSkin('skin_classic', Color(0xFF3B82F6), Color(0xFF0F172A), Color(0xFFFF6B35));

  static const Map<String, SprintSkin> all = {
    'skin_classic': classic,
    'skin_fuego': SprintSkin('skin_fuego', Color(0xFFEF4444), Color(0xFF1F1A17), Color(0xFFFF9F1C)),
    'skin_oceano': SprintSkin('skin_oceano', Color(0xFF14B8A6), Color(0xFFF8FAFC), Color(0xFF0EA5E9)),
    'skin_selva': SprintSkin('skin_selva', Color(0xFF10B981), Color(0xFF064E3B), Color(0xFFFACC15)),
    'skin_neon': SprintSkin('skin_neon', Color(0xFFEC4899), Color(0xFF111827), Color(0xFF22D3EE)),
    'skin_oro': SprintSkin('skin_oro', Color(0xFFFFD166), Color(0xFF7C5E10), Color(0xFFFFFFFF)),
  };

  static SprintSkin byId(String? id) => all[id] ?? classic;
}

/// Estela que deja el corredor (artículos `trail_*`).
class SprintTrail {
  final String id;
  final List<Color> colors;

  const SprintTrail(this.id, this.colors);

  static const Map<String, SprintTrail> all = {
    'trail_chispas': SprintTrail('trail_chispas', [Color(0xFFFFD166), Color(0xFFFFF3B0)]),
    'trail_fuego': SprintTrail('trail_fuego', [Color(0xFFFF6B35), Color(0xFFEF4444), Color(0xFFFACC15)]),
    'trail_arcoiris': SprintTrail('trail_arcoiris', [
      Color(0xFFEF4444),
      Color(0xFFF59E0B),
      Color(0xFFFACC15),
      Color(0xFF10B981),
      Color(0xFF3B82F6),
      Color(0xFFA855F7),
    ]),
    'trail_cometa': SprintTrail('trail_cometa', [Color(0xFF22D3EE), Color(0xFF3B82F6), Color(0xFFE0F2FE)]),
  };

  static SprintTrail? byId(String? id) => id == null ? null : all[id];
}
