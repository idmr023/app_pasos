import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/theme.dart';
import '../../models/cover_style.dart';
import '../../models/route_card_template.dart';
import '../../models/wallet.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/aura_card_builder.dart';
import '../../widgets/route_texture_renderer.dart';
import '../../widgets/template_selector.dart';
import '../../widgets/wallet_widgets.dart';

/// Editor de portadas (Share Aura v4).
///
/// - Carrusel animado (PageView) con TODAS las plantillas.
/// - Foto de fondo / foto pequeña desde galería o cámara (solo en el
///   dispositivo, en memoria como bytes: funciona también en web).
/// - Acento, fuente, título, métricas visibles y stickers arrastrables.
/// - Exporta la plantilla visible a PNG de 1080 px de ancho (9:16) y la
///   comparte (share_plus) o la guarda en la galería (gal).
class CoverEditorScreen extends StatefulWidget {
  final AuraData data;
  final ui.Image? mapImage;
  final TemplateType initialTemplate;

  const CoverEditorScreen({
    super.key,
    required this.data,
    this.mapImage,
    this.initialTemplate = TemplateType.revista,
  });

  /// Atajo para abrir el editor al terminar una carrera en vivo.
  /// [pace] en formato `m:ss` (opcional: se calcula si es null).
  CoverEditorScreen.forRun({
    super.key,
    required double distanceKm,
    required Duration duration,
    String? pace,
    List<LatLng> routePoints = const [],
    String title = 'Mi carrera',
    DateTime? date,
    this.initialTemplate = TemplateType.neonNocturno,
  })  : data = AuraData.fromRun(
          distanceKm: distanceKm,
          duration: duration,
          pace: pace,
          routePoints: routePoints,
          title: title,
          date: date,
        ),
        mapImage = null;

  @override
  State<CoverEditorScreen> createState() => _CoverEditorScreenState();
}

class _CoverEditorScreenState extends State<CoverEditorScreen> with TickerProviderStateMixin {
  static const _maxStickers = 8;
  static const _stickerSlots = [
    Alignment(-0.6, -0.5),
    Alignment(0.6, -0.25),
    Alignment(0, 0.15),
    Alignment(-0.55, 0.5),
    Alignment(0.55, 0.65),
    Alignment(0, -0.75),
    Alignment(-0.7, 0.85),
    Alignment(0.7, -0.8),
  ];

  final List<TemplateType> _templates = [
    ...TemplateType.values.where((t) => t.isCover),
    ...TemplateType.values.where((t) => !t.isCover),
  ];
  late final List<GlobalKey> _keys = List.generate(_templates.length, (_) => GlobalKey());
  late final PageController _pageController;
  late final TabController _tabController;
  late final TextEditingController _titleController;
  final ImagePicker _picker = ImagePicker();
  final math.Random _rnd = math.Random();

  late AuraData _data;
  late int _index;
  CoverStyle _style = const CoverStyle();
  AuraMetricsConfig _config = const AuraMetricsConfig();
  bool _isProcessing = false;

  TemplateType get _current => _templates[_index];

