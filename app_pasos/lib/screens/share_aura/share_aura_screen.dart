import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/route.dart';
import '../../models/route_card_template.dart';
import '../../models/wallet.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/wallet_widgets.dart';
import '../../services/aura_card_service.dart';
import '../../services/route_service.dart';
import '../../widgets/aura_card_composer.dart';
import '../../widgets/aura_card_builder.dart';
import '../../widgets/route_texture_renderer.dart';
import '../routes/route_image_card_screen.dart';
import 'cover_editor_screen.dart';

/// Pantalla principal del módulo Share Aura V3.
///
/// Arquitectura:
/// 1. Carga la ruta, el mapa 3D y la textura GPS UNA sola vez.
/// 2. Muestra los moldes (8 portadas v4 + 5 clásicos) en una grilla de 2 columnas.
/// 3. Al tocar un molde se abre [CoverEditorScreen]: carrusel animado con
///    todas las plantillas, foto de fondo/inset, estilo, métricas, stickers
///    y exportación a PNG (compartir / guardar en galería).
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
  UserRoute? _loadedRoute;

  @override
  void initState() {
    super.initState();
    _loadAssets();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ensureWalletLoaded(context);
    });
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
        _loadedRoute = route;
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
    final data = _auraData;
    if (data == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CoverEditorScreen(
          data: data,
          mapImage: _mapImage,
          initialTemplate: template,
        ),
      ),
    );
  }

  void _openImageCard() {
    final route = _loadedRoute;
    if (route == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RouteImageCardScreen(route: route)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05050F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Share Aura', style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 1)),
        actions: const [Center(child: WalletBalanceChip()), SizedBox(width: 12)],
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
              for (final template in [
                ...TemplateType.values.where((t) => t.isCover),
                ...TemplateType.values.where((t) => !t.isCover),
              ])
                _TemplateGridCard(
                  template: template,
                  // Las premium bloqueadas también se abren: se pueden previsualizar
                  // y desbloquear desde el editor.
                  lockedPrice: context.watch<WalletProvider>().isTemplateUnlocked(template)
                      ? null
                      : context.watch<WalletProvider>().priceOf(premiumCoverItems[template]!),
                  onTap: () => _openConfigurator(template),
                ),
              _ImageBackgroundCard(onTap: _openImageCard),
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

  /// Precio en pasos si es una portada premium no comprada.
  final int? lockedPrice;

  const _TemplateGridCard({required this.template, required this.onTap, this.lockedPrice});

  @override
  Widget build(BuildContext context) {
    final accent = template.accent.computeLuminance() < 0.05 ? Colors.white : template.accent;

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
              if (lockedPrice != null) ...[
                const SizedBox(height: 8),
                LockedPriceBadge(price: lockedPrice!),
              ],
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

/// Tarjeta extra que abre la pantalla "Card con Imagen" (fondo personalizado).
class _ImageBackgroundCard extends StatelessWidget {
  final VoidCallback onTap;

  const _ImageBackgroundCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF00D4FF);

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
                child: const Icon(Icons.image_outlined, color: accent, size: 26),
              ),
              const Spacer(),
              const Text(
                'Card con Imagen',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sube una foto de fondo y tus datos en panel transparente',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white38, fontSize: 10, height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
