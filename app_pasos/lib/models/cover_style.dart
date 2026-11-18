import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Sticker colocado sobre la portada. [alignment] va de -1 a 1 en cada eje
/// (relativo a la card), así se exporta igual en cualquier tamaño.
class CoverSticker {
  final String text;

  /// true = badge de texto (píldora con el color de acento); false = emoji.
  final bool isBadge;
  final Alignment alignment;

  const CoverSticker({
    required this.text,
    this.isBadge = false,
    this.alignment = Alignment.center,
  });

  CoverSticker copyWith({Alignment? alignment}) =>
      CoverSticker(text: text, isBadge: isBadge, alignment: alignment ?? this.alignment);
}

/// Opciones de personalización de una portada. Inmutable (`copyWith`).
///
/// Las fotos viven SOLO en memoria como bytes (no se suben al backend). Se usan
/// bytes + `Image.memory` en lugar de `dart:io File` para que funcione en web.
class CoverStyle {
  /// Foto de fondo elegida de la galería / cámara.
  final Uint8List? photoBytes;
  final BoxFit photoFit;

  /// Capa negra encima de la foto (0 = nada, 0.85 = casi negro).
  final double photoDarken;

  /// Sigma del desenfoque gaussiano (0 = nítido).
  final double photoBlur;

  /// Encuadre de la foto (-1..1 en cada eje).
  final Alignment photoAlignment;

  /// Zoom extra sobre la foto (1 = sin zoom).
  final double photoZoom;

  /// Foto pequeña opcional (inset) superpuesta en una esquina.
  final Uint8List? insetBytes;
  final Alignment insetAlignment;

  /// null = color por defecto de la plantilla.
  final Color? accent;

  /// Nombre de Google Font; null = fuente por defecto de la plantilla.
  final String? fontFamily;

  /// Título personalizado; null/vacío = título de la ruta.
  final String? customTitle;

  final List<CoverSticker> stickers;

  const CoverStyle({
    this.photoBytes,
    this.photoFit = BoxFit.cover,
    this.photoDarken = 0.35,
    this.photoBlur = 0,
    this.photoAlignment = Alignment.center,
    this.photoZoom = 1,
    this.insetBytes,
    this.insetAlignment = Alignment.topRight,
    this.accent,
    this.fontFamily,
    this.customTitle,
    this.stickers = const [],
  });

  bool get hasPhoto => photoBytes != null;

  CoverStyle copyWith({
    Uint8List? photoBytes,
    bool clearPhoto = false,
    BoxFit? photoFit,
    double? photoDarken,
    double? photoBlur,
    Alignment? photoAlignment,
    double? photoZoom,
    Uint8List? insetBytes,
    bool clearInset = false,
    Alignment? insetAlignment,
    Color? accent,
    bool clearAccent = false,
    String? fontFamily,
    bool clearFont = false,
    String? customTitle,
    List<CoverSticker>? stickers,
  }) {
    return CoverStyle(
      photoBytes: clearPhoto ? null : (photoBytes ?? this.photoBytes),
      photoFit: photoFit ?? this.photoFit,
      photoDarken: photoDarken ?? this.photoDarken,
      photoBlur: photoBlur ?? this.photoBlur,
      photoAlignment: photoAlignment ?? this.photoAlignment,
      photoZoom: photoZoom ?? this.photoZoom,
      insetBytes: clearInset ? null : (insetBytes ?? this.insetBytes),
      insetAlignment: insetAlignment ?? this.insetAlignment,
      accent: clearAccent ? null : (accent ?? this.accent),
      fontFamily: clearFont ? null : (fontFamily ?? this.fontFamily),
      customTitle: customTitle ?? this.customTitle,
      stickers: stickers ?? this.stickers,
    );
  }
}

/// Fuentes de Google Fonts disponibles en el editor de portadas.
const List<String> coverFonts = [
  'Bebas Neue',
  'Montserrat',
  'Oswald',
  'Playfair Display',
  'Permanent Marker',
  'Orbitron',
];

/// Colores de acento sugeridos en el editor.
const List<Color> coverAccentPresets = [
  Color(0xFFFF3B30),
  Color(0xFFFF7A45),
  Color(0xFFFFC94A),
  Color(0xFF00E5A0),
  Color(0xFF00D4FF),
  Color(0xFF3B82F6),
  Color(0xFF8B5CF6),
  Color(0xFFFF2BD6),
  Color(0xFFFFFFFF),
  Color(0xFF111111),
];

const List<String> coverEmojiStickers = [
  '🔥', '🏃', '⚡', '🏆', '💪', '🥇', '😅', '🌄', '🎉', '❤️', '🚀', '👟', '🌙', '☀️', '🥵', '🎧',
];

const List<String> coverBadgeStickers = [
  'NUEVO PR',
  'MODO BESTIA',
  'DOMINGO LARGO',
  'SIN EXCUSAS',
  'KM FELICES',
  'DÍA 1',
];
