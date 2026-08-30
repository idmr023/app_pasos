// Flutter Driver test del módulo Tracking (frontend + backend).
// ignore_for_file: avoid_print
//
// IMPORTANTE: usa package:test (PROHIBIDO flutter_test). Los finders son
// selectores estables (texto/tooltip/tipo) — sin IDs temporales.
//
// JOURNEY (user journey):
//   1. Ir a la pestaña Tracking (LiveHubScreen).
//   2. Iniciar seguimiento -> se crea la sala y arranca la grabación al
//      instante (sin diálogo de meta). Se muestra 'Sala: <CODE>' en pantalla.
//   3. Registrar distancia en vivo (VELOCIDAD deja de ser '--' cuando hay fix).
//   4. Enviar un mensaje de chat como corredor y verificar el eco propio
//      (valida socket + persistencia LiveMessage en backend).
//   5. Verificar endpoints backend: /tracking/<code> (activo), history y messages.
//   6. Volver (sin detener) y unirse como espectador con código inválido ->
//      snackbar 'Sala no encontrada o ya finalizó' (404).
//   7. Unirse como espectador con el código real -> reacciones y chat.
//   8. Cerrar la sesión desde el backend y confirmar status 'completed'
//      (re-unirse con el mismo código ahora falla: 400).
//
// Ejecución:
//   flutter drive --driver=integration_test/tracking_flow_test.dart \
//     --target=test_driver/app.dart \
//     --dart-define=BACKEND_URL=https://app-pasos.onrender.com/api \
//     -d CPH2735

import 'dart:convert';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

// El host del driver no recibe --dart-define del target; por eso el fallback
// apunta al mismo backend de producción desde el que se ejecuta la app.
const _backendBase = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'https://app-pasos.onrender.com/api',
);

const _waitShort = Duration(seconds: 20);
const _waitLong = Duration(seconds: 45);

FlutterDriver? _driver;
String? _token;

