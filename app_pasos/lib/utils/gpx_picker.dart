import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'gpx.dart';

/// Abre el selector de archivos y parsea un .gpx. Devuelve null si el usuario
/// cancela o el archivo no es válido (muestra el motivo en un SnackBar).
///
/// `FileType.any`: en Android el MIME de .gpx no es estándar y el filtro por
/// extensión deja el archivo deshabilitado en muchos gestores.
Future<GpxRoute?> pickGpxRoute(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  void fail(String msg) => messenger.showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
      );
  try {
    final result = await FilePicker.pickFiles(type: FileType.any, withData: true);
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      fail('No se pudo leer el archivo');
      return null;
    }
    if (bytes.length > 25 * 1024 * 1024) {
      fail('El archivo es demasiado grande (máx. 25 MB)');
      return null;
    }
    final text = utf8.decode(bytes, allowMalformed: true);
    final baseName = file.name.replaceAll(RegExp(r'\.gpx$', caseSensitive: false), '');
    return parseGpx(text, fallbackName: baseName.isEmpty ? 'Ruta GPX' : baseName);
  } on GpxParseException catch (e) {
    fail(e.message);
  } catch (e) {
    fail('No se pudo abrir el GPX: $e');
  }
  return null;
}
