# App Pasos

Flutter app + Node.js backend para competencias de pasos entre amigos + gimnasio con rutinas y temporizador.

## Estructura

```
app_pasos/       → Flutter app (Android, iOS, Web, Windows, Linux, macOS)
backend/         → Node.js/Express API + MongoDB
docs/            → Documentación para el agente (ARCHITECTURE, NAVIGATION, GYM_MODULE, XP_LEVELS, THEME, GAME, LEAGUES)
```

## Navegación Principal

BottomNavigationBar con 5 tabs (IndexedStack, todos vivos en memoria):
- **Pasos** 🏃 — HomeScreen: contador de pasos, retos activos/finalizados, crear/unirse a retos
- **Gimnasio** 💪 — GymScreen: racha semanal, rutinas, ejercicios, flujo 3-pasos nueva rutina
- **Tracking** 📡 — LiveHubScreen: carreras en vivo con Socket.IO (corredor comparte GPS en tiempo real, espectadores se unen con código de 6 chars, chat con reacciones + TTS). Km persistidos en backend (`finalizeSession` calcula totalDistance/avgSpeed/maxSpeed/avgPace al cerrar; cierre determinista vía `POST /tracking/:roomCode/close` con fallback al timer de 30s). Al salir, el corredor ve resumen con km/tiempo/ritmo + compartir. Sección "Mis carreras" en el hub (`GET /tracking/sessions`). Espectador ve mapa OSM en vivo (flutter_map) con polyline del recorrido + banner si la sesión ya finalizó. **Wakelock_plus activo durante el tracking del corredor** (si no, Android pausaría el GPS con la pantalla apagada/bolsillo y los km dejarían de contar). El espectador carga el historial con `?recent=true` para ver el tramo actual en carreras largas. **Ánimo en vivo**: los espectadores mandan power-ups (🔥💧👏🏁⚡💪 + ánimo de voz) que el corredor escucha por TTS en cola y ve como ráfaga animada; contador "energía del público" y recap al final (ver abajo y `docs/LIVE_CHEERS.md`)
- **Chat** 🤖 — ChatScreen: Coach IA con Gemini (Google AI), chat funcional con memoria persistente y RAG sobre ejercicios
- **Explorar** 🧭 — MenuScreen: hub con header de nivel/XP y grid animado: Sprint (juego, ver docs/GAME.md), Rutas y portadas, Estadísticas, Perfil, Retos (va a tab Pasos), Carrera en vivo (va a tab Tracking), Ajustes (bottom sheet con cerrar sesión)

Barra inferior: `NavigationBar` M3 con fundido entre tabs (FadeTransition sobre el IndexedStack, conserva estado). Tracking: los errores transitorios del socket van a `TrackingProvider.notice` → SnackBar vía `TrackingNoticeListener` (nunca reemplazan mapa/chat); banner "Reconectando…" con el evento interno `connection`. Al terminar una carrera, el resumen ofrece "Crear portada" (`CoverEditorScreen.forRun`).

## Comandos

```bash
# Backend
cd backend && npm run dev              # Iniciar servidor (puerto 3000)
cd backend && npm run seed             # Poblar DB con usuarios + 27 ejercicios predefinidos
cd backend && npm run sync-exercises   # Sincronizar 1327+ ejercicios desde WorkoutX API (manual)
cd backend && npm run dedup-exercises  # Eliminar ejercicios duplicados y actualizar referencias

# Flutter (Android - dispositivo físico)
cd app_pasos
flutter run --dart-define=BACKEND_URL=http://192.168.18.15:3000/api

# Flutter (Android - emulador)
flutter run --dart-define=BACKEND_URL=http://10.0.2.2:3000/api

# Build APK para compartir (con Render)
flutter build apk --dart-define=BACKEND_URL=https://app-pasos.onrender.com/api

# Verificar código
flutter analyze
```

## Funcionalidades

### Sistema de Pasos y Retos
- Registrar pasos diarios en retos contra amigos
- Challenges con código de invitación (6 chars)
- Calendario mensual de pasos
- Estadísticas semanales/mensuales con gráfica de barras

### Sistema de XP y Niveles
- 1 XP por cada 10 pasos registrados
- Nivel 0→1: 1,000 XP. Fórmula: XP_total(L) = 1000 × L × (L+1) / 2
- Recompensas cada 10 niveles: título + avatar (Caminante, Maratonista, Ultramaratonista, Leyenda, Titán)
- Vista de progreso y recompensas en el perfil

