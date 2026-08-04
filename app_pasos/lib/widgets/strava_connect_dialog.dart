import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../providers/route_provider.dart';

const Color _stravaOrange = Color(0xFFFC4C02);

class StravaConnectDialog {
  /// Muestra el diálogo de 3 pasos para conectar con Strava.
  /// Devuelve `true` si la conexión se completó con éxito.
  static Future<bool> show(BuildContext context, {String? onConnectedMessage}) async {
    final routeProv = context.read<RouteProvider>();
    final result = await routeProv.initStravaConnection();
    if (!context.mounted) return false;

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al iniciar conexión con Strava'), backgroundColor: AppTheme.error),
      );
      return false;
    }

    final url = result['url'] as String;
    final state = result['state'] as String;

    if (!context.mounted) return false;

    final connected = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _StravaDialog(url: url, state: state),
    );

    if (connected == true && onConnectedMessage != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(onConnectedMessage)),
      );
    }

    return connected == true;
  }
}

class _StravaDialog extends StatefulWidget {
  final String url;
  final String state;

  const _StravaDialog({required this.url, required this.state});

  @override
  State<_StravaDialog> createState() => _StravaDialogState();
}

class _StravaDialogState extends State<_StravaDialog> {
  bool _polling = false;
  bool _timedOut = false;
  bool _closed = false;

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }

  Future<void> _openStrava() async {
    final uri = Uri.parse(widget.url);
    if (!await canLaunchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el navegador')),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    setState(() => _polling = true);
    _waitForConnection();
  }

  Future<void> _waitForConnection() async {
    final routeProv = context.read<RouteProvider>();
    const maxAttempts = 60;
    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (_closed || !mounted) return;

      final connected = await routeProv.checkStravaStatus(widget.state);
      if (_closed || !mounted) return;

      if (connected) {
        Navigator.of(context).pop(true);
        if (_closed || !mounted) return;
        final count = await routeProv.syncStrava();
        if (!_closed && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('¡Conectado a Strava! Sincronizados $count entrenamientos')),
          );
        }
        return;
      }
    }

    if (_closed || !mounted) return;
    setState(() => _timedOut = true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Conectar con Strava', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt, size: 48, color: _stravaOrange),
            const SizedBox(height: 16),
            if (_timedOut) ...[
              const Icon(Icons.timer_off, size: 40, color: AppTheme.error),
              const SizedBox(height: 12),
              const Text(
                'Tiempo de espera agotado.\nVuelve a intentarlo.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              const Text('1. Toca el botón para abrir Strava', style: TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('2. Autoriza la aplicación', style: TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('3. Vuelve a la app automáticamente', style: TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
            ],
            const SizedBox(height: 24),
            if (!_polling)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openStrava,
                  icon: const Icon(Icons.open_in_browser, color: Colors.white),
                  label: const Text('Abrir Strava', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _stravaOrange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )
            else ...[
              const CircularProgressIndicator(color: _stravaOrange),
              const SizedBox(height: 12),
              const Text('Esperando autorización...', style: TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
