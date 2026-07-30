import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/route.dart';
import '../../providers/route_provider.dart';
import '../../widgets/glass_card.dart';

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
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.surface,
                  title: const Text('Eliminar ruta', style: TextStyle(color: Colors.white)),
                  content: const Text('¿Estás seguro de eliminar esta ruta?', style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent))),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
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
