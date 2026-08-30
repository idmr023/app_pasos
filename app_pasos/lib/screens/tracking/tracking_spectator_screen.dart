import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_pasos/config/theme.dart';
import 'package:app_pasos/providers/tracking_provider.dart';

class TrackingSpectatorScreen extends StatefulWidget {
  final String roomCode;

  const TrackingSpectatorScreen({Key? key, required this.roomCode})
    : super(key: key);

  @override
  State<TrackingSpectatorScreen> createState() =>
      _TrackingSpectatorScreenState();
}

class _TrackingSpectatorScreenState extends State<TrackingSpectatorScreen> {
  final TextEditingController _messageController = TextEditingController();
  String? _startError;
  bool _starting = true;

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
      await provider.joinAsSpectator(widget.roomCode);
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
    final locations = provider.locations;

    return Stack(
      children: [
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
                    children: const [
                      Icon(Icons.flag, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'El corredor ha detenido el tracking',
                          style: TextStyle(
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

        // Map area with OpenStreetMap using flutter_map would go here
        // For now, a placeholder
        Align(
          alignment: Alignment.topCenter,
          heightFactor: provider.trackingStopped ? 0.4 : null,
          child: Padding(
            padding: EdgeInsets.only(
              top: provider.trackingStopped ? 60 : 0,
            ),
            child: currentLoc != null
                  ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_pin, size: 80, color: AppTheme.primary),
                      const SizedBox(height: 16),
                      Text(
                        'Lat: ${currentLoc['latitude']}, Lng: ${currentLoc['longitude']}',
                        style: AppTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Velocidad: ${((currentLoc['speed'] ?? 0) * 3.6).toStringAsFixed(1)} km/h',
                        style: AppTheme.bodySmall,
                      ),
                    ],
                  )
                  : const Text(
                    'Esperando datos del corredor...',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
        ),
        ),

        // Route polyline (accumulated locations)
        if (locations.isNotEmpty)
          Positioned(
            top: 100,
            child: Card(
              color: AppTheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Puntos de ruta: ${locations.length}',
                  style: AppTheme.bodySmall,
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
