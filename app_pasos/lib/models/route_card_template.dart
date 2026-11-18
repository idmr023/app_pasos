import 'package:flutter/material.dart';

enum TemplateType {
  cartografo,
  diario,
  distanciaRey,
  cyberHud,
  timeline,
  // Portadas (v4): construidas con widgets en aura_cover_templates.dart,
  // soportan foto de fondo, color de acento, fuente y título personalizados.
  revista,
  neonNocturno,
  minimal,
  polaroid,
  podio,
  dorsal,
  fotoMapa,
  atardecer,
}

extension TemplateTypeX on TemplateType {
  String get id {
    switch (this) {
      case TemplateType.cartografo: return 'cartografo';
      case TemplateType.diario: return 'diario';
      case TemplateType.distanciaRey: return 'distancia_rey';
      case TemplateType.cyberHud: return 'cyber_hud';
      case TemplateType.timeline: return 'timeline';
      case TemplateType.revista: return 'revista';
      case TemplateType.neonNocturno: return 'neon_nocturno';
      case TemplateType.minimal: return 'minimal';
      case TemplateType.polaroid: return 'polaroid';
      case TemplateType.podio: return 'podio';
      case TemplateType.dorsal: return 'dorsal';
      case TemplateType.fotoMapa: return 'foto_mapa';
      case TemplateType.atardecer: return 'atardecer';
    }
  }

  String get displayName {
    switch (this) {
      case TemplateType.cartografo: return 'El Cartógrafo';
      case TemplateType.diario: return 'El Diario';
      case TemplateType.distanciaRey: return 'Distancia Rey';
      case TemplateType.cyberHud: return 'Cyber HUD';
      case TemplateType.timeline: return 'Línea de Tiempo';
      case TemplateType.revista: return 'Portada Revista';
      case TemplateType.neonNocturno: return 'Neón Nocturno';
      case TemplateType.minimal: return 'Minimal';
      case TemplateType.polaroid: return 'Polaroid';
      case TemplateType.podio: return 'Podio';
      case TemplateType.dorsal: return 'Dorsal Retro';
      case TemplateType.fotoMapa: return 'Foto + Mapa';
      case TemplateType.atardecer: return 'Atardecer';
    }
  }

  String get subtitle {
    switch (this) {
      case TemplateType.cartografo: return 'Minimalismo puro sobre mapa 3D';
      case TemplateType.diario: return 'Estética Editorial / Revista';
      case TemplateType.distanciaRey: return 'Río de neón dentro del KM';
      case TemplateType.cyberHud: return 'Interfaz Sci-Fi con Crosshairs';
      case TemplateType.timeline: return 'Storytelling e hitos de carrera';
      case TemplateType.revista: return 'Tu carrera en portada de revista';
      case TemplateType.neonNocturno: return 'Ruta brillante para salidas de noche';
      case TemplateType.minimal: return 'Solo números, tipografía limpia';
      case TemplateType.polaroid: return 'Foto instantánea con nota escrita';
      case TemplateType.podio: return 'Medalla de oro y podio de stats';
      case TemplateType.dorsal: return 'Número de carrera vintage';
      case TemplateType.fotoMapa: return 'Mitad foto, mitad mapa';
      case TemplateType.atardecer: return 'Degradado retro con sol';
    }
  }

  IconData get icon {
    switch (this) {
      case TemplateType.cartografo: return Icons.map;
      case TemplateType.diario: return Icons.auto_stories;
      case TemplateType.distanciaRey: return Icons.workspace_premium;
      case TemplateType.cyberHud: return Icons.radar;
      case TemplateType.timeline: return Icons.timeline;
      case TemplateType.revista: return Icons.menu_book;
      case TemplateType.neonNocturno: return Icons.nightlife;
      case TemplateType.minimal: return Icons.notes;
      case TemplateType.polaroid: return Icons.photo_camera_back;
      case TemplateType.podio: return Icons.military_tech;
      case TemplateType.dorsal: return Icons.confirmation_number;
      case TemplateType.fotoMapa: return Icons.splitscreen;
      case TemplateType.atardecer: return Icons.wb_twilight;
    }
  }

  /// Color de acento por defecto (usado en tarjetas de la grilla y como
  /// acento base de las portadas cuando el usuario no elige uno).
  Color get accent {
    switch (this) {
      case TemplateType.cartografo: return const Color(0xFF00D4FF);
      case TemplateType.diario: return const Color(0xFFF3F4F6);
      case TemplateType.distanciaRey: return const Color(0xFF00F5D4);
      case TemplateType.cyberHud: return const Color(0xFF00FF66);
      case TemplateType.timeline: return const Color(0xFF38BDF8);
      case TemplateType.revista: return const Color(0xFFFF3B30);
      case TemplateType.neonNocturno: return const Color(0xFFFF2BD6);
      case TemplateType.minimal: return const Color(0xFF111111);
      case TemplateType.polaroid: return const Color(0xFFFFB703);
      case TemplateType.podio: return const Color(0xFFFFC94A);
      case TemplateType.dorsal: return const Color(0xFFE63946);
      case TemplateType.fotoMapa: return const Color(0xFF00E5A0);
      case TemplateType.atardecer: return const Color(0xFFFF7A45);
    }
  }

  /// true para las portadas v4 (soportan foto de fondo, acento, fuente y título).
  bool get isCover => index >= TemplateType.revista.index;
}

