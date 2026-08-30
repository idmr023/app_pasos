import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_pasos/config/theme.dart';
import 'package:app_pasos/providers/tracking_provider.dart';
import 'package:share_plus/share_plus.dart'; // Añadido

class TrackingRunnerScreen extends StatefulWidget {
  final String roomCode;
  final bool isRunner;
  final double goalDistance; // Nueva meta en km

  const TrackingRunnerScreen({
    Key? key,
    required this.roomCode,
    required this.isRunner, // Enlace explícito con this.isRunner
    this.goalDistance = 5.0, // Meta por defecto 5km
  }) : super(key: key);

  @override
  State<TrackingRunnerScreen> createState() => _TrackingRunnerScreenState();
}

class _TrackingRunnerScreenState extends State<TrackingRunnerScreen> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize provider and start tracking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<TrackingProvider>();
      provider.startAsRunner(widget.roomCode, widget.goalDistance, widget.isRunner);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
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
        title: const Text('Tracking en Curso'),
        actions: [
          IconButton(
            icon: const Icon(Icons.stop),
            tooltip: 'Detener tracking',
            onPressed: () {
              context.read<TrackingProvider>().stopTracking();
              context.read<TrackingProvider>().leaveRoom();
              Navigator.pop(context);
            },
          ),
          // Botón de Compartir
          IconButton(
            icon: const Icon(Icons.share, color: AppTheme.primary),
            tooltip: 'Compartir código',
            onPressed: () {
              final code = Provider.of<TrackingProvider>(context, listen: false).roomCode ?? '';
              if (code.isNotEmpty) {
                final shareText = '¡Sígueme en mi carrera en vivo! Ingresa al código: $code';
                Share.share(shareText);
              }
            },
          ),
        ],
      ),
      body: Consumer<TrackingProvider>(
        builder: (context, provider, _) {
          return _buildRunnerBody(provider);
        },
      ),
    );
  }

  Widget _buildRunnerBody(TrackingProvider provider) {
    // Calculamos el progreso: (distancia actual / meta) * 100
    double progress = 0.0;
    if (provider.currentDistance > 0 && widget.goalDistance > 0) {
      progress = (provider.currentDistance / widget.goalDistance).clamp(0.0, 1.0);
    }

    return Stack(
      children: [
        // Progress Bar at the top
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[900],
              color: AppTheme.primary,
            ),
          ),
        ),
        // Map area (placeholder for now)
        Positioned(
          top: 40,
          left: 0,
          right: 0,
          child: Container(
            height: 250,
            color: Colors.grey[900],
            child: Center(
              child: Text(
                'Distancia: ${provider.currentDistance.toStringAsFixed(1)} km / ${widget.goalDistance} km',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),

        // Stats panel
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              color: AppTheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VELOCIDAD: ${provider.currentRunnerLocation?['speed'] != null ? (provider.currentRunnerLocation!['speed'] * 3.6).toStringAsFixed(1) + ' km/h' : '--'}',
                      style: AppTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RITMO: ${provider.currentRunnerLocation?['pace'] != null ? '${provider.currentRunnerLocation!['pace'].toInt()} min/km' : '--'}',
                      style: AppTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Chat overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 200,
            color: AppTheme.surface,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: 'Escribe un mensaje...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: AppTheme.primary),
                        onPressed: _sendMessage,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}