### Economía de pasos (monedero)
- Los pasos registrados son moneda: saldo = pasos ganados (máx. por día entre retos, nunca baja) − gastos ± apuestas
- Tienda (`/api/wallet`): skins y estelas del Sprint, 5 portadas premium de Share Aura (Revista/Minimal/Polaroid gratis), packs de stickers
- Retos con apuesta: ambos apuestan N pasos, el ganador se lleva 2N; empate/borrado → reembolso. Escudo en el Sprint con ≥ 8.000 pasos hoy
- Flutter: `WalletProvider` (cada pantalla llama `ensureWalletLoaded(context)` en post-frame), `WalletScreen()` en `lib/screens/wallet/wallet_screen.dart`. Detalle: `docs/WALLET.md`

### Módulo Gimnasio
- **Librería de ejercicios**: 1,327+ ejercicios desde WorkoutX API con GIFs animados y nombres/descripciones en español, en 4 categorías (calentamiento, fuerza, cardio, flexibilidad) + 322 ejercicios predefinidos en español del seed
- **Rutinas**: flujo de 3 pasos para crear rutinas — (1) seleccionar ejercicios en `ExerciseLibraryScreen`, (2) configurar nombre/series/reps/descanso global en `RoutineConfigScreen`, (3) confirmar y guardar en `RoutineConfirmScreen`. Editar rutinas existentes con `RoutineBuilderScreen`.
- **Workout**: ejecutar rutinas paso a paso con temporizador real basado en DateTime.now() (preciso incluso con celular bloqueado)
- **Racha semanal**: seguimiento de semanas consecutivas entrenando (limitado a 52 workouts)
- **Wakelock**: pantalla encendida durante el workout
- **Alarma**: sonido al terminar cada timer

### Módulo Chat / Coach IA
- **Coach IA**: chatbot con Gemini (Google AI) integrado vía backend Express
- **RAG**: recupera ejercicios relevantes de MongoDB + datos del usuario (nivel, racha, rutinas, PRs) como contexto en cada mensaje
- **Memoria persistente**: conversaciones guardadas en MongoDB (`ChatConversation`), se retoman al abrir la app
- **System prompt**: el coach solo recomienda ejercicios que existen en la base de datos, personaliza según nivel y progreso del usuario
- **Búsqueda inteligente**: detecta categorías (fuerza/cardio/etc.) y grupos musculares del mensaje del usuario

### Sistema de Logros de Peso
- Logros automáticos al levantar 25/50/75/100/150/200 kg en un ejercicio
- Vista en perfil con progreso hacia el siguiente logro

## Backend Rutas

| Ruta | Métodos |
|---|---|
| `/api/auth` | POST register, POST login, GET/PUT profile |
| `/api/challenges` | POST create (opcional `wager` en pasos), POST join (apuesta lo mismo), GET list/detail (liquidan apuestas de retos terminados), POST leave, DELETE (reembolsan) — ver `docs/WALLET.md` |
| `/api/steps` | POST save, GET list/calendar, GET analytics |
| `/api/xp` | GET xp+level+progress, GET rewards, POST claim, GET weight-rewards |
| `/api/gym` | GET exercises, CRUD routines, POST workouts, GET streak, GET/POST personal-records |
| `/api/chat` | POST send message, GET history, DELETE history |
| `/api/tracking` | POST create (crea sala con código), POST join (valida sala), GET sessions (historial del usuario), GET/:roomCode, POST/:roomCode/close, GET/:roomCode/history, GET/:roomCode/messages, GET/:roomCode/cheers (recap de ánimos) |
| `/api/wallet` | GET saldo + movimientos + inventario + equipado, GET catalog (tienda), POST purchase `{itemId}`, GET inventory, POST equip `{slot, itemId}` — economía de pasos, ver `docs/WALLET.md` |
| `/api/game` | GET fuel (intentos por pasos de hoy + `shield` si ≥ 8.000 pasos hoy), POST play (guarda partida, XP si nivel ≥ 5), GET leaderboard (mejor por usuario + `me`), GET multiplier-status — ver `docs/GAME.md` |
| `/api/leagues` | GET current (mi grupo semanal: standings, zonas, puntos, tiempo restante, `pendingResult`), GET history, POST ack-result — ligas semanales America/Lima, unión/cierre perezosos, ver `docs/LEAGUES.md` |

