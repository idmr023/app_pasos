import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/theme.dart';
import '../../models/route.dart';

/// Pantalla "Card con Imagen": permite subir una imagen de fondo y
/// superpone los datos de la ruta en un panel translúcido abajo-centro.
class RouteImageCardScreen extends StatefulWidget {
  final UserRoute route;

  const RouteImageCardScreen({super.key, required this.route});

  @override
  State<RouteImageCardScreen> createState() => _RouteImageCardScreenState();
}

class _RouteImageCardScreenState extends State<RouteImageCardScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _backgroundBytes;
  bool _isProcessing = false;

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 92,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _backgroundBytes = bytes);
  }

  int _elapsedSeconds() {
    final coords = widget.route.coordinates;
    if (coords.length >= 2 &&
        coords.first.timestamp.isNotEmpty &&
        coords.last.timestamp.isNotEmpty) {
      final start = DateTime.tryParse(coords.first.timestamp);
      final end = DateTime.tryParse(coords.last.timestamp);
      if (start != null && end != null && end.isAfter(start)) {
        return end.difference(start).inSeconds;
      }
    }
    return widget.route.duration;
  }

  String _formatClock(int seconds) {
    if (seconds <= 0) return '--';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  Future<Uint8List?> _captureBytes() async {
    final boundary =
        _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _saveToGallery() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final bytes = await _captureBytes();
      if (bytes == null) return;
      if (!await Gal.hasAccess(toAlbum: true)) {
        await Gal.requestAccess(toAlbum: true);
      }
      await Gal.putImageBytes(bytes, album: 'App Pasos');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Imagen guardada en la galería'),
          backgroundColor: AppTheme.secondary,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar (disponible en Android/iOS)'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _share() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final bytes = await _captureBytes();
      if (bytes == null) return;
      final xfile = XFile.fromData(
        bytes,
        mimeType: 'image/png',
        name: 'ruta_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await Share.shareXFiles([xfile], text: widget.route.title);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al compartir: $e'), backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05050F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Card con Imagen',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 1),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: RepaintBoundary(
                      key: _repaintKey,
                      child: _buildCardPreview(),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                      label: const Text('Elegir imagen'),
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
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.share, size: 18),
                      label: Text(_isProcessing ? 'Generando...' : 'Compartir'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
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
      ),
    );
  }

  Widget _buildCardPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black54,
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
          _buildDataPanel(),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    final bytes = _backgroundBytes;
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.cover);
    }
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF12172B), Color(0xFF1E2235)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_photo_alternate_outlined, size: 48, color: Colors.white24),
            SizedBox(height: 12),
            Text(
              'Selecciona una imagen de fondo',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataPanel() {
    final route = widget.route;
    final distanceKm = (route.distance / 1000).toStringAsFixed(2);
    final durationStr = _formatClock(route.duration);
    final elapsedStr = _formatClock(_elapsedSeconds());
    final kcalStr = route.calories > 0 ? '${route.calories}' : '--';

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    route.title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStat('Distancia', '$distanceKm km'),
                      _buildStat('Duración', durationStr),
                      _buildStat('Tiempo', elapsedStr),
                      _buildStat('Calorías', '$kcalStr kcal'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}