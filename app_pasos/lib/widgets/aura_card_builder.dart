import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/route.dart';
import '../../models/route_card_template.dart';
import '../../widgets/aura_card_composer.dart';

/// MOLDE 1: "El Cartógrafo" — pintado 100% por [AuraCardPainter].
class CartografoTemplateWidget extends StatelessWidget {
  final AuraData data;
  final AuraMetricsConfig config;
  final ui.Image? mapImage;

  const CartografoTemplateWidget({
    super.key,
    required this.data,
    required this.config,
    this.mapImage,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: AuraCardPainter(
        mapImage: mapImage,
        stats: data.toStatsMap(),
        template: getTemplateById(TemplateType.cartografo.id),
        metricsConfig: config,
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// MOLDE 2: "El Diario" — pintado 100% por [AuraCardPainter].
class DiarioTemplateWidget extends StatelessWidget {
  final AuraData data;
  final AuraMetricsConfig config;
  final ui.Image? mapImage;

  const DiarioTemplateWidget({
    super.key,
    required this.data,
    required this.config,
    this.mapImage,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: AuraCardPainter(
        mapImage: mapImage,
        stats: data.toStatsMap(),
        template: getTemplateById(TemplateType.diario.id),
        metricsConfig: config,
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// MOLDE 3: "Distancia Rey" — El Río de Neón.
///
/// La ruta GPS del usuario (pre-renderizada como textura neón en
/// [AuraData.routeTexture]) vive ÚNICAMENTE dentro de la silueta de los
/// números gigantes, usando ShaderMask + ImageShader con BlendMode.srcIn.
/// El fondo permanece limpio (negro puro).
class DistanciaReyTemplateWidget extends StatelessWidget {
  final AuraData data;
  final AuraMetricsConfig config;
  final ui.Image? mapImage;

  const DistanciaReyTemplateWidget({
    super.key,
    required this.data,
    required this.config,
    this.mapImage,
  });

  @override
  Widget build(BuildContext context) {
    final distanceStr = data.distanceKm.toStringAsFixed(1);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Fondo limpio — la ruta NO se dibuja aquí
        Container(color: Colors.black),

        // 2. Números MASIVOS con la ruta GPS como textura interna
        if (config.showDistance)
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (Rect bounds) {
                  final texture = data.routeTexture;
                  if (texture != null) {
                    // Escala la textura GPS para cubrir exactamente los bounds del texto
                    final matrix = Matrix4.identity()
                      ..scaleByDouble(bounds.width / texture.width, bounds.height / texture.height, 1.0, 1.0);
                    return ImageShader(
                      texture,
                      TileMode.clamp,
                      TileMode.clamp,
                      matrix.storage,
                    );
                  }
                  // Fallback si la ruta no tiene coordenadas GPS
                  return const LinearGradient(
                    colors: [Color(0xFF00F5D4), Color(0xFF7B2CBF)],
                  ).createShader(bounds);
                },
                child: Text(
                  distanceStr,
                  style: GoogleFonts.bebasNeue(
                    fontSize: 320,
                    fontWeight: FontWeight.w400,
                    height: 0.9,
                    letterSpacing: -4,
                  ),
                ),
              ),
            ),
          ),

        // 3. Etiqueta "KM" flotante
        if (config.showDistance)
          Positioned(
            top: 24,
            right: 24,
            child: Text(
              'KM',
              style: GoogleFonts.bebasNeue(
                fontSize: 28,
                color: Colors.white54,
                letterSpacing: 6,
              ),
            ),
          ),

        // 4. Panel de métricas complementarias — cápsulas transparentes
        Positioned(
          bottom: 32,
          left: 16,
          right: 16,
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (config.showPace) _buildSmallStat('RITMO', '${data.pace} /km'),
              if (config.showTime) _buildSmallStat('TIEMPO', data.duration),
              if (config.showCalories) _buildSmallStat('CALORÍAS', '${data.calories} kcal'),
              if (config.showElevation) _buildSmallStat('ELEVACIÓN', '+${data.elevationGain}m'),
              if (config.showHeartRate) _buildSmallStat('FC', '${data.heartRate} bpm'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSmallStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 1.5),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// MOLDE 4: "Cyber HUD" — Sci-Fi Cyberpunk 2077 (tipografía Orbitron).
class CyberHudTemplateWidget extends StatelessWidget {
  final AuraData data;
  final AuraMetricsConfig config;
  final ui.Image? mapImage;

  const CyberHudTemplateWidget({
    super.key,
    required this.data,
    required this.config,
    this.mapImage,
  });

  @override
  Widget build(BuildContext context) {
    const neonGreen = Color(0xFF00FF66);
    const neonPink = Color(0xFFFF0055);

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: const Color(0xFF050811)),

        CustomPaint(
          painter: CyberHudPainter(primaryColor: neonGreen, accentColor: neonPink),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Sci-Fi con brackets
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, color: neonGreen),
                      const SizedBox(width: 8),
                      Text(
                        '[ SYS.AURA // V3.0 ]',
                        style: GoogleFonts.orbitron(
                          color: neonGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '[LIVE]',
                    style: GoogleFonts.orbitron(
                      color: neonPink,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 2),

              // Bloque Distancia Neón con glow
              if (config.showDistance)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TARGET_DISTANCE',
                        style: GoogleFonts.orbitron(color: Colors.white38, fontSize: 9, letterSpacing: 3),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            data.distanceKm.toStringAsFixed(2),
                            style: GoogleFonts.orbitron(
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: const [Shadow(color: neonGreen, blurRadius: 12)],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'KM',
                            style: GoogleFonts.orbitron(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: neonGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Barra de progreso Sci-Fi
              Container(
                height: 3,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (data.distanceKm / 42.195).clamp(0.05, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: neonGreen,
                      boxShadow: const [BoxShadow(color: neonGreen, blurRadius: 6)],
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // Grilla de métricas HUD
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (config.showPace)
                    _buildHudCard('PACE_AVG', '${data.pace} /km', neonGreen),
                  if (config.showTime)
                    _buildHudCard('ELAPSED', data.duration, neonPink),
                  if (config.showCalories)
                    _buildHudCard('CAL_BURN', '${data.calories} KCAL', neonPink),
                  if (config.showElevation)
                    _buildHudCard('ALT_GAIN', '+${data.elevationGain}M', neonGreen),
                  if (config.showHeartRate)
                    _buildHudCard('HEART_RATE', '${data.heartRate} BPM', neonPink),
                ],
              ),

              const SizedBox(height: 14),

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'APP_PASOS',
                    style: GoogleFonts.orbitron(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 8,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    'PASOS_OS',
                    style: GoogleFonts.orbitron(
                      color: neonGreen.withValues(alpha: 0.4),
                      fontSize: 8,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHudCard(String tag, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1322).withValues(alpha: 0.9),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 0.8),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.15), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tag,
            style: GoogleFonts.orbitron(
              color: accent.withValues(alpha: 0.65),
              fontSize: 7,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// MOLDE 5: "Línea de Tiempo" — pintado 100% por [AuraCardPainter].
class TimelineTemplateWidget extends StatelessWidget {
  final AuraData data;
  final AuraMetricsConfig config;
  final ui.Image? mapImage;

  const TimelineTemplateWidget({
    super.key,
    required this.data,
    required this.config,
    this.mapImage,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: AuraCardPainter(
        mapImage: mapImage,
        stats: data.toStatsMap(),
        template: getTemplateById(TemplateType.timeline.id),
        metricsConfig: config,
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// Data DTO unificada para alimentar los moldes.
class AuraData {
  final String title;
  final double distanceKm;
  final String pace;
  final String duration;
  final int elevationGain;
  final int calories;
  final int heartRate;
  final DateTime date;
  final List<Coordinate> coordinates;

  /// Textura neón de la ruta GPS (pre-renderizada por RouteTextureRenderer).
  /// Solo la consume "Distancia Rey".
  final ui.Image? routeTexture;

  const AuraData({
    required this.title,
    required this.distanceKm,
    required this.pace,
    required this.duration,
    required this.elevationGain,
    required this.calories,
    required this.heartRate,
    required this.date,
    this.coordinates = const [],
    this.routeTexture,
  });

  Map<String, dynamic> toStatsMap() {
    return {
      'title': title,
      'distance': distanceKm * 1000,
      'pace': pace,
      'duration': duration,
      'elevationGain': elevationGain,
      'calories': calories,
      'heartRate': heartRate,
      'startDate': date.toIso8601String(),
    };
  }
}

/// Widget Builder (Switch de plantillas).
class AuraCardBuilder extends StatelessWidget {
  final TemplateType templateType;
  final AuraData data;
  final AuraMetricsConfig metricsConfig;
  final ui.Image? mapImage;

  const AuraCardBuilder({
    super.key,
    required this.templateType,
    required this.data,
    required this.metricsConfig,
    this.mapImage,
  });

  @override
  Widget build(BuildContext context) {
    // Relación de aspecto 9:16 fija (Historias de Instagram/TikTok)
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: _buildTemplate(),
      ),
    );
  }

  Widget _buildTemplate() {
    switch (templateType) {
      case TemplateType.cartografo:
        return CartografoTemplateWidget(data: data, config: metricsConfig, mapImage: mapImage);
      case TemplateType.diario:
        return DiarioTemplateWidget(data: data, config: metricsConfig, mapImage: mapImage);
      case TemplateType.distanciaRey:
        return DistanciaReyTemplateWidget(data: data, config: metricsConfig, mapImage: mapImage);
      case TemplateType.cyberHud:
        return CyberHudTemplateWidget(data: data, config: metricsConfig, mapImage: mapImage);
      case TemplateType.timeline:
        return TimelineTemplateWidget(data: data, config: metricsConfig, mapImage: mapImage);
    }
  }
}