class AuraMetricsConfig {
  final bool showMap;
  final bool showDistance;
  final bool showPace;
  final bool showTime;
  final bool showCalories;
  final bool showElevation;
  final bool showHeartRate;

  const AuraMetricsConfig({
    this.showMap = true,
    this.showDistance = true,
    this.showPace = true,
    this.showTime = true,
    this.showCalories = true,
    this.showElevation = true,
    this.showHeartRate = false,
  });

  AuraMetricsConfig copyWith({
    bool? showMap,
    bool? showDistance,
    bool? showPace,
    bool? showTime,
    bool? showCalories,
    bool? showElevation,
    bool? showHeartRate,
  }) {
    return AuraMetricsConfig(
      showMap: showMap ?? this.showMap,
      showDistance: showDistance ?? this.showDistance,
      showPace: showPace ?? this.showPace,
      showTime: showTime ?? this.showTime,
      showCalories: showCalories ?? this.showCalories,
      showElevation: showElevation ?? this.showElevation,
      showHeartRate: showHeartRate ?? this.showHeartRate,
    );
  }
}

class RouteCardTemplate {
  final String id;
  final String name;
  final String description;
  final TemplateType type;
  final Color routeColor;
  final Color glowColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color backgroundColor;
  final Color accentColor;
  final double routeLineWidth;
  final double glowWidth;
  final String mapboxStyleId;
  final String layoutType;
  final IconData icon;

  const RouteCardTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.routeColor,
    required this.glowColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.backgroundColor,
    required this.accentColor,
    required this.routeLineWidth,
    required this.glowWidth,
    required this.mapboxStyleId,
    required this.layoutType,
    required this.icon,
  });
}

final List<RouteCardTemplate> auraTemplates = [
  const RouteCardTemplate(
    id: 'cartografo',
    name: 'El Cartógrafo',
    description: 'Mapa 3D al 100% con tarjeta Glassmorphism en la parte inferior',
    type: TemplateType.cartografo,
    routeColor: Color(0xFF00D4FF),
    glowColor: Color(0xFF00D4FF),
    primaryTextColor: Colors.white,
    secondaryTextColor: Color(0xFF8A8A9E),
    backgroundColor: Color(0xFF0A0A1A),
    accentColor: Color(0xFFFF00FF),
    routeLineWidth: 6,
    glowWidth: 18,
    mapboxStyleId: 'mapbox/dark-v11',
    layoutType: 'cartografo',
    icon: Icons.map,
  ),
  const RouteCardTemplate(
    id: 'diario',
    name: 'El Diario',
    description: 'Día de la semana gigante y estética de revista de moda',
    type: TemplateType.diario,
    routeColor: Color(0xFFF3F4F6),
    glowColor: Colors.white24,
    primaryTextColor: Colors.white,
    secondaryTextColor: Color(0xFF9CA3AF),
    backgroundColor: Color(0xFF111827),
    accentColor: Color(0xFFE5E7EB),
    routeLineWidth: 4,
    glowWidth: 8,
    mapboxStyleId: 'mapbox/dark-v11',
    layoutType: 'diario',
    icon: Icons.auto_stories,
  ),
  const RouteCardTemplate(
    id: 'distancia_rey',
    name: 'Distancia Rey',
    description: 'Número de KM masivo usando ShaderMask con la foto/mapa de fondo',
    type: TemplateType.distanciaRey,
    routeColor: Color(0xFFFFD700),
    glowColor: Color(0xFFFFD700),
    primaryTextColor: Colors.white,
    secondaryTextColor: Color(0xFFFFE57F),
    backgroundColor: Color(0xFF0D0D11),
    accentColor: Color(0xFFFFD700),
    routeLineWidth: 6,
    glowWidth: 16,
    mapboxStyleId: 'mapbox/dark-v11',
    layoutType: 'distancia_rey',
    icon: Icons.workspace_premium,
  ),
  const RouteCardTemplate(
    id: 'cyber_hud',
    name: 'Cyber HUD',
    description: 'Interfaz Sci-Fi con verde fósforo, crosshairs y corchetes angulares',
    type: TemplateType.cyberHud,
    routeColor: Color(0xFF00FF66),
    glowColor: Color(0xFF00FF66),
    primaryTextColor: Colors.white,
    secondaryTextColor: Color(0xFF00FF66),
    backgroundColor: Color(0xFF050811),
    accentColor: Color(0xFFFF0055),
    routeLineWidth: 5,
    glowWidth: 15,
    mapboxStyleId: 'mapbox/dark-v11',
    layoutType: 'cyber_hud',
    icon: Icons.radar,
  ),
  const RouteCardTemplate(
    id: 'timeline',
    name: 'Línea de Tiempo',
    description: 'Storytelling e hitos visuales estilo pase de abordar premium',
    type: TemplateType.timeline,
    routeColor: Color(0xFF38BDF8),
    glowColor: Color(0xFF38BDF8),
    primaryTextColor: Colors.white,
    secondaryTextColor: Color(0xFF94A3B8),
    backgroundColor: Color(0xFF0F172A),
    accentColor: Color(0xFF38BDF8),
    routeLineWidth: 4,
    glowWidth: 10,
    mapboxStyleId: 'mapbox/streets-v12',
    layoutType: 'timeline',
    icon: Icons.timeline,
  ),
];

RouteCardTemplate getTemplateById(String id) {
  return auraTemplates.firstWhere((t) => t.id == id, orElse: () => auraTemplates[0]);
}

