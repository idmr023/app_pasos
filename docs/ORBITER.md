# ORBITER — Juego de Nave con Fusión de Fitness

Juego 2D de naves espaciales con control de voz, integrado al sistema de pasos y XP de la app.

## Mecánica principal

### Combustible (Fuel System)
- Cada **2,000 pasos** registrados = **1 intento** para jugar
- Máximo **5 intentos por día** (para evitar abuso)
- La barra de combustible se muestra en el HomeScreen debajo del contador de pasos
- Al perder una partida se descuenta 1 intento; para jugar de nuevo hay que seguir caminando

### Niveles del juego
| Nivel | Requisito | Velocidad | Intervalo asteroides |
|---|---|---|---|
| 1 | Inicio | 100 | 2.0s |
| 2 | 5 esquivados | 160 | 1.4s |
| 3 | 12 esquivados | 220 | 1.0s |

### XP Multiplier
- Al alcanzar **nivel 5+** en una partida, se activa **bonus x1.5 al XP** hasta medianoche
- El XP adicional se calcula como: `floor(score/10) * 1.5`
- El multiplier es verificable vía `GET /api/game/multiplier-status`
- Se resetea automáticamente al día siguiente

### Leaderboard
- Top 20 scores globales, ordenados por puntuación descendente
- Muestra: posición, username, avatar, nivel alcanzado, score
- Accesible desde el botón de trofeo en la barra de fuel del HomeScreen

## Control

### Voz (principal)
- `speech_to_text` escucha continuamente en español (`es_ES`)
- Comandos: "izquierda"/"izq"/"left" → mover izquierda, "derecha"/"der"/"right" → mover derecha
- La nave se mueve con aceleración durante ~400ms y luego se detiene automáticamente
- Si el reconocimiento falla, reintenta automáticamente después de 1 segundo

### Táctil (fallback)
- Tap izquierdo de la pantalla = mover izquierda
- Tap derecho = mover derecha
- La nave se mueve mientras se mantiene presionado y se detiene al soltar

## Arquitectura técnica

### Backend
- **Modelo**: `backend/models/GameScore.js` — user, level, asteroidsDodged, score, createdAt
- **Rutas**: `backend/routes/game.js` — 4 endpoints (fuel, play, leaderboard, multiplier-status)
- **Constantes**: `STEPS_PER_ATTEMPT=2000`, `MAX_ATTEMPTS_PER_DAY=5`, `MULTIPLIER_LEVEL=5`

### Flutter ( Flame Engine )
- **Game**: `lib/games/orbiter/orbiter_game.dart` — `FlameGame` con colisiones AABB, spawner de asteroides, sistema de niveles
- **Ship**: `lib/games/orbiter/ship.dart` — nave con gradiente, rendering programático (sin sprites PNG)
- **Asteroid**: `lib/games/orbiter/asteroid.dart` — polígono irregular con glow, nivel 1= naranja, nivel 2+= rojo
- **Stars**: `lib/games/orbiter/star_particle.dart` — partículas de fondo con movimiento parallax suave
- **Voice**: `lib/games/orbiter/voice_controller.dart` — wrapper de `speech_to_text`
- **HUD**: `lib/games/orbiter/hud.dart` — nivel, esquivados, score, intentos restantes
- **GameOver**: `lib/games/orbiter/game_over_overlay.dart` — score final, multiplier status, XP ganados

### UI
- **HomeScreen** (`lib/screens/home_screen.dart`): barra de fuel con indicador de intentos, barra de progreso, botón "JUGAR"
- **OrbiterScreen** (`lib/screens/games/orbiter_screen.dart`): GameWidget de Flame + controles táctiles + HUD overlay
- **LeaderboardScreen** (`lib/screens/games/leaderboard_screen.dart`): top 20 con posiciones, trofeos por top 3

### Provider
- `lib/providers/game_provider.dart` — attempts, usedToday, stepsUntilNext, hasMultiplier, leaderboard
- `lib/services/game_service.dart` — HTTP client para `/api/game/*`

## Assets
- Rendering programático: nave (gradiente cyan→púrpura), asteroide (polígono irregular con glow), estrellas (dots with blur)
- No se necesitan sprites PNG para que el juego funcione
- Para mejorar visuals: reemplazar `render()` en ship.dart/asteroid.dart con `SpriteComponent` y assets PNG

## Flujo del usuario
1. **HomeScreen** → ve barra de fuel con intentos disponibles
2. **Toca "JUGAR"** → se abre `OrbiterScreen` en pantalla completa
3. **Juega** → control por voz o tacto, esquivar asteroides
4. **Pierde** → game over overlay muestra score, nivel, multiplier
5. **Si alcanzó nivel 5+** → se activa x1.5 XP para el resto del día
6. **Vuelve al home** → fuel actualizado, puede jugar de nuevo si tiene intentos

## Por implementar
- Assets PNG de alta calidad (nave, asteroides, fondos)
- Sonidos del juego (colisión, esquivar, power-up, música de fondo)
- Modo "endless" con dificultad progresiva infinita
- Power-ups (escudo temporal, doble velocidad, magnet de puntos)
- Retos "Nave vs Nave" entre amigos (quién alcanza nivel más alto)
