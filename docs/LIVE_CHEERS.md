# Ánimo en vivo (power-ups de espectadores)

Diferenciador del tracking en vivo: los espectadores (con cuenta o invitados,
desde la app o desde el visor web `backend/public/track.html`) mandan
"power-ups" al corredor. El corredor los **escucha** (TTS con el nombre de
quien lo envía, en cola) y los **ve** (ráfaga animada + toast). Hay contador
"energía del público" en vivo y un recap al terminar la carrera.

## Catálogo

Fuente de verdad: `backend/utils/powerUps.js` (`POWER_UP_TYPES`). Espejo en
Flutter: `app_pasos/lib/models/power_up.dart` (`PowerUpType`) y en
`track.html` (`POWER_UPS`). **Mantener los tres sincronizados.**

| type | emoji | Texto hablado (TTS) |
|---|---|---|
| `turbo` | 🔥 | ¡{name} te manda TURBO! |
| `agua` | 💧 | ¡{name} dice: hidrátate! |
| `aplausos` | 👏 | ¡{name} te está aplaudiendo! |
| `ultimoKm` | 🏁 | ¡{name} dice: último kilómetro, a por todas! |
| `ritmo` | ⚡ | ¡{name} dice: sube el ritmo! |
| `fuerza` | 💪 | ¡{name} dice: tú puedes! |
| `voz` | 🎙️ | {name} dice: {texto} (texto libre, máx. 80 chars) |

El texto hablado lo genera el **servidor** (`speech` en el evento), así los
clientes no duplican la lógica de frases.

## Protocolo Socket.IO

Cliente → servidor (solo espectadores; el corredor recibe `error`):

```js
socket.emit('powerUp', { type: 'turbo' });
socket.emit('powerUp', { type: 'voz', text: '¡Vamos que ya llegas!' });
// Invitados web pueden mandar senderName (igual que en chatMessage)
```

Validaciones del servidor (`server.js`, handler `powerUp`):

1. `type` debe existir en el catálogo → si no, `error {code: 'POWERUP_INVALID'}`.
2. `voz` requiere texto; se colapsan espacios/saltos y se recorta a 80.
3. **Rate limit server-side por socket: 1 power-up cada 5 s**
   (`POWER_UP_COOLDOWN_MS`). Rechazo → `error {code: 'POWERUP_COOLDOWN',
   retryInMs, message}`. Los inválidos no consumen el cooldown.
4. La sesión debe estar `active`.

Servidor → sala (`io.to(room)`, incluido el emisor):

```json
{
  "type": "turbo", "emoji": "🔥",
  "message": "🔥 ¡Ana te manda TURBO!",
  "speech": "¡Ana te manda TURBO!",
  "text": null,
  "senderId": "…|null", "senderName": "Ana", "senderType": "spectator",
  "timestamp": "ISO",
  "stats": { "total": 12, "supporters": 4, "topSupporter": { "name": "Ana", "count": 5 } }
}
```

## Persistencia

`LiveMessage` gana dos campos (compatibles hacia atrás):

- `kind: 'chat' | 'powerUp'` (default `'chat'`; docs antiguos sin `kind` = chat)
- `powerUpType: String | null`

`message` guarda el texto mostrado (con emoji). Índice nuevo
`{ roomCode: 1, kind: 1 }` para stats/recap. `GET /tracking/:code/messages`
devuelve ambos tipos (los clientes pintan los power-ups distinto).

Supporters: usuarios registrados se agrupan por `sender` (_id); invitados por
`senderName`.

## REST

- `GET /api/tracking/:roomCode/cheers` — mismas reglas de privacidad que
  `/messages`. Respuesta:
  ```json
  { "success": true, "cheers": {
      "total": 23, "supporters": 5,
      "byType": { "turbo": 9, "agua": 2, "aplausos": 6, "ultimoKm": 1, "ritmo": 3, "fuerza": 1, "voz": 1 },
      "topSupporters": [{ "name": "Ana", "count": 8 }],
      "samples": [{ "senderName": "Bob", "text": "¡Vamos!", "timestamp": "ISO" }]
  } }
  ```
- `POST /api/tracking/:roomCode/close` — la respuesta incluye `cheers` (mismo
  objeto; `null` si falló el cálculo, no bloquea el cierre).
- `GET /api/tracking/sessions` — cada sesión trae `cheersCount` (1 sola
  aggregation para todo el listado).

## Flutter

- `WebSocketService.sendPowerUp(type, {text})` + evento `powerUp` en el stream.
- `TrackingProvider`:
  - `sendPowerUp(PowerUpType, {text})` (solo rol espectador; cooldown local
    espejo del servidor en `powerUpCooldownUntil`, se re-sincroniza con
    `retryInMs` si el servidor rechaza).
  - `powerUpEvents` (stream broadcast para animaciones), `cheersTotal`,
    `cheersSupporters`, `topSupporter`. Las stats se cargan de `/cheers` al
    unirse / reconectar / volver a la app.
  - Corredor: cada `powerUp` se encola en `TtsService.enqueue(speech)`.
- `TtsService`: cola FIFO (máx. 6 pendientes, descarta las más viejas) con
  `awaitSpeakCompletion(true)` para que los ánimos no se corten entre sí. Los
  emojis 🔥💪⚡👏 enviados como **chat** (clientes viejos) siguen hablándose,
  ahora también por la cola.
- Widgets:
  - `lib/widgets/power_up_burst_overlay.dart` — `PowerUpBurstOverlay`
    (corredor): emoji que sube con brillo + partículas + toast con el nombre,
    háptica media, máx. 4 ráfagas simultáneas, `IgnorePointer`.
  - `lib/widgets/power_up_bar.dart` — `PowerUpBar` (espectador; anillo de
    cooldown con `CustomPainter`, háptica fuerte al enviar, diálogo de voz) y
    `CrowdEnergyChip` (energía del público, usado en ambas pantallas).
- Resumen de fin de carrera (`tracking_runner_screen.dart`): bloque
  `_CheersRecap` (conteo por tipo, top 3 supporters, ánimos de voz). El botón
  "Crear portada" pasa `title: '🔥 23 ánimos de 5 amigos'` cuando hay ánimos.
- "Mis carreras" (`live_hub_screen.dart`) muestra `🔥 N ánimos`.

## Web (`track.html`)

Barra de power-ups con anillo de cooldown (CSS `conic-gradient`), `prompt()`
para el ánimo de voz, `navigator.vibrate`, ráfaga de emoji al recibir un
`powerUp` y línea de "energía del público".

## Limitaciones conocidas

- El rate limit es por socket: reconectar reinicia el cooldown (aceptable;
  un abuso real requeriría limitar por usuario/IP).
- Clientes viejos del corredor no escuchan el evento `powerUp` (solo chat).
- Las stats en vivo se recalculan con una aggregation por power-up (como
  máx. 1 cada 5 s por espectador); si escala, cachear en memoria por sala.

## Test

E2E (backend real + mongodb-memory-server + socket.io-client): broadcast,
rate limit, invitado, validaciones, persistencia, `/cheers`, `/close`,
`/sessions`. Widget tests: `app_pasos/test/power_up_widgets_test.dart`.
