import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import '../../config/theme.dart';
import '../../models/route_card_template.dart';
import '../../providers/auth_provider.dart';
import '../../services/aura_card_service.dart';
import '../../services/route_service.dart';
import '../../widgets/aura_card_composer.dart';
import '../../widgets/aura_card_builder.dart';
import '../../widgets/route_texture_renderer.dart';

/// Pantalla principal del módulo Share Aura V3.
///
/// Arquitectura:
/// 1. Carga la ruta, el mapa 3D y la textura GPS UNA sola vez.
/// 2. Muestra los 5 moldes en una grilla de 2 columnas.
/// 3. Al tocar un molde se abre [AuraConfiguratorSheet] (BottomSheet) con
///    previsualización en vivo, toggles de métricas y botón de compartir.
class ShareAuraScreen extends StatefulWidget {
  final String routeId;

  const ShareAuraScreen({super.key, required this.routeId});

  @override
  State<ShareAuraScreen> createState() => _ShareAuraScreenState();
}

class _ShareAuraScreenState extends State<ShareAuraScreen> {
  AuraData? _auraData;
  ui.Image? _mapImage;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      if (auth.token == null) throw Exception('No autenticado');

      final routeService = RouteService(auth.token!);
      final route = await routeService.getRoute(widget.routeId);

      // Mapa 3D (estilo oscuro, compartido por los moldes que usan mapa)
      ui.Image? mapImage;
      try {
        final mapBytes = await AuraCardService(auth.token!).downloadMapImageFromBackend(
          widget.routeId,
          template: TemplateType.cartografo.id,
          width: 1080,
          height: 1920,
        );
        mapImage = await AuraCardComposer.loadImageFromBytes(mapBytes);
      } catch (_) {
        mapImage = null; // Los moldes funcionan también sin mapa
      }

      // Textura "Río de Neón" para Distancia Rey
      final routeTexture = await RouteTextureRenderer.render(coordinates: route.coordinates);

      if (!mounted) return;
      setState(() {
        _auraData = AuraData(
          title: route.title,
          distanceKm: route.distance / 1000,
          pace: AuraCardComposer.formatPace(route.averagePace.toDouble()),
          duration: AuraCardComposer.formatDuration(route.duration),
          elevationGain: route.elevationGain,
          calories: route.calories,
          heartRate: route.averageHeartRate,
          date: route.startDate ?? DateTime.now(),
          coordinates: route.coordinates,
          routeTexture: routeTexture,
        );
        _mapImage = mapImage;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _openConfigurator(TemplateType template) {
    if (_auraData == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AuraConfiguratorSheet(
        templateType: template,
        data: _auraData!,
        mapImage: _mapImage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05050F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Share Aura', style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 1)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF00D4FF)),
            SizedBox(height: 16),
            Text('Preparando tu ruta...', style: TextStyle(color: Colors.white54, fontSize: 14)),
            SizedBox(height: 8),
            Text('Mapa 3D + textura GPS', style: TextStyle(color: Colors.white24, fontSize: 12)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 16),
              Text('Error: $_error',
                  style: const TextStyle(color: Colors.white54, fontSize: 14), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadAssets,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D4FF)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Text(
            'ELIGE TU MOLDE',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
        ),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
            children: [
              for (final template in TemplateType.values)
                _TemplateGridCard(
                  template: template,
                  onTap: () => _openConfigurator(template),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tarjeta de la grilla principal para elegir un molde.
class _TemplateGridCard extends StatelessWidget {
  final TemplateType template;
  final VoidCallback onTap;

  const _TemplateGridCard({required this.template, required this.onTap});

  static const Map<TemplateType, Color> _accents = {
    TemplateType.cartografo: Color(0xFF00D4FF),
    TemplateType.diario: Color(0xFFF3F4F6),
    TemplateType.distanciaRey: Color(0xFF00F5D4),
    TemplateType.cyberHud: Color(0xFF00FF66),
    TemplateType.timeline: Color(0xFF38BDF8),
  };

  @override
  Widget build(BuildContext context) {
    final accent = _accents[template] ?? Colors.white;

    return Material(
      color: const Color(0xFF10121D),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(template.icon, color: accent, size: 26),
              ),
              const Spacer(),
              Text(
                template.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                template.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white38, fontSize: 10, height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pop-up configurador: previsualización en vivo + toggles + compartir.
class AuraConfiguratorSheet extends StatefulWidget {
  final TemplateType templateType;
  final AuraData data;
  final ui.Image? mapImage;

  const AuraConfiguratorSheet({
    super.key,
    required this.templateType,
    required this.data,
    this.mapImage,
  });

  @override
  State<AuraConfiguratorSheet> createState() => _AuraConfiguratorSheetState();
}

class _AuraConfiguratorSheetState extends State<AuraConfiguratorSheet> {
  AuraMetricsConfig _config = const AuraMetricsConfig();
  final GlobalKey _repaintKey = GlobalKey();
  bool _isProcessing = false;

  Future<Uint8List?> _captureCardBytes() async {
    final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    return byteData.buffer.asUint8List();
  }

  Future<void> _share() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final bytes = await _captureCardBytes();
      if (bytes == null) return;
      final xfile = XFile.fromData(
        bytes,
        mimeType: 'image/png',
        name: 'aura_card_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await Share.shareXFiles([xfile], text: 'Mi entrenamiento en App Pasos!');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al compartir: $e'), backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveToGallery() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final bytes = await _captureCardBytes();
      if (bytes == null) return;
      if (!await Gal.hasAccess(toAlbum: true)) {
        await Gal.requestAccess(toAlbum: true);
      }
      await Gal.putImageBytes(bytes, album: 'App Pasos');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagen guardada en la galería'), backgroundColor: AppTheme.secondary),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la imagen'), backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFF0B0D17),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle de arrastre
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header del molde
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Icon(widget.templateType.icon, color: Colors.white70, size: 20),
                const SizedBox(width: 10),
                Text(
                  widget.templateType.displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Previsualización en tiempo real
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: AuraCardBuilder(
                    templateType: widget.templateType,
                    data: widget.data,
                    metricsConfig: _config,
                    mapImage: widget.mapImage,
                  ),
                ),
              ),
            ),
          ),

          // Panel de toggles
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildToggle('Mapa', _config.showMap, (v) => _config = _config.copyWith(showMap: v)),
                _buildToggle('Kilómetros', _config.showDistance, (v) => _config = _config.copyWith(showDistance: v)),
                _buildToggle('Ritmo', _config.showPace, (v) => _config = _config.copyWith(showPace: v)),
                _buildToggle('Tiempo', _config.showTime, (v) => _config = _config.copyWith(showTime: v)),
                _buildToggle('Calorías', _config.showCalories, (v) => _config = _config.copyWith(showCalories: v)),
                _buildToggle('Elevación', _config.showElevation, (v) => _config = _config.copyWith(showElevation: v)),
              ],
            ),
          ),

          // Botones de acción
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _saveToGallery,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Guardar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _share,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.share, size: 18),
                    label: Text(_isProcessing ? 'Generando...' : 'Compartir Aura'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D4FF),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: (v) => setState(() => onChanged(v)),
      selectedColor: const Color(0xFF00D4FF).withValues(alpha: 0.2),
      checkmarkColor: const Color(0xFF00D4FF),
      backgroundColor: const Color(0xFF1E2235),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: value ? const Color(0xFF00D4FF) : Colors.transparent),
      ),
      labelStyle: TextStyle(
        color: value ? const Color(0xFF00D4FF) : Colors.white60,
        fontSize: 11,
      ),
    );
  }
}
