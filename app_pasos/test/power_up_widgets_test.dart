import 'dart:async';

import 'package:app_pasos/models/power_up.dart';
import 'package:app_pasos/providers/tracking_provider.dart';
import 'package:app_pasos/widgets/power_up_bar.dart';
import 'package:app_pasos/widgets/power_up_burst_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PowerUpBurstOverlay muestra ráfaga + toast y se limpia', (
    tester,
  ) async {
    final events = StreamController<Map<String, dynamic>>.broadcast();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PowerUpBurstOverlay(
            events: events.stream,
            child: const Center(child: Text('contenido')),
          ),
        ),
      ),
    );

    events.add({
      'type': 'turbo',
      'emoji': '🔥',
      'senderName': 'Ana',
      'speech': '¡Ana te manda TURBO!',
    });
    events.add({
      'type': 'voz',
      'emoji': '🎙️',
      'senderName': 'Bob',
      'text': 'Vamos!',
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('contenido'), findsOneWidget);
    // El toast muestra el ánimo más reciente.
    expect(find.text('Bob: Vamos!'), findsOneWidget);
    expect(find.text('🎙️'), findsWidgets);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('Bob: Vamos!'), findsNothing);
    expect(find.text('contenido'), findsOneWidget);
    await events.close();
  });

  testWidgets('PowerUpBar renderiza todos los power-ups y CrowdEnergyChip', (
    tester,
  ) async {
    final provider = TrackingProvider();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const CrowdEnergyChip(
                total: 3,
                supporters: 2,
                topSupporter: {'name': 'Ana', 'count': 2},
              ),
              PowerUpBar(provider: provider),
            ],
          ),
        ),
      ),
    );
    for (final t in PowerUpType.all) {
      expect(find.byKey(ValueKey('powerUp_${t.id}')), findsOneWidget);
    }
    expect(find.text('3 ánimos · 2 fans · Top: Ana (2)'), findsOneWidget);

    // Sin sala (role null) el envío no hace nada ni lanza excepciones.
    await tester.tap(find.byKey(const ValueKey('powerUp_turbo')));
    await tester.pump();
    expect(provider.powerUpCooldownUntil, isNull);

    // El botón de voz abre el diálogo con límite de 80 caracteres.
    await tester.tap(find.byKey(const ValueKey('powerUp_voz')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('voiceCheerField')), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });
}
