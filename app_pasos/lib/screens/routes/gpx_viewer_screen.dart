import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/route_provider.dart';
import '../../utils/gpx.dart';
import '../../utils/gpx_picker.dart';

/// Abre un .gpx y muestra la ruta en el mapa con distancia, desnivel y perfil
/// de elevación. Se puede guardar en "Mis rutas" (portadas, Share Aura).
class GpxViewerScreen extends StatefulWidget {
  final GpxRoute? initialRoute;
  const GpxViewerScreen({super.key, this.initialRoute});

  @override
  State<GpxViewerScreen> createState() => _GpxViewerScreenState();
}

class _GpxViewerScreenState extends State<GpxViewerScreen> {
  GpxRoute? _route;
  bool _saving = false;
  bool _saved = false;
  int _mapKey = 0;

  @override
  void initState() {
    super.initState();
    _route = widget.initialRoute;
    if (_route == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
    }
  }

  Future<void> _pick() async {
    final r = await pickGpxRoute(context);
    if (r == null || !mounted) return;
    setState(() {
      _route = r;
      _saved = false;
      _mapKey++; // recrea el mapa para encuadrar la nueva ruta
    });
  }

  Future<void> _save() async {
    final r = _route;
    if (r == null) return;
    setState(() => _saving = true);
    final simplified = r.simplified(5000);
    final ok = await context.read<RouteProvider>().createRoute({
      'title': r.name,
      'source': 'gpx',
      'activityType': 'run',
      'coordinates': simplified.points
          .map((p) => {'lat': p.lat, 'lng': p.lng, 'elevation': p.ele ?? 0})
          .toList(),
    });
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = ok;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Ruta guardada en Mis rutas' : (context.read<RouteProvider>().error ?? 'No se pudo guardar')),
      backgroundColor: ok ? null : AppTheme.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final r = _route;
    return Scaffold(
      appBar: AppBar(
        title: Text(r?.name ?? 'Ruta GPX', overflow: TextOverflow.ellipsis),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.white,
        elevation: 0,
        actions: [
          IconButton(tooltip: 'Abrir otro GPX', icon: const Icon(Icons.folder_open), onPressed: _pick),
        ],
      ),
      body: r == null
          ? Center(
              child: ElevatedButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.route),
                label: const Text('Elegir archivo .gpx'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                SizedBox(height: 340, child: _map(r)),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _stat('Distancia', '${r.totalKm.toStringAsFixed(2)} km'),
                      _stat('Desnivel +', r.hasElevation ? '${r.elevationGain.round()} m' : '--'),
                      _stat('Desnivel −', r.hasElevation ? '${r.elevationLoss.round()} m' : '--'),
                    ],
                  ),
                ),
                if (r.hasElevation) _elevationChart(r),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: ElevatedButton.icon(
                    onPressed: _saving || _saved ? null : _save,
                    icon: Icon(_saved ? Icons.check : Icons.save_alt, color: Colors.white),
                    label: Text(
                      _saved ? 'Guardada en Mis rutas' : 'Guardar en Mis rutas',
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    'Para que tus espectadores la vean en vivo, cárgala al iniciar una carrera en Tracking.',
                    style: AppTheme.bodySmall,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _map(GpxRoute r) {
    final pts = r.points.map((p) => LatLng(p.lat, p.lng)).toList();
    return FlutterMap(
      key: ValueKey(_mapKey),
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(pts),
          padding: const EdgeInsets.all(32),
        ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag | InteractiveFlag.doubleTapZoom,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.apppasos.app_pasos',
          maxZoom: 19,
        ),
        PolylineLayer(polylines: [Polyline(points: pts, strokeWidth: 5, color: AppTheme.secondary)]),
        MarkerLayer(markers: [
          Marker(point: pts.first, width: 30, height: 30, child: const Icon(Icons.play_circle_fill, color: AppTheme.tertiary, size: 28)),
          Marker(point: pts.last, width: 32, height: 32, child: const Icon(Icons.sports_score, color: AppTheme.error, size: 30)),
        ]),
        const RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors © CARTO')]),
      ],
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTheme.bodySmall.copyWith(color: AppTheme.grey)),
            const SizedBox(height: 2),
            Text(value, style: AppTheme.titleLarge),
          ],
        ),
      );

  Widget _elevationChart(GpxRoute r) {
    // ≤ 300 puntos para el gráfico.
    final step = (r.points.length / 300).ceil().clamp(1, 1 << 30);
    final spots = <FlSpot>[];
    for (var i = 0; i < r.points.length; i += step) {
      final e = r.points[i].ele;
      if (e != null) spots.add(FlSpot(r.cumulative[i] / 1000, e));
    }
    if (spots.length < 2) return const SizedBox.shrink();
    final minE = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxE = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final pad = ((maxE - minE) * 0.15).clamp(5.0, 200.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Perfil de elevación', style: AppTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minY: minE - pad,
                maxY: maxE + pad,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppTheme.surfaceAlt,
                    getTooltipItems: (items) => items
                        .map((it) => LineTooltipItem(
                              'km ${it.x.toStringAsFixed(1)}\n${it.y.round()} m',
                              const TextStyle(color: Colors.white, fontSize: 12),
                            ))
                        .toList(),
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (v, meta) => Text('${v.round()}', style: const TextStyle(color: AppTheme.darkGrey, fontSize: 10)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (v, meta) => Text('${v.round()}', style: const TextStyle(color: AppTheme.darkGrey, fontSize: 10)),
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    barWidth: 2,
                    color: AppTheme.secondary,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: AppTheme.secondary.withValues(alpha: 0.18)),
                  ),
                ],
              ),
            ),
          ),
          Text('km', style: AppTheme.bodySmall),
        ],
      ),
    );
  }
}
