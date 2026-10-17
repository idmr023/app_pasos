import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:app_pasos/config/theme.dart';
import 'package:app_pasos/providers/tracking_provider.dart';

class TrackingSpectatorScreen extends StatefulWidget {
  final String roomCode;
  final String? guestName;

  const TrackingSpectatorScreen({
    super.key,
    required this.roomCode,
    this.guestName,
  });

  @override
  State<TrackingSpectatorScreen> createState() =>
      _TrackingSpectatorScreenState();
}

class _TrackingSpectatorScreenState extends State<TrackingSpectatorScreen> {
  final TextEditingController _messageController = TextEditingController();
  final MapController _mapController = MapController();
  String? _startError;
  bool _starting = true;
  bool _followRunner = true;
  LatLng? _lastCentered;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinRoom();
    });
  }

  Future<void> _joinRoom() async {
    setState(() {
      _starting = true;
      _startError = null;
    });
    final provider = context.read<TrackingProvider>();
    try {
      if (widget.guestName != null) {
        await provider.joinAsGuest(widget.roomCode, guestName: widget.guestName!);
      } else {
        await provider.joinAsSpectator(widget.roomCode);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _startError = '$e');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _retry() {
    _joinRoom();
  }

  void _backToHub() {
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _messageController.dispose();
    context.read<TrackingProvider>().leaveRoom();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    context.read<TrackingProvider>().sendMessage(text);
    _messageController.clear();
  }

  void _centerOnRunner(TrackingProvider provider) {
    if (!_followRunner) return;
    final loc = provider.currentRunnerLocation;
    if (loc == null) return;
    final lat = (loc['latitude'] as num?)?.toDouble();
    final lng = (loc['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    final target = LatLng(lat, lng);
    // Evitar movers el mapa si ya está recientrado en esta posición
    if (_lastCentered != null &&
        (_lastCentered!.latitude - target.latitude).abs() < 1e-6 &&
        (_lastCentered!.longitude - target.longitude).abs() < 1e-6) {
      return;
    }
    _lastCentered = target;
    _mapController.move(target, _mapController.camera.zoom < 14
        ? 16
        : _mapController.camera.zoom);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sala: ${widget.roomCode}'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_startError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
              const SizedBox(height: 16),
              Text(_startError!, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _retry,
                child: const Text('Reintentar'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _backToHub,
                child: const Text('Volver al Hub'),
              ),
            ],
          ),
        ),
      );
    }

    if (_starting) {
      return const Center(child: CircularProgressIndicator());
    }

    return Consumer<TrackingProvider>(
      builder: (context, provider, _) {
        if (provider.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, size: 64, color: AppTheme.error),
                  const SizedBox(height: 16),
                  Text(provider.error!, textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: _backToHub,
                    child: const Text('Volver al Hub'),
                  ),
                ],
              ),
            ),
          );
        }
        return _buildSpectatorBody(provider);
      },
    );
  }

  Widget _buildSpectatorBody(TrackingProvider provider) {
    final currentLoc = provider.currentRunnerLocation;
    final routePoints = provider.routePoints;

    // Centrar el mapa en el corredor cuando llega una nueva posición
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _centerOnRunner(provider);
    });

    final LatLng? runnerLatLng = currentLoc != null &&
            currentLoc['latitude'] is num &&
            currentLoc['longitude'] is num
        ? LatLng(
            (currentLoc['latitude'] as num).toDouble(),
            (currentLoc['longitude'] as num).toDouble(),
          )
        : (routePoints.isNotEmpty ? routePoints.last : null);

    final speedKmh = ((currentLoc?['speed'] as num?) ?? 0).toDouble() * 3.6;
    final distanceKm = provider.currentDistance;
    final pace = (currentLoc?['pace'] as num?)?.toDouble() ?? 0;

    return Stack(
      children: [
        // --- Mapa en vivo (OpenStreetMap, gratis y sin API key) ---
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: runnerLatLng ?? const LatLng(-12.0464, -77.0428),
              initialZoom: 15,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom |
                    InteractiveFlag.drag |
                    InteractiveFlag.doubleTapZoom,
              ),
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) {
                  // El usuario movió el mapa manualmente: pausar el seguimiento
                  setState(() => _followRunner = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.apppasos.app_pasos',
                maxZoom: 19,
              ),
              if (routePoints.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 5,
                      color: AppTheme.primary,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (runnerLatLng != null)
                    Marker(
                      point: runnerLatLng,
                      width: 48,
                      height: 48,
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: AppTheme.primary,
                        size: 48,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // --- Overlay de métricas del corredor ---
        Positioned(
          top: provider.trackingStopped ? 60 : 12,
          left: 12,
          right: 12,
          child: Card(
            color: AppTheme.surface.withValues(alpha: 0.92),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: currentLoc != null
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStat('Distancia', '${distanceKm.toStringAsFixed(2)} km'),
                        _buildStat('Velocidad', '${speedKmh.toStringAsFixed(1)} km/h'),
                        _buildStat(
                          'Ritmo',
                          pace > 0 ? '${_formatPace(pace)} /km' : '--',
                        ),
                      ],
                    )
                  : const Center(
                      child: Text(
                        'Esperando datos del corredor...',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
            ),
          ),
        ),

        // Botón para reanudar el seguimiento del corredor
        if (!_followRunner && runnerLatLng != null)
          Positioned(
            top: provider.trackingStopped ? 130 : 84,
            right: 12,
            child: FloatingActionButton.small(
              backgroundColor: AppTheme.primary,
              tooltip: 'Seguir al corredor',
              onPressed: () {
                setState(() {
                  _followRunner = true;
                  _lastCentered = null;
                });
                _centerOnRunner(provider);
              },
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
          ),

        // Banner: tracking detenido
        if (provider.trackingStopped)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: AppTheme.error,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flag, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          provider.finalStats != null
                              ? 'Carrera finalizada — ${((provider.finalStats!['totalDistance'] as num?) ?? 0).toStringAsFixed(2)} km'
                              : 'El corredor ha detenido el tracking',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Chat section
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 250,
            color: AppTheme.surface,
            child: Column(
              children: [
                // Quick reactions
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      _QuickReactionButton(
                        emoji: '🔥',
                        onTap: () => provider.sendMessage('🔥'),
                        provider: provider,
                      ),
                      const SizedBox(width: 6),
                      _QuickReactionButton(
                        emoji: '💪',
                        onTap: () => provider.sendMessage('💪'),
                        provider: provider,
                      ),
                      const SizedBox(width: 6),
                      _QuickReactionButton(
                        emoji: '⚡',
                        onTap: () => provider.sendMessage('⚡'),
                        provider: provider,
                      ),
                      const SizedBox(width: 6),
                      _QuickReactionButton(
                        emoji: '👏',
                        onTap: () => provider.sendMessage('👏'),
                        provider: provider,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Messages list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: provider.messages.length,
                    itemBuilder: (context, index) {
                      final msg = provider.messages[index];
                      return ListTile(
                        title: Text(
                          msg['senderName'] ?? 'Espectador',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(msg['message'] ?? ''),
                      );
                    },
                  ),
                ),
                // Input
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  color: AppTheme.surface,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: const InputDecoration(
                            hintText: 'Escribe un mensaje...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: AppTheme.primary),
                        tooltip: 'Enviar',
                        onPressed: _sendMessage,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatPace(double paceMinPerKm) {
    if (paceMinPerKm <= 0 || !paceMinPerKm.isFinite) return '--';
    final totalSeconds = (paceMinPerKm * 60).round();
    final min = totalSeconds ~/ 60;
    final sec = totalSeconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
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
    );
  }
}

class _QuickReactionButton extends StatelessWidget {
  final String emoji;
  final VoidCallback onTap;
  final TrackingProvider provider;

  const _QuickReactionButton({
    required this.emoji,
    required this.onTap,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: provider.isTracking ? AppTheme.primary : AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}
