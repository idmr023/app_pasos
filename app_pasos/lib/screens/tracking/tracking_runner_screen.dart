import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:app_pasos/config/api.dart';
import 'package:app_pasos/config/theme.dart';
import 'package:app_pasos/providers/tracking_provider.dart';
import 'package:share_plus/share_plus.dart';

class TrackingRunnerScreen extends StatefulWidget {
  final String roomCode;
  final bool isRunner;
  final double goalDistance; // Meta en km (0 = sin meta)

  const TrackingRunnerScreen({
    super.key,
    required this.roomCode,
    required this.isRunner,
    this.goalDistance = 5.0,
  });

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
    final distanceKm = context.read<TrackingProvider>().currentDistance;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Detener el tracking'),
          content: Text(
            '¿Salir y detener el seguimiento en vivo?\n\n'
            'Se guardarán tus ${distanceKm.toStringAsFixed(2)} km '
            'y verás el resumen de la carrera.',
          ),
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

  /// Flujo único de salida (back y botón ⏹): confirma, cierra la sesión
  /// en el backend (guardado determinista), muestra el resumen y sale.
  Future<void> _exitFlow() async {
    final confirmed = await _confirmExit();
    if (!confirmed || !mounted) return;

    final provider = context.read<TrackingProvider>();
    final navigator = Navigator.of(context);

    // 1) Detener GPS/socket y capturar stats locales ANTES de cualquier reset
    provider.stopTracking();
    final localDistance = provider.currentDistance;
    final localElapsed = provider.elapsedTime;

    // 2) Cerrar la sesión en el backend (persiste totalDistance/avgSpeed/...)
    //    Si falla, el fallback es el timer de 30s del servidor al desconectar.
    Map<String, dynamic>? serverStats;
    if (!mounted) return;
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    _showClosingDialog(); // sin await: se cierra tras la petición
    serverStats = await _closeSessionOnBackend();
    rootNavigator.pop(); // cierra el diálogo de "Guardando..."

    // 3) Liberar socket y resetear estado
    provider.leaveRoom();

    // 4) Resumen final: stats del server si están; si no, calculadas locally
    final elapsedSec = localElapsed.inSeconds;
    final serverDistance = (serverStats?['totalDistance'] as num?)?.toDouble();
    var distanceKm =
        (serverDistance != null && serverDistance > 0)
            ? serverDistance
            : localDistance;
    var avgPace = (serverStats?['avgPace'] as num?)?.toDouble() ?? 0;
    var avgSpeed = (serverStats?['avgSpeed'] as num?)?.toDouble() ?? 0;
    if (avgSpeed <= 0 && distanceKm > 0 && elapsedSec > 0) {
      avgSpeed = distanceKm / (elapsedSec / 3600);
    }
    if (avgPace <= 0 && distanceKm > 0 && elapsedSec > 0) {
      avgPace = (elapsedSec / 60) / distanceKm;
    }

    if (mounted) {
      await _showSummaryDialog(
        distanceKm: distanceKm,
        elapsed: localElapsed,
        avgPace: avgPace,
        avgSpeed: avgSpeed,
      );
    }

    // 5) Volver al hub
    if (mounted) navigator.pop();
  }

