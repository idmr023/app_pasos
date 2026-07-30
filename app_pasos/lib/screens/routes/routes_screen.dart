import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/route_provider.dart';
import '../../models/route.dart';
import '../../widgets/glass_card.dart';
import 'route_detail_screen.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.token != null) {
        context.read<RouteProvider>().setToken(auth.token!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final routeProv = context.watch<RouteProvider>();
    final routes = routeProv.routes;
    final user = context.watch<AuthProvider>().user;
    final hasStrava = user?.hasStrava ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async => routeProv.loadRoutes(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Rutas y GPS', style: AppTheme.titleLarge.copyWith(letterSpacing: 1.5)),
                        if (hasStrava)
                          ElevatedButton.icon(
                            onPressed: () async {
                              final count = await routeProv.syncStrava();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Sincronizados $count nuevos entrenamientos de Strava')),
                                );
                              }
                            },
                            icon: const Icon(Icons.sync, size: 16, color: Color(0xFFFC4C02)),
                            label: const Text('Sincronizar', style: TextStyle(color: Colors.white, fontSize: 12)),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF242424)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Connect Strava banner ONLY if not connected, positioned centered
                    if (!hasStrava) ...[
                      Center(
                        child: GlassCard(
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.bolt, size: 48, color: Color(0xFFFC4C02)),
                                const SizedBox(height: 12),
                                const Text('Conecta con Strava', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                const Text('Sincroniza tus carreras y rutas GPS automáticamente.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 13)),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final url = await routeProv.getStravaAuthUrl();
                                    if (url != null && context.mounted) {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          backgroundColor: AppTheme.surface,
                                          title: const Text('Conectar con Strava', style: TextStyle(color: Colors.white)),
                                          content: Text('Para vincular Strava, ve a Mi Perfil o abre este enlace en tu navegador:\n\n$url', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                Navigator.pushNamed(context, '/profile');
                                              },
                                              child: const Text('Ir a Mi Perfil'),
                                            ),
                                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
                                          ],
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.bolt, size: 18, color: Colors.white),
                                  label: const Text('Conectar Strava', style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFC4C02)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text('Tus Actividades', style: AppTheme.titleMedium),
                    const SizedBox(height: 12),
                    if (routeProv.isLoading)
                      const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppTheme.primary)))
                    else if (routes.isEmpty)
                      GlassCard(
                        width: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              const Icon(Icons.map_outlined, size: 48, color: AppTheme.darkGrey),
                              const SizedBox(height: 16),
                              Text('No hay rutas registradas', style: AppTheme.bodyLarge),
                              const SizedBox(height: 4),
                              Text('Sincroniza tus actividades desde Strava', style: AppTheme.bodyMedium),
                            ],
                          ),
                        ),
                      )
                    else
                      Column(
                        children: routes.map((r) => _buildRouteCard(r)).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard(UserRoute route) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RouteDetailScreen(route: route)),
        );
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: route.source == 'strava' ? const Color(0xFFFC4C02).withValues(alpha: 0.15) : AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              route.source == 'strava' ? Icons.bolt : Icons.directions_run,
              color: route.source == 'strava' ? const Color(0xFFFC4C02) : AppTheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(route.title, style: AppTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '${(route.distance / 1000).toStringAsFixed(2)} km • ${route.elevationGain}m desniv.',
                  style: AppTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppTheme.darkGrey),
        ],
      ),
    );
  }
}
