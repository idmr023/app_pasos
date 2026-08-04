import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/route_provider.dart';
import '../../models/route.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_states.dart';
import '../../widgets/strava_connect_dialog.dart';
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
                                  onPressed: () => _connectStrava(context),
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
                      const Padding(padding: EdgeInsets.all(32), child: AppLoading())
                    else if (routes.isEmpty)
                      const EmptyStateCard(
                        icon: Icons.map_outlined,
                        title: 'No hay rutas registradas',
                        subtitle: 'Sincroniza tus actividades desde Strava',
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

  Future<void> _connectStrava(BuildContext context) async {
    await StravaConnectDialog.show(context);
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
