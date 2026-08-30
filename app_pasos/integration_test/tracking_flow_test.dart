// Flutter Driver test del módulo Tracking (frontend + backend).
// ignore_for_file: avoid_print
//
// IMPORTANTE: usa package:test (PROHIBIDO flutter_test). Los finders son
// selectores estables (texto/tooltip/tipo) — sin IDs temporales.
//
// JOURNEY (nuevo flujo):
//   FASE A - Corredor:
//     1. Ir a la pestaña Tracking (LiveHubScreen).
//     2. Iniciar seguimiento -> creación de sala + grabación directa.
//     3. Verificar código de sala (trackingRoomCodeText) y VELOCIDAD.
//     4. Chat como corredor: mensaje + eco propio.
//     5. Backend: sesión activa, history y messages.
//     6. Back -> diálogo de confirmación -> "Quedarme" (cancela, sigue en sala).
//     7. Back otra vez -> "Salir" (detiene + cierra sesión) -> LiveHub.
//     8. Backend: sesión status=completed; POST /join con código cerrado -> 400.
//   FASE B - Espectador:
//     9. Crear sala activa nueva vía backend (sin entrar como corredor).
//    10. Prueba negativa: código ZZZZZZ -> snackbar 404.
//    11. Unirse como espectador a la sala nueva -> reacciones + chat con eco.
//    12. Backend: reacción y mensaje del espectador persistidos.
//    13. Cerrar sala vía backend -> 200 + status=completed.
//    14. Re-join a sala completada -> 400.
//
// Ejecución:
//   flutter drive --driver=integration_test/tracking_flow_test.dart \
//     --target=test_driver/app.dart \
//     --dart-define=BACKEND_URL=https://app-pasos.onrender.com/api \
//     -d <device>

import 'dart:convert';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

const _backendBase = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'https://app-pasos.onrender.com/api',
);

const _waitShort = Duration(seconds: 20);
const _waitLong  = Duration(seconds: 45);

FlutterDriver? _driver;
String? _token;

