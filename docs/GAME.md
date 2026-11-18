# SPRINT — Minijuego deportivo ganado con pasos

Sustituye al diseño de `ORBITER.md` (nave + control por voz con Flame). Lo que se construyó es un
runner de atletismo en **Flutter puro** (CustomPainter + Ticker), sin dependencias nuevas.

## Idea

Un corredor (visto de espaldas) avanza por una pista de atletismo de **3 carriles** en un estadio
nocturno. Hay que **esquivar** vallas, conos y rivales y **recoger** monedas y bebidas energéticas.
Cada 350 m se sube de nivel y la velocidad aumenta. Inspirado en `legacy-phaser-game/` (esquivar
objetos que caen, niveles que aceleran), re-tematizado como deporte.

## Reglas

| Elemento | Comportamiento |
|---|---|
| Valla | Se puede **saltar** (deslizar ↑). Saltarla: +15 × multiplicador |
| Cono / rival | No se puede saltar: hay que cambiar de carril |
| Obstáculo esquivado | +5 × multiplicador |
| Moneda | +10 × multiplicador; suma combo |
| Bebida energética | **TURBO** 4.5 s: puntos x2, +25 % velocidad y arrasa obstáculos (+20 × mult.) |
| Distancia | +1 punto por metro |

- **Combo**: cada moneda reinicia una ventana de 2.4 s; si expira, el combo vuelve a 0.
  Multiplicador = `1 + combo ~/ 5` (máx. x5), ×2 durante turbo.
- **Niveles**: nivel = `1 + distancia ~/ 350`. Velocidad base 16 m/s, +2.4 m/s por nivel (tope 44 m/s).
  Desde nivel 2 aparecen rivales; desde nivel 3 puede haber 2 carriles bloqueados por fila
  (nunca los 3). El intervalo entre filas baja de 1.25 s a 0.6 s.
- Un choque sin turbo termina la carrera, salvo que quede **escudo**: con ≥ 8.000 pasos hoy las carreras
  oficiales empiezan con 1 escudo (`SprintGame.shields`, `shield` en `GET /fuel`), que perdona un choque.
- El corredor se pinta con la equipación/estela equipada en la tienda de pasos
  (`SprintPainter(game, skin:, trail:)`, `sprint_cosmetics.dart`). Ver `docs/WALLET.md`.

## Controles

- Tocar mitad izquierda/derecha de la pantalla o deslizar ←/→: cambiar de carril.
- Deslizar ↑: saltar. Deslizar ↓ en el aire: caer más rápido.
- Teclado (web/escritorio): flechas o A/D/W/S, espacio = saltar, Esc/P = pausa.
- Botón de pausa; la partida también se pausa sola si la app pasa a segundo plano.
- Hápticos: clic al cambiar de carril, toque leve en monedas, medio en turbo/nivel/récord, fuerte al chocar.
- Wakelock activo durante la partida (solo si nadie más lo tenía activo, p. ej. el tracking en vivo).

## Intentos (combustible) y modos

- Cada **2.000 pasos** registrados **hoy** en los retos = 1 intento, máx. **5 al día**
  (`GET /api/game/fuel`). Los pasos salen de `StepEntry` (suma de todos los retos del día).
- **Carrera oficial**: consume un intento al terminar; la puntuación se envía a `POST /api/game/play`.
  Si el jugador abandona a mitad (atrás/pausa → Abandonar) se le pide confirmación y la puntuación
  actual **se guarda igualmente** (evita salir para no gastar el intento). Abandonar durante la
  cuenta atrás no consume intento.
- **Práctica libre**: siempre disponible, no llama al backend ni consume intentos.

## XP y multiplicador

- Solo las carreras oficiales que llegan a **nivel ≥ 5** dan XP: `floor(score/10)` + 50 % de bonus,
  con tope de **500 XP por carrera**.
- El XP del juego se acumula en `User.gameXp` (nuevo campo, default 0) y entra en el total:
  `xp = stepsXp + gymXp + gameXp` (`services/xpService.js`, `routes/steps.js`). Antes se sumaba
  a `user.xp` directamente y se perdía en el siguiente recálculo.
- `hasMultiplier` (fuel / multiplier-status) indica que hoy ya se alcanzó el nivel 5 en alguna partida.

## Backend (`/api/game`, montado en `server.js`)

| Endpoint | Respuesta |
|---|---|
| `GET /fuel` | `attempts, usedToday, maxAttempts, stepsUntilNext, stepsToday, hasMultiplier, bestLevelToday` + (nuevo) `bestScore, stepsPerAttempt, maxAttemptsPerDay, multiplierLevel, multiplierValue` |
| `POST /play` | Body: `level, score, obstaclesDodged` (o `asteroidsDodged`, compatibilidad Orbiter) + opcionales `distance, coins, maxCombo, durationMs, game`. Valida enteros ≥ 0, `1 ≤ level ≤ 200`, `score ≤ 1.000.000`. 403 si no quedan intentos. Devuelve `gameScore, xpAwarded, hasMultiplier, isNewBest, bestScore, user{xp,level,title}|null, fuel{attempts,usedToday,maxAttempts}` |
| `GET /leaderboard` | Top 20 con la **mejor puntuación de cada usuario**: `rank, userId, username, avatar, score, level, asteroidsDodged, distance, createdAt, isMe` + `me{bestScore, rank}` |
| `GET /multiplier-status` | `hasMultiplier, bestLevelToday, multiplierValue, multiplierLevel` |

Modelo `GameScore`: `user, game ('sprint'), level, asteroidsDodged, score, distance, coins, maxCombo,
durationMs, xpAwarded, createdAt`. Los campos nuevos son opcionales (las partidas antiguas siguen siendo válidas).

## Flutter

```
lib/games/sprint/sprint_game.dart      → lógica pura (ChangeNotifier): entidades, spawner, colisiones, combo, niveles, partículas
lib/games/sprint/sprint_painter.dart   → CustomPainter con proyección en perspectiva (estadio, gradas, pista, vallas, conos, corredores, monedas, latas, partículas, textos)
lib/services/game_service.dart         → HTTP /api/game
lib/providers/game_provider.dart       → GameProvider (registrado en main.dart); setToken lo llama el hub
lib/screens/games/game_hub_screen.dart → GameHubScreen() — intentos, récord, ranking, multiplicador, jugar/practicar
lib/screens/games/sprint_play_screen.dart     → SprintPlayScreen(official: bool) — Ticker + HUD + pausa + game over
lib/screens/games/game_leaderboard_screen.dart → GameLeaderboardScreen() — ranking completo
```

- **Bucle**: `Ticker` (createTicker) → `dt` real por frame (limitado a 50 ms) → `SprintGame.update(dt)`.
  Todo el movimiento está escalado por `dt`. El painter se repinta escuchando al juego (`repaint:`),
  el HUD usa `AnimatedBuilder`; la pantalla no hace `setState` por frame. El ticker se detiene en pausa
  y 1.6 s después del game over.
- **Render**: proyección `p(z) = 8 / (8 + z)`; parallax con franjas de césped y marcas de pista que se
  desplazan con la distancia, vallas publicitarias laterales, gradas con público animado, torres de luz,
  ligera cámara lateral que sigue al jugador, líneas de velocidad, temblor de cámara al chocar.
- El hub muestra una portada renderizada con `SprintGame.preview()` (simulación de 2.5 s con piloto automático, sin ticker).
- La navegación al hub la cablea quien integre (`main_shell`/`menu_screen` no se tocaron):
  `import 'screens/games/game_hub_screen.dart';` → `const GameHubScreen()`.
