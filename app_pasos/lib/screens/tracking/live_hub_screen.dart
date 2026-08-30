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

  Future<String?> _createTrackingSession() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) {
      debugPrint('[Tracking] No auth_token en storage');
      return null;
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
    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      return data['roomCode'] as String?;
    }
    debugPrint('[Tracking] Error body: ${response.body}');
    return null;
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
    try {
      roomCode = await _createTrackingSession();
    } catch (e) {
      _showError('No se pudo conectar con el servidor');
    }
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (roomCode == null) {
      _showError('No se pudo crear la sala de tracking');
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
    );
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
                    color: AppTheme.primary.withOpacity(0.5),
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