**Tracking en vivo**: usa Socket.IO (no WebSocket crudo). El frontend conecta con `socket_io_client` enviando `auth.token` + query `roomCode`/`isRunner`. Eventos: `locationUpdate`, `chatMessage`, `powerUp`, `trackingStopped`, `userJoined/Left`.

**Ánimo en vivo (power-ups)**: espectadores (invitados incluidos, también desde `public/track.html`) emiten `powerUp {type, text?}` — tipos `turbo 🔥, agua 💧, aplausos 👏, ultimoKm 🏁, ritmo ⚡, fuerza 💪, voz 🎙️` (texto ≤80 chars). Server valida tipo, rate limit 1/5 s por socket (`error` con `code: 'POWERUP_COOLDOWN'`, `retryInMs`), persiste en `LiveMessage` (`kind: 'powerUp'`, `powerUpType`) y emite a la sala con `speech` (texto TTS) + `stats` (total, fans, top supporter). Corredor: TTS en cola (`TtsService.enqueue`) + overlay animado (`PowerUpBurstOverlay`). Espectador: `PowerUpBar` con anillo de cooldown + háptica. `POST /close` incluye `cheers` (recap) y `GET /sessions` incluye `cheersCount`. Catálogo en `backend/utils/powerUps.js` ↔ `lib/models/power_up.dart` (mantener sincronizados). Detalle: `docs/LIVE_CHEERS.md`.

## Índices MongoDB

| Colección | Índice | Query que optimiza |
|---|---|---|
| Challenge | `{ creator: 1, status: 1 }` + `{ opponent: 1, status: 1 }` | Listar retos del usuario por status |
| Exercise | `{ category: 1, name: 1 }` + text index en `name`/`nameSpanish` | Filtrar y buscar ejercicios |
| Workout | `{ user: 1, date: -1 }` | Cálculo de racha semanal + listar workouts |
| Routine | `{ user: 1, createdAt: -1 }` | Listar rutinas del usuario |
| StepEntry | `{ challenge: 1, date: 1 }` | Calendario y analytics de retos |
| ChatConversation | `{ user: 1 }` (unique) | Obtener/conversación del usuario |
| Wallet | `{ user: 1 }` (unique) | Monedero de pasos (saldo atómico + diario `ops`) |
| WalletTransaction | `{ user: 1, key: 1 }` (unique) + `{ user: 1, createdAt: -1 }` | Idempotencia del ledger + historial |
| DailyStepCredit | `{ user: 1, day: 1 }` (unique) | Pasos acreditados por día (sin doble conteo) |
| LiveMessage | `{ roomCode: 1, timestamp: 1 }` + `{ roomCode: 1, kind: 1 }` | Chat de la sala + stats/recap de ánimos |
| LeagueGroup | `{ week: 1, division: 1, seq: 1 }` (unique) | Buscar grupo con cupo / crear el siguiente sin duplicar |
| LeagueMembership | `{ user: 1, week: 1 }` (unique) + `{ user: 1, weekStart: -1 }` + `{ group: 1 }` | Membresía semanal, semana anterior, miembros del grupo |

## Performance

### Flutter
- **Health check**: no bloquea startup (fire-and-forget con timeout 5s en `splash_screen.dart`)
- **Búsqueda de ejercicios**: debounce de 300ms antes de llamar API
- **Exercise cards**: usan `Selector<GymProvider, double>` para evitar rebuilds innecesarios — solo se rebuildéa el badge de PR cuando cambia ese específico
- **Caché de ejercicios**: SharedPreferences cachea los 1,327+ ejercicios (carga instantánea en segunda visita)

### Backend
- **XP**: no se recalcula en GET (solo al guardar pasos). Elimina doble agregación por visita al perfil.
- **Streak**: limitado a 52 workouts. No carga todo el historial.
- **Challenges**: winners de challenges finalizados se obtienen con una sola aggregation (N+1 → 1). Detail de challenge usa 1 query en vez de 3.
- **Workout PR**: upserts por ejercicio, cada workout podría optimizarse a `bulkWrite` si escala.

## Seguridad

- JWT almacenado con `flutter_secure_storage` (Android Keystore)
- No hardcodear tokens ni secrets en el código
- No hay rate limiting ni compresión de respuestas aún
