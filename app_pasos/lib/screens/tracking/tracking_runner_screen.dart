import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_pasos/config/theme.dart';
import 'package:app_pasos/providers/tracking_provider.dart';

class TrackingRunnerScreen extends StatefulWidget {
  final String roomCode;
  final bool isRunner;

  const TrackingRunnerScreen({
    Key? key,
    required this.roomCode,
    required this.isRunner,
  }) : super(key: key);

  @override
  State<TrackingRunnerScreen> createState() => _TrackingRunnerScreenState();
}

class _TrackingRunnerScreenState extends State<TrackingRunnerScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize provider and start tracking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<TrackingProvider>();
      provider.startAsRunner(widget.roomCode);
    });
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
              Navigator.pop(context);
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
    return Stack(
      children: [
        // Map area (placeholder for now)
        Container(
          height: 300,
          color: Colors.grey[900],
          child: const Center(
            child: Text(
              'Mapa en tiempo real - GPS activo',
              style: TextStyle(color: Colors.white70),
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
                          onSubmitted: (_) =>
                              provider.sendMessage(_),
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
                        onPressed: () =>
                            provider.sendMessage('¡Vamos!'),
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