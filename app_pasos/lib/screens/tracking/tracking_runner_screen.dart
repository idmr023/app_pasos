import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String? _startError;
  bool _starting = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startTracking();
    });
  }

  Future<void> _startTracking() async {
    setState(() {
      _starting = true;
      _startError = null;
    });
    final provider = context.read<TrackingProvider>();
    try {
      await provider.startAsRunner(
        widget.roomCode,
        widget.goalDistance,
        widget.isRunner,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _startError = '$e');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _retry() {
    _startTracking();
  }

  void _backToHub() {
    Navigator.pop(context);
  }

  Future<bool> _confirmExit() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Detener el tracking'),
          content: const Text('¿Salir y detener el seguimiento en vivo?'),
          actions: [
            TextButton(
              key: const ValueKey('runnerExitCancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Quedarme'),
            ),
            TextButton(
              key: const ValueKey('runnerExitConfirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Salir'),
            ),
          ],
        );
      },
    );
    return result == true;
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final provider = context.read<TrackingProvider>();
        final navigator = Navigator.of(context);
        final exit = await _confirmExit();
        if (exit && mounted) {
          provider.stopTracking();
          provider.leaveRoom();
          if (mounted) navigator.pop();
        }
      },
      child: Scaffold(
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
            IconButton(
              icon: const Icon(Icons.share, color: AppTheme.primary),
              tooltip: 'Compartir código',
              onPressed: () {
                final code =
                    Provider.of<TrackingProvider>(
                      context,
                      listen: false,
                    ).roomCode ??
                    '';
                if (code.isNotEmpty) {
                  final shareText =
                      '¡Sígueme en mi carrera en vivo! Ingresa al código: $code';
                  Share.share(shareText);
                }
              },
            ),
          ],
        ),
        body: _buildBody(),
      ),
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
        return _buildRunnerBody(provider);
      },
    );
  }

  Widget _buildRunnerBody(TrackingProvider provider) {
    // Calculamos el progreso: (distancia actual / meta) * 100
    double progress = 0.0;
    if (provider.currentDistance > 0 && widget.goalDistance > 0) {
      progress = (provider.currentDistance / widget.goalDistance).clamp(
        0.0,
        1.0,
      );
    }

    return Stack(
      children: [
        // Progress Bar at the top (solo si hay meta definida)
        if (widget.goalDistance > 0)
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
                widget.goalDistance > 0
                    ? 'Distancia: ${provider.currentDistance.toStringAsFixed(1)} km / ${widget.goalDistance} km'
                    : 'Distancia: ${provider.currentDistance.toStringAsFixed(1)} km',
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
                      key: const ValueKey('trackingSpeedText'),
                      style: AppTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RITMO: ${provider.currentRunnerLocation?['pace'] != null ? '${provider.currentRunnerLocation!['pace'].toInt()} min/km' : '--'}',
                      style: AppTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.meeting_room,
                          size: 18,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Sala: ${widget.roomCode}',
                          key: const ValueKey('trackingRoomCodeText'),
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.copy,
                            size: 16,
                            color: AppTheme.primary,
                          ),
                          tooltip: 'Copiar código',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: widget.roomCode),
                            );
                          },
                        ),
                      ],
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
                        tooltip: 'Enviar',
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