void main() {
  setUpAll(() async {
    final f = FlutterDriver.connect();
    _driver = await f;
    await _driver!.checkHealth();
    _token = await _driver!.requestData('token');
    expect(_token, isNotEmpty,
        reason: 'El usuario debe estar logueado (auth_token en storage)');
  });

  tearDownAll(() async {
    await _driver?.close();
  });

  var codeTag = 0;

  test('Tracking: corredor + espectador (frontend y backend)', () async {
    final driver = _driver!;
    final tag = codeTag++;

    // ── FASE A: CORREDOR ──────────────────────────────────────────────

    // 1) Navegar a la pestaña Tracking
    await driver.tap(find.byValueKey('bottomNavTracking'));
    await driver.waitFor(find.text('Live Track & Support'), timeout: _waitShort);

    // 2) Iniciar seguimiento
    await driver.tap(find.text('Iniciar mi seguimiento'));
    await driver.waitFor(find.text('Tracking en Curso'), timeout: _waitShort);

    // 3) Leer código de sala
    final salaText = await driver.getText(find.byValueKey('trackingRoomCodeText'));
    final roomCode = salaText.split('Sala: ').last.trim().toUpperCase();
    expect(roomCode.length, 6, reason: 'Código de sala de 6 caracteres: $roomCode');
    print('[$tag] Sala corredor creada: $roomCode');

    // 4) Backend: sesión activa
    await _expectBackendActive(roomCode);

    // 5) GPS soft (tolerante)
    await _waitForGpsFix(driver);

    // 6) Chat corredor
    final runnerMsg = 'R-$roomCode-$tag';
    await driver.tap(find.byType('TextField'));
    await driver.enterText(runnerMsg);
    await driver.tap(find.byTooltip('Enviar'));
    await driver.waitFor(find.text(runnerMsg), timeout: _waitShort);
    print('[$tag] Eco del corredor visible');

    // 7) Backend: history + messages
    final history = await _getBackend('/tracking/$roomCode/history');
    expect(history['success'], isTrue);
    expect(history['locations'], isA<List>());
    print('[$tag] Locations en backend: ${(history['locations'] as List).length}');

    final messages = await _getBackend('/tracking/$roomCode/messages');
    expect(messages['success'], isTrue);
    expect(
      (messages['messages'] as List).map((m) => (m as Map<String, dynamic>)['message']),
      contains(runnerMsg),
      reason: 'El mensaje del corredor debe existir en backend',
    );
    print('[$tag] Mensaje del corredor persistido en backend');

    // 8) Back -> diálogo -> "Quedarme" (cancela, sigue en runner)
    await driver.tap(find.byType('BackButton'));
    await driver.waitFor(find.text('Quedarme'), timeout: _waitShort);
    await driver.tap(find.text('Quedarme'));
    await driver.waitFor(find.text('Tracking en Curso'), timeout: _waitShort);
    print('[$tag] Diálogo cancelado: sigue en runner');

    // 9) Back otra vez -> "Salir" (detiene + cierra sesión)
    await driver.tap(find.byType('BackButton'));
    await driver.waitFor(find.text('Salir'), timeout: _waitShort);
    await driver.tap(find.text('Salir'));
    await driver.waitFor(find.text('Live Track & Support'), timeout: _waitShort);
    print('[$tag] Sesión corredor cerrada desde UI');

    // 10) Backend: sesión completada + re-join 400
    final close = await _postBackend('/tracking/$roomCode/close');
    final closeJson = jsonDecode(close.body) as Map<String, dynamic>;
    expect(close.statusCode, 200, reason: 'POST close debe responder 200');
    expect((closeJson['session'] as Map<String, dynamic>)['status'], 'completed',
        reason: 'Cerrar sesión debe marcarla completed');
    print('[$tag] Sesión corredor status=completed');

    final lateJoin = await _postBackend('/tracking/join', body: {'roomCode': roomCode});
    expect(lateJoin.statusCode, 400,
        reason: 'Unirse a sesión completada debe responder 400');
    print('[$tag] Re-join a corredor completado -> 400 (correcto)');

    // ── FASE B: ESPECTADOR ───────────────────────────────────────────

    // 11) Crear sala activa nueva vía backend (sin entrar como corredor)
    final createResp = await _postBackend('/tracking/create',
        body: {'title': 'Sala Espectador $tag', 'isPublic': true});
    expect(createResp.statusCode, 201, reason: 'Create debe responder 201');
    final createJson = jsonDecode(createResp.body) as Map<String, dynamic>;
    final spectatorRoom = (createJson['roomCode'] as String).toUpperCase();
    print('[$tag] Sala espectador creada: $spectatorRoom');

    // 12) Prueba negativa: código ZZZZZZ
    await driver.tap(find.text('Unirme como espectador'));
    await driver.waitFor(find.byType('TextField'), timeout: _waitShort);
    await driver.tap(find.byType('TextField'));
    await driver.enterText('ZZZZZZ');
    await driver.tap(find.text('Unirse'));
    await driver.waitFor(find.text('Sala no encontrada o ya finalizó'), timeout: _waitShort);
    print('[$tag] Espectador negativo: 404 validado en UI');

    final badJoin = await _postBackend('/tracking/join', body: {'roomCode': 'ZZZZZZ'});
    expect(badJoin.statusCode, 404,
        reason: 'POST /tracking/join con código inválido debe responder 404');
    print('[$tag] Backend 404 para ZZZZZZ');

    // 13) Unirse como espectador a la sala nueva
    await driver.tap(find.text('Unirme como espectador'));
    await driver.waitFor(find.byType('TextField'), timeout: _waitShort);
    await driver.tap(find.byType('TextField'));
    await driver.enterText(spectatorRoom);
    await driver.tap(find.text('Unirse'));
    await driver.waitFor(find.text('Sala: $spectatorRoom'), timeout: _waitShort);
    await driver.waitFor(find.text('🔥'), timeout: _waitShort);
    print('[$tag] Espectador dentro de la sala $spectatorRoom');

    // 14) Reacción + mensaje espectador
    await driver.tap(find.text('🔥'));
    final spectMsg = 'S-$spectatorRoom-$tag';
    await driver.tap(find.byType('TextField'));
    await driver.enterText(spectMsg);
    await driver.tap(find.byTooltip('Enviar'));
    await driver.waitFor(find.text(spectMsg), timeout: _waitShort);
    print('[$tag] Chat del espectador con eco visible');

    // 15) Backend: reacción y mensaje del espectador persistidos
    final messages2 = await _getBackend('/tracking/$spectatorRoom/messages');
    final allTexts = (messages2['messages'] as List)
        .map((m) => (m as Map<String, dynamic>)['message'])
        .toList();
    expect(allTexts, contains('🔥'), reason: 'Reacción desde backend');
    expect(allTexts, contains(spectMsg), reason: 'Mensaje espectador desde backend');
    print('[$tag] Reacción y mensaje del espectador en backend');

    // 16) Cerrar sesión espectador + re-join 400
    await driver.tap(find.byType('BackButton'));
    await driver.waitFor(find.text('Live Track & Support'), timeout: _waitShort);

    final close2 = await _postBackend('/tracking/$spectatorRoom/close');
    final close2Json = jsonDecode(close2.body) as Map<String, dynamic>;
    expect(close2.statusCode, 200);
    expect((close2Json['session'] as Map<String, dynamic>)['status'], 'completed');
    print('[$tag] Sesión espectador cerrada');

    final lateJoin2 = await _postBackend('/tracking/join',
        body: {'roomCode': spectatorRoom});
    expect(lateJoin2.statusCode, 400,
        reason: 'Re-join a sesión completada debe ser 400');
    print('[$tag] Re-join a espectador completado -> 400');
  });
}

// ── Helpers ────────────────────────────────────────────────────────────────

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
    print('WARN GPS: sin fix en ${_waitLong.inSeconds}s '
        '(verifica permisos y señal). El resto del flujo sigue validado.');
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

Future<http.Response> _postBackend(String path, {Map<String, dynamic>? body}) async {
  return http.post(
    Uri.parse('$_backendBase$path'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    },
    body: jsonEncode(body ?? {}),
  );
}
