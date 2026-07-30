import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/theme.dart';
import '../../models/route_card_template.dart';
import '../../providers/auth_provider.dart';
import '../../services/aura_card_service.dart';
import '../../widgets/aura_card_composer.dart';
import '../../widgets/template_selector.dart';

class ShareAuraScreen extends StatefulWidget {
  final String routeId;

  const ShareAuraScreen({super.key, required this.routeId});

  @override
  State<ShareAuraScreen> createState() => _ShareAuraScreenState();
}

class _ShareAuraScreenState extends State<ShareAuraScreen> {
  String _selectedTemplate = 'cyberpunk';
  AuraCardData? _cardData;
  ui.Image? _mapImage;
  bool _isLoading = false;
  String? _error;
  final GlobalKey _repaintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _generateCard();
  }

  Future<void> _generateCard() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _mapImage = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      if (auth.token == null) throw Exception('No autenticado');

      final service = AuraCardService(auth.token!);
      final data = await service.getMapCardData(
        widget.routeId,
        template: _selectedTemplate,
      );

      final mapFile = await service.downloadMapImage(
        data.imageUrl,
        widget.routeId,
      );

      final image = await AuraCardComposer.loadImageFromFile(mapFile);

      if (!mounted) return;
      setState(() {
        _cardData = data;
        _mapImage = image;
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

  Future<void> _shareCard() async {
    if (_cardData == null) return;

    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final dir = Directory.systemTemp;
      final file = File('${dir.path}/aura_card_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Mi entrenamiento en App Pasos!',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al compartir: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05050F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Share Aura', style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 1)),
        actions: [
          if (_cardData != null)
            IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: _shareCard,
              tooltip: 'Compartir',
            ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          TemplateSelector(
            templates: auraTemplates,
            selectedId: _selectedTemplate,
            onChanged: (id) {
              setState(() => _selectedTemplate = id);
              _generateCard();
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildPreview(),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF00D4FF)),
            SizedBox(height: 16),
            Text('Generando tu tarjeta...', style: TextStyle(color: Colors.white54, fontSize: 14)),
            SizedBox(height: 8),
            Text('Descargando mapa 3D de Mapbox', style: TextStyle(color: Colors.white24, fontSize: 12)),
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
              Text('Error: $_error', style: const TextStyle(color: Colors.white54, fontSize: 14), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _generateCard,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D4FF)),
              ),
            ],
          ),
        ),
      );
    }

    if (_cardData == null) return const SizedBox();

    final cardWidth = _cardData!.width.toDouble();
    final cardHeight = _cardData!.height.toDouble();
    final screenWidth = MediaQuery.of(context).size.width - 32;
    final scale = screenWidth / cardWidth;
    final displayWidth = screenWidth;
    final displayHeight = cardHeight * scale;

    return Center(
      child: GestureDetector(
        onTap: _shareCard,
        child: RepaintBoundary(
          key: _repaintKey,
          child: Container(
            width: displayWidth,
            height: displayHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _getTemplateColor().withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(
                size: Size(displayWidth, displayHeight),
                painter: AuraCardPainter(
                  mapImage: _mapImage,
                  stats: _cardData!.stats,
                  template: _cardData!.templateConfig,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getTemplateColor() {
    return auraTemplates
        .firstWhere((t) => t.id == _selectedTemplate, orElse: () => auraTemplates[0])
        .routeColor;
  }
}