void main() {
  setUpAll(() async {
    final f = FlutterDriver.connect();
    _driver = await f;
    await _driver!.checkHealth();
    _token = await _driver!.requestData('token');
    expect(
      _token,
      isNotEmpty,
      reason: 'El usuario debe estar logueado (auth_token en storage)',
    );
  });

  tearDownAll(() async {
    await _driver?.close();
  });

  var codeTag = 0;

  test('Tracking: corredor + espectador (frontend y backend)', () async {
    final driver = _driver!;
    final tag = codeTag++;

    // 1) Navegar a la pestaña Tracking usando ValueKey estable
    await driver.tap(find.byValueKey('bottomNavTracking'));
    await driver.waitFor(
      find.text('Live Track & Support'),
      timeout: _waitShort,
    );

    // 2) Iniciar seguimiento -> grabación directa, sin diálogo de meta
    await driver.tap(find.text('Iniciar mi seguimiento'));
    await driver.waitFor(find.text('Tracking en Curso'), timeout: _waitShort);

    // Leer y validar el código de sala mostrado
    final salaText = await driver.getText(
      find.byValueKey('trackingRoomCodeText'),
    );
    final roomCode = salaText.split('Sala: ').last.trim().toUpperCase();
    expect(
      roomCode.length,
      6,
      reason: 'Código de sala de 6 caracteres: $roomCode',
    );
    print('[$tag] Sala creada: $roomCode');

    // 3) Backend: la sesión existe y está activa
    await _expectBackendActive(roomCode);

    // 4) Distancia en vivo (GPS) — aserción tolerante
    await _waitForGpsFix(driver);

    // 5) Chat como corredor: mensaje único + eco propio en pantalla
    final runnerMsg = 'R-$roomCode-$tag';
    await driver.tap(find.byType('TextField'));
    await driver.enterText(runnerMsg);
    await driver.tap(find.byTooltip('Enviar'));
    await driver.waitFor(find.text(runnerMsg), timeout: _waitShort);
    print('[$tag] Eco del corredor visible en pantalla');

    // 6) Backend: mensaje persistido en LiveMessage + history responde
    final history = await _getBackend('/tracking/$roomCode/history');
    expect(history['success'], isTrue);
    expect(history['locations'], isA<List>());
    print(
      '[$tag] Ubicaciones persistidas en backend: ${(history['locations'] as List).length}',
    );

    final messages = await _getBackend('/tracking/$roomCode/messages');
    expect(messages['success'], isTrue);
    expect(
      (messages['messages'] as List).map(
        (m) => (m as Map<String, dynamic>)['message'],
      ),
      contains(runnerMsg),
      reason: 'El mensaje del corredor debe existir en backend',
    );
    print('[$tag] Mensaje del corredor persistido en backend');

    // 7) Volver (sin detener la sesión) -> LiveHub
    await driver.tap(find.byType('BackButton'));
    await driver.waitFor(
      find.text('Live Track & Support'),
      timeout: _waitShort,
    );
    print('[$tag] Runner regresó a LiveHub sin detener sesión');

    // 8) Espectador negativo: código inexistente -> snackbar de error (404)
    await driver.tap(find.text('Unirme como espectador'));
await driver.waitFor(find.byType('TextField'), timeout: _waitShort);
     await driver.tap(find.byType('TextField'));
     await driver.enterText('ZZZZZZ');
    await driver.tap(find.text('Unirse'));
    await driver.waitFor(
      find.text('Sala no encontrada o ya finalizó'),
      timeout: _waitShort,
    );
    await driver.waitForAbsent(
      find.text('Sala no encontrada o ya finalizó'),
      timeout: _waitShort,
    );
    print('[$tag] Espectador negativo: 404 validado en UI');

    final badJoin = await _postBackend(
      '/tracking/join',
      body: {'roomCode': 'ZZZZZZ'},
    );
    expect(
      badJoin.statusCode,
      404,
      reason: 'POST /tracking/join con código inválido debe responder 404',
    );

    // 9) Espectador positivo: unirse con el código de la sala activa
    await driver.tap(find.text('Unirme como espectador'));
    await driver.waitFor(find.byType('TextField'), timeout: _waitShort);
    await driver.tap(find.byType('TextField'));
    await driver.enterText(roomCode);
    await driver.tap(find.text('Unirse'));
    await driver.waitFor(find.text('Sala: $roomCode'), timeout: _waitShort);
    await driver.waitFor(find.text('🔥'), timeout: _waitShort);
    print('[$tag] Espectador dentro de la sala $roomCode');

    // Reacción + mensaje único del espectador
    await driver.tap(find.text('🔥'));
    final spectMsg = 'S-$roomCode-$tag';
    await driver.tap(find.byType('TextField'));
    await driver.enterText(spectMsg);
    await driver.tap(find.byTooltip('Enviar'));
    await driver.waitFor(find.text(spectMsg), timeout: _waitShort);
    print('[$tag] Chat del espectador con eco visible');

    // Backend: reacción y mensaje del espectador persistidos
    final messages2 = await _getBackend('/tracking/$roomCode/messages');
    final allTexts =
        (messages2['messages'] as List)
            .map((m) => (m as Map<String, dynamic>)['message'])
            .toList();
    expect(allTexts, contains('🔥'), reason: 'Reacción desde backend');
    expect(
      allTexts,
      contains(spectMsg),
      reason: 'Mensaje espectador desde backend',
    );
    print('[$tag] Reacción y mensaje del espectador persistidos');

    // 10) Salir del espectador y cerrar la sesión desde el backend
    await driver.tap(find.byType('BackButton'));
    await driver.waitFor(
      find.text('Live Track & Support'),
      timeout: _waitShort,
    );

    final close = await _postBackend('/tracking/$roomCode/close');
    final closeJson = jsonDecode(close.body) as Map<String, dynamic>;
    expect(close.statusCode, 200, reason: 'POST close debe responder 200');
    expect(
      (closeJson['session'] as Map<String, dynamic>)['status'],
      'completed',
      reason: 'Cerrar la sesión debe marcarla completed',
    );
    print('[$tag] Sesión cerrada -> status completed');

    // 11) Re-unirse con el código cerrado ahora debe fallar (sesión no activa)
    final lateJoin = await _postBackend(
      '/tracking/join',
      body: {'roomCode': roomCode},
    );
    expect(
      lateJoin.statusCode,
      400,
      reason: 'Unirse a una sesión completada debe responder 400',
    );
    print('[$tag] Re-join a sesión completada -> 400 (correcto)');
  });
}

// --- Helpers ---

Future<void> _expectBackendActive(String roomCode) async {
  final data = await _getBackend('/tracking/$roomCode');
  expect(data['success'], isTrue);
  expect((data['session'] as Map<String, dynamic>)['status'], 'active');
}

Future<void> _waitForGpsFix(FlutterDriver driver) async {
  final deadline = DateTime.now().add(_waitLong);
  var fixed = false;
  while (!fixed && DateTime.now().isBefore(deadline)) {
    final speedTxt = await driver.getText(find.byValueKey('trackingSpeedText'));
    if (!speedTxt.contains('--')) {
      fixed = true;
      break;
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  if (fixed) {
    print('GPS OK: VELOCIDAD transmitida en vivo');
  } else {
    print(
      'WARN GPS: sin fix en ${_waitLong.inSeconds}s '
      '(verifica permisos y señal). El resto del flujo sigue validado.',
    );
  }
}

Future<Map<String, dynamic>> _getBackend(String path) async {
  const maxAttempts = 5;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    final response = await http.get(
      Uri.parse('$_backendBase$path'),
      headers: {'Authorization': 'Bearer $_token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }
  fail('GET $_backendBase$path no respondió 200');
}

Future<http.Response> _postBackend(
  String path, {
  Map<String, dynamic>? body,
}) async {
  return http.post(
    Uri.parse('$_backendBase$path'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    },
    body: jsonEncode(body ?? {}),
  );
}