  Future<void> _showClosingDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => const AlertDialog(
            backgroundColor: AppTheme.surface,
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Expanded(child: Text('Guardando tu carrera...')),
              ],
            ),
          ),
    );
  }

  Future<Map<String, dynamic>?> _closeSessionOnBackend() async {
    try {
      final token = await const FlutterSecureStorage().read(key: 'auth_token');
      if (token == null) return null;

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/tracking/${widget.roomCode}/close'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({}),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;
      final data = json.decode(response.body);
      final session = data['session'];
      if (session is Map<String, dynamic>) return session;
      return null;
    } catch (e) {
      debugPrint('[Tracking] Error cerrando sesión: $e');
      return null;
    }
  }

  Future<void> _showSummaryDialog({
    required double distanceKm,
    required Duration elapsed,
    required double avgPace,
    required double avgSpeed,
  }) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text(
            '¡Carrera finalizada!',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, size: 56, color: AppTheme.primary),
              const SizedBox(height: 16),
              Text(
                '${distanceKm.toStringAsFixed(2)} km',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tiempo: ${_formatDuration(elapsed)}',
                style: AppTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Ritmo: ${avgPace > 0 ? '${_formatPace(avgPace)} /km' : '--'}',
                style: AppTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Velocidad media: '
                '${avgSpeed > 0 ? '${avgSpeed.toStringAsFixed(1)} km/h' : '--'}',
                style: AppTheme.bodyMedium,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                final paceText =
                    avgPace > 0 ? '${_formatPace(avgPace)} min/km' : '';
                Share.share(
                  '¡Terminé mi carrera! 🏃‍♂️ '
                  '${distanceKm.toStringAsFixed(2)} km en '
                  '${_formatDuration(elapsed)}'
                  '${paceText.isNotEmpty ? ' ($paceText)' : ''}',
                );
              },
              child: const Text('Compartir'),
            ),
            FilledButton(
              key: const ValueKey('runnerSummaryDone'),
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Listo'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    // Asegurar liberación de socket/GPS si la pantalla se destruye por
    // cualquier vía (error, navegación externa, etc.). leaveRoom es idempotente.
    context.read<TrackingProvider>().leaveRoom();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  String _formatPace(double paceMinPerKm) {
    if (paceMinPerKm <= 0 || !paceMinPerKm.isFinite) return '--';
    final totalSeconds = (paceMinPerKm * 60).round();
    final min = totalSeconds ~/ 60;
    final sec = totalSeconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
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
        await _exitFlow();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tracking en Curso'),
          actions: [
            IconButton(
              icon: const Icon(Icons.stop),
              tooltip: 'Detener tracking',
              onPressed: _exitFlow,
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
                  final base = ApiConfig.baseUrl.replaceFirst(
                    RegExp(r'/api/?$'),
                    '',
                  );
                  final link = '$base/track/$code';
                  final shareText = '¡Sígueme en mi carrera en vivo! $link';
                  Share.share(shareText);
                  Clipboard.setData(ClipboardData(text: link));
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
              Text(
                _startError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
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
                  Text(
                    provider.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
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
    final loc = provider.currentRunnerLocation;
    final speed = (loc?['speed'] as num?)?.toDouble();
    final instantSpeedKmh = speed != null && speed > 0 ? speed * 3.6 : null;
    final paceFromGps = (loc?['pace'] as num?)?.toDouble() ?? 0;
    final distanceKm = provider.currentDistance;

    // Fallback: si el GPS no entrega `speed` (común en Android), calculamos
    // la velocidad y el ritmo a partir de la distancia acumulada y el reloj.
    final elapsedSec = provider.elapsedTime.inSeconds;
    final avgSpeedKmh =
        distanceKm > 0 && elapsedSec > 3
            ? distanceKm / (elapsedSec / 3600)
            : null;

    final speedKmh = instantSpeedKmh ?? avgSpeedKmh;
    final pace =
        paceFromGps > 0
            ? paceFromGps
            : (avgSpeedKmh != null && avgSpeedKmh > 0 ? 60 / avgSpeedKmh : 0.0);

    final hasGps = speedKmh != null || pace > 0 || elapsedSec <= 8;

    double progress = 0.0;
    if (widget.goalDistance > 0) {
      progress = (distanceKm / widget.goalDistance).clamp(0.0, 1.0);
    }

    return Column(
      children: [
        if (widget.goalDistance > 0)
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[900],
            color: AppTheme.primary,
          ),
        // Dashboard de métricas en vivo
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E2235), Color(0xFF12172B)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              children: [
                Text(
                  _formatDuration(provider.elapsedTime),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 46,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'TIEMPO',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    _buildMetric(
                      'Distancia',
                      '${distanceKm.toStringAsFixed(2)} km',
                    ),
                    _buildMetric(
                      'Velocidad',
                      speedKmh == null
                          ? '--'
                          : '${speedKmh.toStringAsFixed(1)} km/h',
                      valueKey: const ValueKey('trackingSpeedText'),
                    ),
                    _buildMetric(
                      'Ritmo',
                      pace > 0 ? '${_formatPace(pace)} /km' : '--',
                    ),
                  ],
                ),
                if (!hasGps) ...[
                  const SizedBox(height: 14),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.gps_off, size: 14, color: AppTheme.error),
                      SizedBox(width: 6),
                      Text(
                        'Buscando señal GPS...',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        // Sala + copiar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.meeting_room, size: 18, color: AppTheme.primary),
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
                icon: const Icon(Icons.copy, size: 16, color: AppTheme.primary),
                tooltip: 'Copiar código',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.roomCode));
                },
              ),
            ],
          ),
        ),
        // Chat
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                if (!provider.trackingStopped)
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
                  child:
                      provider.messages.isEmpty
                          ? const Center(
                            child: Text(
                              'Manda ánimo a tu sala',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 13,
                              ),
                            ),
                          )
                          : ListView.builder(
                            itemCount: provider.messages.length,
                            itemBuilder: (context, index) {
                              final msg = provider.messages[index];
                              return ListTile(
                                title: Text(
                                  msg['senderName'] ?? 'Espectador',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
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

  Widget _buildMetric(String label, String value, {Key? valueKey}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            key: valueKey,
            maxLines: 1,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
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
      ),
    );
  }
}
