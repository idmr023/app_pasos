import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/route.dart';
import '../../providers/route_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/confirm_dialog.dart';
import '../share_aura/share_aura_screen.dart';
import 'route_design_editor_screen.dart';

class RouteDetailScreen extends StatelessWidget {
  final UserRoute route;

  const RouteDetailScreen({super.key, required this.route});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Text(route.title, style: AppTheme.titleMedium),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined, color: AppTheme.primary),
            tooltip: 'Decorar ruta',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RouteDesignEditorScreen(route: route)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () async {
              final confirmed = await ConfirmDialog.show(
                context,
                title: 'Eliminar ruta',
                message: '¿Estás seguro de eliminar esta ruta?',
                confirmLabel: 'Eliminar',
                destructive: true,
              );

              if (confirmed && context.mounted) {
                final success = await context.read<RouteProvider>().deleteRoute(route.id);
                if (success && context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
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
                GlassCard(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                route.source == 'strava' ? Icons.bolt : Icons.directions_run,
                                color: route.source == 'strava' ? const Color(0xFFFC4C02) : AppTheme.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(route.source == 'strava' ? 'Strava' : 'GPS / Manual', style: AppTheme.labelLarge),
                            ],
                          ),
                          Text(
                            route.startDate != null ? '${route.startDate!.day}/${route.startDate!.month}/${route.startDate!.year}' : '',
                            style: AppTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('Distancia', '${(route.distance / 1000).toStringAsFixed(2)} km'),
                          _buildStatItem('Duración', _formatDuration(route.duration)),
                          _buildStatItem('Desnivel', '${route.elevationGain} m'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white12),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('Ritmo medio', '${(route.averagePace ~/ 60)}:${(route.averagePace % 60).toString().padLeft(2, '0')} /km'),
                          _buildStatItem('Calorías', '${route.calories} kcal'),
                          _buildStatItem('FCMed', '${route.averageHeartRate} bpm'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ShareAuraScreen(routeId: route.id)),
                      );
                    },
                    icon: const Icon(Icons.auto_awesome, color: Colors.white),
                    label: const Text('✨ Share Aura', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 1)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D4FF),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Puntos de Ruta (${route.coordinates.length})', style: AppTheme.titleMedium),
                const SizedBox(height: 12),
                GlassCard(
                  width: double.infinity,
                  child: SizedBox(
                    height: 200,
                    child: ListView.builder(
                      itemCount: route.coordinates.length,
                      itemBuilder: (ctx, i) {
                        final c = route.coordinates[i];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 12,
                            backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                            child: Text('${i + 1}', style: const TextStyle(fontSize: 10, color: AppTheme.primary)),
                          ),
                          title: Text('Lat: ${c.lat.toStringAsFixed(4)}, Lng: ${c.lng.toStringAsFixed(4)}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                          subtitle: Text('Alt: ${c.elevation.toStringAsFixed(1)}m${c.heartRate > 0 ? ' • ${c.heartRate} bpm' : ''}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: AppTheme.bodySmall),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
