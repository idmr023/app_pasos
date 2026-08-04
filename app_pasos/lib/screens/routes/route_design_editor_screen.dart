import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/route.dart';
import '../../providers/route_provider.dart';
import '../../widgets/glass_card.dart';

class RouteDesignEditorScreen extends StatefulWidget {
  final UserRoute route;

  const RouteDesignEditorScreen({super.key, required this.route});

  @override
  State<RouteDesignEditorScreen> createState() => _RouteDesignEditorScreenState();
}

class _RouteDesignEditorScreenState extends State<RouteDesignEditorScreen> {
  late String _routeColor;
  late String _backgroundColor;
  late String _fontFamily;
  late int _lineWidth;
  late String _lineStyle;
  late bool _showElevation;
  bool _isSaving = false;

  final List<String> _colorPresets = [
    '#3B82F6', // Blue
    '#00D4FF', // Cyan Neon
    '#EF4444', // Red
    '#10B981', // Emerald
    '#F59E0B', // Amber
    '#8B5CF6', // Purple
    '#EC4899', // Pink
    '#FFFFFF', // White
  ];

  final List<String> _bgPresets = [
    '#0F172A', // Dark Slate
    '#0A0A1A', // Midnight
    '#18181B', // Zinc Dark
    '#111827', // Gray Dark
    '#F8FAFC', // Light Clean
    '#F3F0FF', // Light Purple
  ];

  final List<String> _fonts = ['Montserrat', 'Inter', 'Roboto', 'Oswald', 'Lato'];
  final List<String> _lineStyles = ['solid', 'dashed', 'dotted'];

  @override
  void initState() {
    super.initState();
    final d = widget.route.design;
    _routeColor = d?.routeColor ?? '#3B82F6';
    _backgroundColor = d?.backgroundColor ?? '#0F172A';
    _fontFamily = d?.fontFamily ?? 'Montserrat';
    _lineWidth = d?.lineWidth ?? 4;
    _lineStyle = d?.lineStyle ?? 'solid';
    _showElevation = d?.showElevation ?? false;
  }

  Color _parseHex(String hex, {Color fallback = Colors.blue}) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final design = RouteDesign(
        routeColor: _routeColor,
        backgroundColor: _backgroundColor,
        fontFamily: _fontFamily,
        lineWidth: _lineWidth,
        lineStyle: _lineStyle,
        showElevation: _showElevation,
        showStats: widget.route.design?.showStats ?? ['distance', 'pace', 'duration'],
        statsLayout: widget.route.design?.statsLayout ?? 'bottom-bar',
      );

      final success = await context.read<RouteProvider>().updateRouteDesign(widget.route.id, design);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Diseño guardado exitosamente!'), backgroundColor: AppTheme.secondary),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar diseño'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Text('Decorar Ruta y Estilo', style: AppTheme.titleMedium),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Guardar', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.background, Color(0xFF0A0A1A), AppTheme.background],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vista previa simulada
                Center(
                  child: Container(
                    width: double.infinity,
                    height: 220,
                    decoration: BoxDecoration(
                      color: _parseHex(_backgroundColor, fallback: const Color(0xFF0F172A)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _parseHex(_routeColor), width: 2),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.map, size: 48, color: _parseHex(_routeColor).withValues(alpha: 0.8)),
                              const SizedBox(height: 8),
                              Text(
                                widget.route.title,
                                style: TextStyle(
                                  color: _parseHex(_backgroundColor).computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: _fontFamily,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(widget.route.distance / 1000).toStringAsFixed(2)} km • LineWidth: ${_lineWidth}px (${_lineStyle.toUpperCase()})',
                                style: TextStyle(
                                  color: _parseHex(_backgroundColor).computeLuminance() > 0.5 ? Colors.black54 : Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              if (_showElevation) ...[
                                const SizedBox(height: 4),
                                const Text('Desnivel activo', style: TextStyle(color: AppTheme.secondary, fontSize: 11)),
                              ],
                            ],
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _parseHex(_routeColor),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.route.activityType.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Color de Ruta
                Text('Color de Línea de Ruta', style: AppTheme.titleMedium),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _colorPresets.map((hex) {
                    final color = _parseHex(hex);
                    final isSelected = _routeColor.toLowerCase() == hex.toLowerCase();
                    return GestureDetector(
                      onTap: () => setState(() => _routeColor = hex),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 2)] : [],
                        ),
                        child: isSelected ? const Icon(Icons.check, color: Colors.black54, size: 20) : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Color de Fondo
                Text('Color de Fondo', style: AppTheme.titleMedium),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _bgPresets.map((hex) {
                    final color = _parseHex(hex);
                    final isSelected = _backgroundColor.toLowerCase() == hex.toLowerCase();
                    return GestureDetector(
                      onTap: () => setState(() => _backgroundColor = hex),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppTheme.primary : Colors.white24,
                            width: 3,
                          ),
                        ),
                        child: isSelected ? const Icon(Icons.check, color: AppTheme.primary, size: 20) : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Grosor de línea
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Grosor de Línea', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                    Text('${_lineWidth}px', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Slider(
                  value: _lineWidth.toDouble(),
                  min: 2,
                  max: 12,
                  divisions: 5,
                  activeColor: AppTheme.primary,
                  inactiveColor: Colors.white24,
                  onChanged: (val) => setState(() => _lineWidth = val.round()),
                ),
                const SizedBox(height: 16),

                // Estilo de línea y fuente
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Estilo de Trazo', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _lineStyles.contains(_lineStyle) ? _lineStyle : 'solid',
                            dropdownColor: AppTheme.surface,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: _lineStyles.map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _lineStyle = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tipografía', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _fonts.contains(_fontFamily) ? _fontFamily : 'Montserrat',
                            dropdownColor: AppTheme.surface,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: _fonts.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _fontFamily = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Mostrar Desnivel / Perfil de elevación
                GlassCard(
                  child: SwitchListTile(
                    title: const Text('Mostrar Desnivel en Tarjeta', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Incluir datos y perfil altimétrico en la exportación', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    value: _showElevation,
                    activeThumbColor: AppTheme.primary,
                    onChanged: (val) => setState(() => _showElevation = val),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
