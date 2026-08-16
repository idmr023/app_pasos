import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_pasos/config/theme.dart';
import 'package:app_pasos/providers/tracking_provider.dart';

class LiveHubScreen extends StatefulWidget {
  const LiveHubScreen({super.key});

  @override
  State<LiveHubScreen> createState() => _LiveHubScreenState();
}

class _LiveHubScreenState extends State<LiveHubScreen> {
  bool _isRunner = false;
  String _roomCode = '';

  @override
  void initState() {
    super.initState();
    // Initialize tracking provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<TrackingProvider>();
      // Provider initialized lazily
    });
  }

  Future<void> _startAsRunner() async {
    // Generate room code
    final code = '${(DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0')}';
    // Actually better to call backend create endpoint, but for now generate locally
    setState(() {
      _roomCode = code.toUpperCase();
    });
    // Navigate to tracking screen as runner
    Navigator.pushNamed(context, '/tracking/runner',
        arguments: {'roomCode': _roomCode, 'isRunner': true});
  }

  Future<void> _joinAsSpectator() async {
    // Show input dialog for room code
    final codeController = TextEditingController();
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Unirse a Sala en Vivo'),
          content: TextField(
            controller: codeController,
            decoration:
                const InputDecoration(hintText: 'Código de 6 caracteres'),
            keyboardType: TextInputType.text,
            maxLength: 6,
            textCapitalization: TextCapitalization.characters,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final code = codeController.text.trim().toUpperCase();
                if (code.length == 6) {
                  Navigator.of(context).pop();
                  Navigator.pushNamed(
                      context, '/tracking/spectator',
                      arguments: {'roomCode': code});
                }
              },
              child: const Text('Unirse'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon / Illustración
              Icon(
                Icons.live_tv,
                size: 120,
                color: AppTheme.primary.withOpacity(0.5),
              ),
              const SizedBox(height: 32),
              // Título
              Text(
                'Live Track & Support',
                style: AppTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Subtítulo
              Text(
                'Comparte tu carrera en tiempo real con amigos y familiares',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              // Botón Iniciar Tracking
              ElevatedButton.icon(
                onPressed: _startAsRunner,
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
              // Botón Unirse como espectador
              OutlinedButton.icon(
                onPressed: _joinAsSpectator,
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 48),
              // Información adicional
              Text(
                'O ingresa un código de 6 dígitos',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.darkGrey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}