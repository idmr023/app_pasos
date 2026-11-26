import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:app_pasos/config/theme.dart';
import 'package:app_pasos/services/location_service.dart';

/// Verifica el acceso a ubicación antes de grabar una carrera y explica al
/// usuario qué falta con un diálogo. Devuelve true si se puede iniciar.
///
/// - GPS apagado → pide activarlo (abre ajustes de ubicación).
/// - Permiso negado → lo solicita al sistema; si sigue negado, explica por qué.
/// - Negado para siempre → lleva a los ajustes de la app.
/// - "Mientras se usa la app" (Android) → recomienda "Permitir siempre" pero
///   deja continuar: el foreground service mantiene el GPS con pantalla apagada.
Future<bool> ensureTrackingLocationAccess(BuildContext context) async {
  final access = await LocationService().checkAccess();
  if (!context.mounted) return false;

  switch (access) {
    case LocationAccess.always:
      return true;

    case LocationAccess.whileInUse:
      if (defaultTargetPlatform != TargetPlatform.android) return true;
      final goToSettings = await _showLocationDialog(
        context,
        icon: Icons.my_location,
        title: 'Mejora la grabación',
        message:
            'Tienes la ubicación en "Mientras se usa la app". La carrera se '
            'grabará igual, pero para que no se corte si Android cierra la app '
            'en segundo plano, elige "Permitir todo el tiempo" en Ajustes.',
        primaryLabel: 'Abrir ajustes',
        secondaryLabel: 'Continuar así',
      );
      if (goToSettings == true) {
        await Geolocator.openAppSettings();
        return false; // Al volver, el usuario pulsa "Iniciar" de nuevo.
      }
      return goToSettings == false; // null = cerró el diálogo → no iniciar.

    case LocationAccess.serviceDisabled:
      final open = await _showLocationDialog(
        context,
        icon: Icons.location_off,
        title: 'Activa tu GPS',
        message:
            'La ubicación del teléfono está apagada. Actívala para poder '
            'registrar tu recorrido.',
        primaryLabel: 'Activar ubicación',
        secondaryLabel: 'Cancelar',
      );
      if (open == true) await Geolocator.openLocationSettings();
      return false;

    case LocationAccess.denied:
      final retry = await _showLocationDialog(
        context,
        icon: Icons.location_disabled,
        title: 'Necesitamos tu ubicación',
        message:
            'Sin permiso de ubicación no podemos medir tu distancia ni '
            'mostrar tu recorrido a quienes te siguen en vivo.',
        primaryLabel: 'Dar permiso',
        secondaryLabel: 'Ahora no',
      );
      if (retry == true && context.mounted) {
        return ensureTrackingLocationAccess(context);
      }
      return false;

    case LocationAccess.deniedForever:
      final open = await _showLocationDialog(
        context,
        icon: Icons.location_disabled,
        title: 'Permiso de ubicación bloqueado',
        message:
            'Bloqueaste el permiso de ubicación para App Pasos. Ve a Ajustes '
            '› Permisos › Ubicación y elige "Permitir todo el tiempo" o '
            '"Mientras se usa la app".',
        primaryLabel: 'Abrir ajustes',
        secondaryLabel: 'Cancelar',
      );
      if (open == true) await Geolocator.openAppSettings();
      return false;
  }
}

/// true = botón principal, false = secundario, null = cerrado sin elegir.
Future<bool?> _showLocationDialog(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  required String primaryLabel,
  required String secondaryLabel,
}) {
  return showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          backgroundColor: AppTheme.surface,
          icon: Icon(icon, color: AppTheme.primary, size: 36),
          title: Text(title, textAlign: TextAlign.center),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(secondaryLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(primaryLabel),
            ),
          ],
        ),
  );
}