  @override
  void initState() {
    super.initState();
    _data = widget.data;
    _index = math.max(0, _templates.indexOf(widget.initialTemplate));
    _pageController = PageController(viewportFraction: 0.72, initialPage: _index);
    _tabController = TabController(length: 4, vsync: this)..addListener(() => setState(() {}));
    _titleController = TextEditingController(text: _data.title);
    // Portadas premium / stickers: estado del monedero de pasos.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ensureWalletLoaded(context);
    });

    // "Distancia Rey" necesita la textura neón de la ruta.
    if (_data.routeTexture == null && _data.coordinates.length >= 2) {
      RouteTextureRenderer.render(coordinates: _data.coordinates).then((tex) {
        if (!mounted || tex == null) return;
        setState(() => _data = _data.copyWith(routeTexture: tex));
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    _pageController.animateToPage(i, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
  }

  void _surprise() {
    final covers = [for (var i = 0; i < _templates.length; i++) if (_templates[i].isCover && i != _index) i];
    final next = covers[_rnd.nextInt(covers.length)];
    setState(() {
      _style = _style.copyWith(
        accent: coverAccentPresets[_rnd.nextInt(coverAccentPresets.length)],
        fontFamily: coverFonts[_rnd.nextInt(coverFonts.length)],
      );
    });
    _goTo(next);
  }

  // ───────────── Fotos ─────────────

  Future<Uint8List?> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, maxWidth: 2000, maxHeight: 2000, imageQuality: 90);
      if (file == null) return null;
      return await file.readAsBytes();
    } catch (_) {
      _snack(source == ImageSource.camera
          ? 'No se pudo abrir la cámara en este dispositivo'
          : 'No se pudo abrir la galería', error: true);
      return null;
    }
  }

  Future<void> _pickBackground(ImageSource source) async {
    final bytes = await _pick(source);
    if (bytes == null || !mounted) return;
    setState(() => _style = _style.copyWith(photoBytes: bytes));
    if (!_current.isCover) _snack('La foto de fondo se ve en las portadas nuevas (Revista, Polaroid...)');
  }

  Future<void> _pickInset() async {
    final bytes = await _pick(ImageSource.gallery);
    if (bytes == null || !mounted) return;
    setState(() => _style = _style.copyWith(insetBytes: bytes));
  }

  // ───────────── Stickers ─────────────

  void _addSticker(String text, {bool badge = false}) {
    if (_style.stickers.length >= _maxStickers) {
      _snack('Máximo $_maxStickers stickers');
      return;
    }
    final slot = _stickerSlots[_style.stickers.length % _stickerSlots.length];
    setState(() => _style = _style.copyWith(
          stickers: [..._style.stickers, CoverSticker(text: text, isBadge: badge, alignment: slot)],
        ));
  }

  void _moveSticker(int i, Alignment a) {
    final list = [..._style.stickers];
    if (i >= list.length) return;
    list[i] = list[i].copyWith(alignment: a);
    setState(() => _style = _style.copyWith(stickers: list));
  }

  void _removeSticker(int i) {
    final list = [..._style.stickers]..removeAt(i);
    setState(() => _style = _style.copyWith(stickers: list));
  }

  // ───────────── Portadas premium (tienda de pasos) ─────────────

  bool get _currentLocked => !context.read<WalletProvider>().isTemplateUnlocked(_current);

  Future<void> _unlockCurrent() async {
    final itemId = premiumCoverItems[_current];
    if (itemId == null) return;
    final ok = await showWalletPurchaseSheet(
      context,
      itemId: itemId,
      title: 'Portada ${_current.displayName}',
      subtitle: 'Desbloquéala para exportarla y compartirla cuando quieras',
      icon: _current.icon,
    );
    if (ok) _snack('¡Portada ${_current.displayName} desbloqueada!');
  }

  Future<void> _unlockStickers(StickerPack pack) async {
    final ok = await showWalletPurchaseSheet(
      context,
      itemId: pack.itemId,
      title: pack.name,
      subtitle: 'Stickers extra para tus portadas',
      icon: Icons.emoji_emotions_rounded,
    );
    if (ok) _snack('¡${pack.name} desbloqueado!');
  }

  // ───────────── Exportación ─────────────

  Future<Uint8List?> _capture() async {
    final boundary = _keys[_index].currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || boundary.size.width == 0) return null;
    // PNG de 1080 px de ancho sin importar el tamaño de pantalla.
    final ratio = (1080 / boundary.size.width).clamp(1.0, 8.0);
    final image = await boundary.toImage(pixelRatio: ratio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData?.buffer.asUint8List();
  }

  Future<void> _share() async {
    if (_isProcessing) return;
    if (_currentLocked) return _unlockCurrent();
    setState(() => _isProcessing = true);
    try {
      final bytes = await _capture();
      if (bytes == null) return;
      final xfile = XFile.fromData(
        bytes,
        mimeType: 'image/png',
        name: 'portada_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await Share.shareXFiles([xfile], text: 'Mi entrenamiento en App Pasos!');
    } catch (e) {
      _snack('Error al compartir: $e', error: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _save() async {
    if (kIsWeb) {
      // En web no hay galería: share_plus descarga el archivo.
      return _share();
    }
    if (_isProcessing) return;
    if (_currentLocked) return _unlockCurrent();
    setState(() => _isProcessing = true);
    try {
      final bytes = await _capture();
      if (bytes == null) return;
      if (!await Gal.hasAccess(toAlbum: true)) {
        await Gal.requestAccess(toAlbum: true);
      }
      await Gal.putImageBytes(bytes, album: 'App Pasos');
      _snack('Portada guardada en la galería');
    } catch (_) {
      _snack('No se pudo guardar (disponible en Android/iOS)', error: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? AppTheme.error : AppTheme.secondary),
    );
  }

  // ───────────── UI ─────────────

  @override
  Widget build(BuildContext context) {
    final accent = _style.accent ?? _current.accent;
    final uiAccent = accent.computeLuminance() < 0.05 ? Colors.white : accent;
    final locked = context.watch<WalletProvider>().lockedTemplates;
    return Scaffold(
      backgroundColor: const Color(0xFF05050F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Crear portada', style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 1)),
        actions: [
          const Center(child: WalletBalanceChip()),
          IconButton(
            tooltip: 'Sorpréndeme',
            icon: const Icon(Icons.casino_outlined),
            onPressed: _surprise,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildCarousel(locked)),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(anim),
                  child: child,
                ),
              ),
              child: Padding(
                key: ValueKey(_current),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: Column(children: [
                  Text(_current.displayName,
                      style: TextStyle(color: uiAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(_current.subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ]),
              ),
            ),
            TemplateSelector(
              templates: _templates,
              selected: _current,
              locked: locked,
              onChanged: (t) => _goTo(_templates.indexOf(t)),
            ),
            TabBar(
              controller: _tabController,
              indicatorColor: uiAccent,
              labelColor: uiAccent,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(height: 44, icon: Icon(Icons.photo_outlined, size: 18), text: 'Foto'),
                Tab(height: 44, icon: Icon(Icons.palette_outlined, size: 18), text: 'Estilo'),
                Tab(height: 44, icon: Icon(Icons.bar_chart, size: 18), text: 'Datos'),
                Tab(height: 44, icon: Icon(Icons.emoji_emotions_outlined, size: 18), text: 'Stickers'),
              ],
            ),
            SizedBox(
              height: 170,
              child: TabBarView(
                controller: _tabController,
                children: [_photoTab(), _styleTab(), _dataTab(), _stickerTab()],
              ),
            ),
            locked.contains(_current) ? _buildUnlockAction() : _buildActions(uiAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildUnlockAction() {
    final price = context.read<WalletProvider>().priceOf(premiumCoverItems[_current] ?? '');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _unlockCurrent,
          icon: const Icon(Icons.lock_open_rounded, size: 18),
          label: Text('Desbloquear por ${formatPasos(price)} pasos'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.gold,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  Widget _buildCarousel(Set<TemplateType> locked) {
    // En la pestaña Stickers se bloquea el swipe para poder arrastrarlos.
    final dragStickers = _tabController.index == 3;
    return PageView.builder(
      controller: _pageController,
      itemCount: _templates.length,
      physics: dragStickers ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
      onPageChanged: (i) => setState(() => _index = i),
      itemBuilder: (context, i) {
        return AnimatedBuilder(
          animation: _pageController,
          builder: (context, child) {
            var page = _index.toDouble();
            if (_pageController.hasClients && _pageController.position.haveDimensions) {
              page = _pageController.page ?? page;
            }
            final diff = (page - i).abs().clamp(0.0, 1.0);
            return Opacity(
              opacity: 1 - diff * 0.45,
              child: Transform.scale(scale: 1 - diff * 0.12, child: child),
            );
          },
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: GestureDetector(
                onTap: i == _index ? null : () => _goTo(i),
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    RepaintBoundary(
                      key: _keys[i],
                      child: AuraCardBuilder(
                        templateType: _templates[i],
                        data: _data,
                        metricsConfig: _config,
                        mapImage: widget.mapImage,
                        style: _style,
                        onStickerMoved: (i == _index && dragStickers) ? _moveSticker : null,
                      ),
                    ),
                    // Fuera del RepaintBoundary: no sale en la imagen exportada.
                    if (locked.contains(_templates[i]))
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: GestureDetector(
                          onTap: i == _index ? _unlockCurrent : null,
                          child: LockedPriceBadge(
                            price: context.read<WalletProvider>().priceOf(premiumCoverItems[_templates[i]]!),
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActions(Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isProcessing ? null : _save,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Guardar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 13),
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
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.share, size: 18),
              label: Text(_isProcessing ? 'Generando...' : 'Compartir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: accent.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────── Pestañas ─────────────

  Widget _panel(List<Widget> children) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      );

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 6),
        child: Text(text.toUpperCase(),
            style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
      );

  Widget _smallButton(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          side: const BorderSide(color: Colors.white24),
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 92, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 2, overlayShape: SliderComponentShape.noOverlay),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              activeColor: AppTheme.primary,
              inactiveColor: Colors.white24,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _photoTab() {
    final s = _style;
    return _panel([
      if (!_current.isCover) _hint('Las plantillas clásicas no usan foto de fondo: prueba Revista, Polaroid, Dorsal...'),
      Wrap(children: [
        _smallButton(Icons.photo_library_outlined, 'Galería', () => _pickBackground(ImageSource.gallery)),
        _smallButton(Icons.photo_camera_outlined, 'Cámara', () => _pickBackground(ImageSource.camera)),
        if (s.hasPhoto)
          _smallButton(Icons.delete_outline, 'Quitar', () => setState(() => _style = s.copyWith(clearPhoto: true))),
      ]),
      if (s.hasPhoto) ...[
        _slider('Oscurecer', s.photoDarken, 0, 0.85, (v) => setState(() => _style = _style.copyWith(photoDarken: v))),
        _slider('Desenfoque', s.photoBlur, 0, 15, (v) => setState(() => _style = _style.copyWith(photoBlur: v))),
        _slider('Zoom', s.photoZoom, 1, 2.5, (v) => setState(() => _style = _style.copyWith(photoZoom: v))),
        _slider('Encuadre ↔', s.photoAlignment.x, -1, 1,
            (v) => setState(() => _style = _style.copyWith(photoAlignment: Alignment(v, _style.photoAlignment.y)))),
        _slider('Encuadre ↕', s.photoAlignment.y, -1, 1,
            (v) => setState(() => _style = _style.copyWith(photoAlignment: Alignment(_style.photoAlignment.x, v)))),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          _choice('Rellenar', s.photoFit == BoxFit.cover, () => setState(() => _style = _style.copyWith(photoFit: BoxFit.cover))),
          _choice('Completa', s.photoFit == BoxFit.contain, () => setState(() => _style = _style.copyWith(photoFit: BoxFit.contain))),
        ]),
      ],
      _section('Foto pequeña'),
      Wrap(children: [
        _smallButton(Icons.add_photo_alternate_outlined, s.insetBytes == null ? 'Añadir' : 'Cambiar', _pickInset),
        if (s.insetBytes != null)
          _smallButton(Icons.delete_outline, 'Quitar', () => setState(() => _style = s.copyWith(clearInset: true))),
      ]),
      if (s.insetBytes != null)
        Wrap(spacing: 8, runSpacing: 6, children: [
          for (final (label, a) in const [
            ('Arriba izq.', Alignment.topLeft),
            ('Arriba der.', Alignment.topRight),
            ('Abajo izq.', Alignment.bottomLeft),
            ('Abajo der.', Alignment.bottomRight),
          ])
            _choice(label, s.insetAlignment == a, () => setState(() => _style = _style.copyWith(insetAlignment: a))),
        ]),
    ]);
  }

  Widget _choice(String label, bool selected, VoidCallback onTap, {TextStyle? style}) {
    return ChoiceChip(
      label: Text(label, style: (style ?? const TextStyle()).copyWith(fontSize: 12, color: selected ? Colors.black : Colors.white70)),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppTheme.primary,
      backgroundColor: const Color(0xFF1E2235),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _styleTab() {
    final s = _style;
    return _panel([
      if (!_current.isCover) _hint('Título, color y fuente se aplican a las portadas nuevas.'),
      TextField(
        controller: _titleController,
        maxLength: 40,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          counterText: '',
          labelText: 'Título de la portada',
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
        onChanged: (v) => setState(() => _style = _style.copyWith(customTitle: v)),
      ),
      _section('Color de acento'),
      Wrap(spacing: 10, runSpacing: 10, children: [
        _colorDot(null, s.accent == null),
        for (final c in coverAccentPresets) _colorDot(c, s.accent == c),
      ]),
      _section('Tipografía'),
      Wrap(spacing: 8, runSpacing: 6, children: [
        _choice('Auto', s.fontFamily == null, () => setState(() => _style = _style.copyWith(clearFont: true))),
        for (final f in coverFonts)
          _choice(f, s.fontFamily == f, () => setState(() => _style = _style.copyWith(fontFamily: f)),
              style: GoogleFonts.getFont(f)),
      ]),
    ]);
  }

  Widget _colorDot(Color? color, bool selected) {
    return GestureDetector(
      onTap: () => setState(() => _style = color == null ? _style.copyWith(clearAccent: true) : _style.copyWith(accent: color)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          gradient: color == null
              ? const SweepGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.cyan, Colors.blue, Colors.purple, Colors.red])
              : null,
          border: Border.all(color: selected ? Colors.white : Colors.white24, width: selected ? 3 : 1),
        ),
        child: color == null ? const Center(child: Text('A', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))) : null,
      ),
    );
  }

  Widget _dataTab() {
    Widget toggle(String label, bool value, AuraMetricsConfig Function(bool) update) {
      return FilterChip(
        label: Text(label),
        selected: value,
        onSelected: (v) => setState(() => _config = update(v)),
        selectedColor: AppTheme.primary.withValues(alpha: 0.2),
        checkmarkColor: AppTheme.primary,
        backgroundColor: const Color(0xFF1E2235),
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: value ? AppTheme.primary : Colors.transparent),
        ),
        labelStyle: TextStyle(color: value ? AppTheme.primary : Colors.white60, fontSize: 11),
      );
    }

    final c = _config;
    return _panel([
      _hint('Elige qué datos aparecen en la portada. Los valores en 0 se ocultan solos.'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        toggle('Mapa', c.showMap, (v) => c.copyWith(showMap: v)),
        toggle('Kilómetros', c.showDistance, (v) => c.copyWith(showDistance: v)),
        toggle('Ritmo', c.showPace, (v) => c.copyWith(showPace: v)),
        toggle('Tiempo', c.showTime, (v) => c.copyWith(showTime: v)),
        toggle('Calorías', c.showCalories, (v) => c.copyWith(showCalories: v)),
        toggle('Elevación', c.showElevation, (v) => c.copyWith(showElevation: v)),
        toggle('FC', c.showHeartRate, (v) => c.copyWith(showHeartRate: v)),
      ]),
    ]);
  }

  Widget _stickerTab() {
    final stickers = _style.stickers;
    final wallet = context.watch<WalletProvider>();
    return _panel([
      _hint('Toca para añadir y arrastra los stickers sobre la portada.'),
      Wrap(spacing: 4, runSpacing: 4, children: [
        for (final e in coverEmojiStickers)
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _addSticker(e),
            child: Padding(padding: const EdgeInsets.all(6), child: Text(e, style: const TextStyle(fontSize: 22))),
          ),
      ]),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 6, children: [
        for (final b in coverBadgeStickers)
          ActionChip(
            label: Text(b, style: const TextStyle(fontSize: 11, color: Colors.white)),
            backgroundColor: const Color(0xFF1E2235),
            visualDensity: VisualDensity.compact,
            onPressed: () => _addSticker(b, badge: true),
          ),
      ]),
      // Packs premium de la tienda de pasos
      for (final pack in premiumStickerPacks)
        if (wallet.owns(pack.itemId)) ...[
          _section(pack.name),
          Wrap(spacing: 4, runSpacing: 4, children: [
            for (final e in pack.emojis)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _addSticker(e),
                child: Padding(padding: const EdgeInsets.all(6), child: Text(e, style: const TextStyle(fontSize: 22))),
              ),
            for (final b in pack.badges)
              ActionChip(
                label: Text(b, style: const TextStyle(fontSize: 11, color: Colors.white)),
                backgroundColor: const Color(0xFF1E2235),
                visualDensity: VisualDensity.compact,
                onPressed: () => _addSticker(b, badge: true),
              ),
          ]),
        ],
      if (premiumStickerPacks.any((p) => !wallet.owns(p.itemId))) ...[
        _section('Más stickers'),
        Wrap(spacing: 8, runSpacing: 6, children: [
          for (final pack in premiumStickerPacks)
            if (!wallet.owns(pack.itemId))
              ActionChip(
                avatar: const Icon(Icons.lock_rounded, size: 14, color: AppTheme.gold),
                label: Text(
                  '${pack.name} · ${pack.emojis.isNotEmpty ? pack.emojis.take(3).join() : pack.badges.first} · ${formatPasos(wallet.priceOf(pack.itemId))}',
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
                backgroundColor: const Color(0xFF1E2235),
                visualDensity: VisualDensity.compact,
                onPressed: () => _unlockStickers(pack),
              ),
        ]),
      ],
      if (stickers.isNotEmpty) ...[
        _section('En la portada'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (var i = 0; i < stickers.length; i++)
            InputChip(
              label: Text(stickers[i].text, style: const TextStyle(fontSize: 11, color: Colors.white)),
              backgroundColor: const Color(0xFF1E2235),
              visualDensity: VisualDensity.compact,
              onDeleted: () => _removeSticker(i),
              deleteIconColor: Colors.white54,
            ),
          ActionChip(
            label: const Text('Quitar todos', style: TextStyle(fontSize: 11, color: AppTheme.error)),
            backgroundColor: const Color(0xFF1E2235),
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _style = _style.copyWith(stickers: const [])),
          ),
        ]),
      ],
    ]);
  }
}
