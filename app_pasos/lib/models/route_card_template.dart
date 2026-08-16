import 'package:flutter/material.dart';

enum TemplateType {
  cartografo,
  diario,
  distanciaRey,
  cyberHud,
  timeline,
}

extension TemplateTypeX on TemplateType {
  String get id {
    switch (this) {
      case TemplateType.cartografo: return 'cartografo';
      case TemplateType.diario: return 'diario';
      case TemplateType.distanciaRey: return 'distancia_rey';
      case TemplateType.cyberHud: return 'cyber_hud';
      case TemplateType.timeline: return 'timeline';
    }
  }

  String get displayName {
    switch (this) {
      case TemplateType.cartografo: return 'El Cartógrafo';
      case TemplateType.diario: return 'El Diario';
      case TemplateType.distanciaRey: return 'Distancia Rey';
      case TemplateType.cyberHud: return 'Cyber HUD';
      case TemplateType.timeline: return 'Línea de Tiempo';
    }
  }

  String get subtitle {
    switch (this) {
      case TemplateType.cartografo: return 'Minimalismo puro sobre mapa 3D';
      case TemplateType.diario: return 'Estética Editorial / Revista';
      case TemplateType.distanciaRey: return 'Río de neón dentro del KM';
      case TemplateType.cyberHud: return 'Interfaz Sci-Fi con Crosshairs';
      case TemplateType.timeline: return 'Storytelling e hitos de carrera';
    }
  }

  IconData get icon {
    switch (this) {
      case TemplateType.cartografo: return Icons.map;
      case TemplateType.diario: return Icons.auto_stories;
      case TemplateType.distanciaRey: return Icons.workspace_premium;
      case TemplateType.cyberHud: return Icons.radar;
      case TemplateType.timeline: return Icons.timeline;
    }
  }
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

