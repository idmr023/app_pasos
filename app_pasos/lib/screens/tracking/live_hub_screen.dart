import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:app_pasos/config/api.dart';
import 'package:app_pasos/config/theme.dart';
import 'tracking_runner_screen.dart';
import 'tracking_spectator_screen.dart';

class LiveHubScreen extends StatefulWidget {
  const LiveHubScreen({super.key});

  @override
  State<LiveHubScreen> createState() => _LiveHubScreenState();
}

class _LiveHubScreenState extends State<LiveHubScreen> {
  final _storage = const FlutterSecureStorage();
  bool _isLoading = false;
  List<Map<String, dynamic>> _pastSessions = [];
  bool _loadingSessions = false;

  @override
  void initState() {
    super.initState();
    _loadPastSessions();
  }

  Future<void> _loadPastSessions() async {
    if (_loadingSessions) return;
    setState(() => _loadingSessions = true);
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) return;
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/tracking/sessions'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(ApiConfig.timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final sessions = data['sessions'];
        if (sessions is List && mounted) {
          setState(() {
            _pastSessions = sessions
                .map((s) => Map<String, dynamic>.from(s as Map))
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint('[Tracking] Error cargando historial: $e');
    } finally {
      if (mounted) setState(() => _loadingSessions = false);
    }
  }

  String _formatSessionDate(dynamic isoDate) {
    try {
      final date = DateTime.parse(isoDate.toString()).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(date.day)}/${two(date.month)} ${two(date.hour)}:${two(date.minute)}';
    } catch (_) {
      return '';
    }
  }

  /// Devuelve el roomCode creado, o lanza con un mensaje apto para el usuario.
  Future<String> _createTrackingSession() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) {
      throw Exception('Sesión no válida. Cierra sesión y vuelve a entrar.');
    }

    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/tracking/create'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode({'title': 'Carrera en Vivo', 'isPublic': true}),
        )
        .timeout(ApiConfig.timeout);

    debugPrint('[Tracking] POST /tracking/create → ${response.statusCode}');
    debugPrint('[Tracking] Body: ${response.body}');

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      final code = data['roomCode'] as String?;
      if (code != null) return code;
      throw Exception('Respuesta del servidor inválida');
    }

    String serverMsg = '';
    try {
      serverMsg = (json.decode(response.body)['error'] ?? '').toString();
    } catch (_) {}

    if (response.statusCode == 401) {
      throw Exception(
        serverMsg.isNotEmpty
            ? '$serverMsg. Cierra sesión y vuelve a entrar.'
            : 'Sesión expirada. Cierra sesión y vuelve a entrar.',
      );
    }
    throw Exception(
      serverMsg.isNotEmpty
          ? 'El servidor rechazó la sala: $serverMsg'
          : 'Error del servidor (${response.statusCode})',
    );
  }

  Future<bool> _validateRoomCode(String code) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return false;

    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/tracking/join'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode({'roomCode': code}),
        )
        .timeout(ApiConfig.timeout);

    debugPrint('[Tracking] POST /tracking/join → ${response.statusCode}');
    return response.statusCode == 200;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.error),
    );
  }

  Future<void> _startAsRunner() async {
    // Crear sesión real en el backend para obtener un roomCode válido
    // y arrancar la grabación de inmediato (sin elegir meta previa).
    setState(() => _isLoading = true);
    String? roomCode;
    String? errorMsg;
    try {
      roomCode = await _createTrackingSession();
    } on Exception catch (e) {
      errorMsg = e.toString().replaceFirst('Exception: ', '');
    } catch (e) {
      errorMsg = 'No se pudo conectar con el servidor. ¿Está el backend activo?';
    }
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (roomCode == null) {
      _showError(errorMsg ?? 'No se pudo crear la sala de tracking');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => TrackingRunnerScreen(
              roomCode: roomCode!,
              isRunner: true,
              goalDistance: 0, // Sin meta: se muestra la distancia en vivo
            ),
      ),
    ).then((_) => _loadPastSessions());
  }

  Future<void> _joinAsSpectator() async {
    final codeController = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Unirse a Sala en Vivo'),
          content: TextField(
            controller: codeController,
            decoration: const InputDecoration(
              hintText: 'Código de 6 caracteres',
            ),
            keyboardType: TextInputType.text,
            maxLength: 6,
            textCapitalization: TextCapitalization.characters,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final code = codeController.text.trim().toUpperCase();
                if (code.length == 6) {
                  Navigator.of(dialogContext).pop(code);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Unirse'),
            ),
          ],
        );
      },
    );

    if (code == null || code.length != 6) return;

    // Validar que la sala existe y está activa antes de navegar
    setState(() => _isLoading = true);
    bool valid = false;
    try {
      valid = await _validateRoomCode(code);
    } catch (e) {
      _showError('No se pudo conectar con el servidor');
    }
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!valid) {
      _showError('Sala no encontrada o ya finalizó');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrackingSpectatorScreen(roomCode: code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.live_tv,
                    size: 120,
                    color: AppTheme.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Live Track & Support',
                    style: AppTheme.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Comparte tu carrera en tiempo real con amigos y familiares',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _startAsRunner,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 24),
                    label: const Text(
                      'Iniciar mi seguimiento',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _joinAsSpectator,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.person_search, size: 24),
                    label: const Text(
                      'Unirme como espectador',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  Text(
                    'O ingresa un código de 6 caracteres',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.darkGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  // --- Historial de carreras del usuario ---
                  if (_loadingSessions && _pastSessions.isEmpty) ...[
                    const SizedBox(height: 32),
                    const CircularProgressIndicator(),
                  ],
                  if (_pastSessions.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Mis carreras',
                        style: AppTheme.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._pastSessions.take(10).map((session) {
                      final distance =
                          (session['totalDistance'] as num?)?.toDouble() ?? 0;
                      final status = session['status'] ?? '';
                      final endedAt = session['endedAt'];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: status == 'active'
                                ? AppTheme.primary.withValues(alpha: 0.4)
                                : Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              status == 'active'
                                  ? Icons.live_tv
                                  : Icons.check_circle_outline,
                              size: 20,
                              color: status == 'active'
                                  ? AppTheme.primary
                                  : AppTheme.grey,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session['title'] ?? 'Carrera en Vivo',
                                    style: AppTheme.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    _formatSessionDate(
                                      endedAt ?? session['startedAt'],
                                    ),
                                    style: AppTheme.bodySmall.copyWith(
                                      color: AppTheme.darkGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${distance.toStringAsFixed(2)} km',
                                  style: AppTheme.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                Text(
                                  status == 'active'
                                      ? 'En curso'
                                      : 'Finalizada',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: status == 'active'
                                        ? AppTheme.primary
                                        : AppTheme.darkGrey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
