# Ligas semanales

Competencia semanal estilo Duolingo para retención diaria. Los usuarios se agrupan en ligas de hasta 20 personas de la misma división; al cerrar la semana los mejores suben y los últimos bajan.

## Archivos

| Capa | Archivo |
|---|---|
| Modelo | `backend/models/LeagueGroup.js` — `{ week, division, seq, members[], finalized, finalizedAt }` |
| Modelo | `backend/models/LeagueMembership.js` — `{ user, week, weekStart, division, group, joinedAt, finalPoints, finalRank, result, nextDivision, resultSeen }` |
| Lógica | `backend/services/leagueService.js` (semanas, puntos, zonas, unión y cierre perezosos) |
| Rutas | `backend/routes/leagues.js` → `/api/leagues` |
| Flutter | `lib/services/league_service.dart`, `lib/providers/league_provider.dart` |
| UI | `lib/screens/leagues/league_screen.dart` (`LeagueScreen()`), `lib/widgets/league_summary_card.dart` (`LeagueSummaryCard()`), `lib/widgets/league_division_badge.dart` |

Ambos widgets públicos no reciben argumentos y toman el token de `AuthProvider` en un post-frame callback (no dependen de `main_shell`).

## Divisiones

`0 Bronce · 1 Plata · 2 Oro · 3 Platino · 4 Diamante · 5 Leyenda`. Usuarios nuevos empiezan en Bronce.

## Semana

- Semana ISO, lunes 00:00 → lunes siguiente 00:00 en **America/Lima** (UTC-5 fijo; Perú no usa horario de verano). Clave `YYYY-Www` (año ISO, p. ej. `2026-W47`; `2027-01-01` pertenece a `2026-W53`).
- Workouts, partidas de Sprint y carreras en vivo se filtran por instante (`[weekStart, weekEnd)`); los topes "por día" usan el día de Lima (`$dateToString` con `timezone: '-05:00'`).
- **Pasos**: `routes/steps.js` guarda `StepEntry.date` como medianoche *local del servidor* (`setHours(0,0,0,0)`). Por eso la ventana de pasos usa los mismos días calendario lunes..domingo, construidos como medianoche local del servidor, para no perder el lunes cuando el servidor está en UTC.

## Puntos (solo lectura sobre datos existentes)

| Fuente | Regla | Tope |
|---|---|---|
| Pasos (`StepEntry`) | 1 pt cada 100 pasos | 30,000 pasos/día |
| Gimnasio (`Workout`) | 50 pts por entrenamiento | 2 por día |
| Sprint (`GameScore`) | 10 pts por partida | 5 por día (además del límite de intentos del juego) |
| Carreras en vivo (`TrackingSession`, `status: 'completed'`, por `endedAt`) | 20 pts por km (`floor(km × 20)`) | 50 km por carrera |

**Dedupe de pasos**: el mismo día puede estar registrado en varios retos (son los mismos pasos del podómetro, `StepEntry` es único por `user+challenge+date`). Se toma el **máximo** por `(usuario, día)`, no la suma. Luego se aplica el tope diario y se suma la semana. Puntos de pasos = `floor(pasosSemana / 100)`.

Cálculo: 4 agregaciones por grupo (todas con `user: { $in: miembros }`), usando los índices existentes `{user, challenge, date}`, `{user, date}`, `{user, createdAt}`, `{runner, status}`. Caché en memoria por grupo de 15 s (`LEAGUE_CACHE_MS`, `0` la desactiva).

## Zonas y resultado

Con `n` = tamaño del grupo:

- Ascienden: top `min(5, max(1, floor(n/4)))` — nadie asciende desde Leyenda.
- Descienden: últimos `min(5, floor(n/4))` si `n ≥ 4` — nadie desciende desde Bronce.
- Para ascender hay que tener **> 0 puntos**. Fuera de Bronce, terminar con **0 puntos** también baja (inactividad).
- Desempate: más puntos → quien se unió antes a la semana → id de usuario.
- Grupo de 20: 5 suben / 5 bajan. Grupo de 3 en Bronce: 1 sube.
- Saltarse semanas sin abrir la liga no penaliza: se usa el `nextDivision` de la última semana jugada.

## Unión perezosa (sin cron)

`GET /current` → si el usuario no tiene membresía en la semana:
1. Toma su última membresía anterior; si no está cerrada, cierra ese grupo (ver abajo).
2. Crea `LeagueMembership` (único `{user, week}`) en `nextDivision` (o Bronce).
3. Entra atómicamente a un grupo con cupo (`findOneAndUpdate` con `members.19: {$exists: false}` + `$addToSet`). Si todos están llenos crea el grupo `seq + 1`; el índice único `{week, division, seq}` hace que peticiones concurrentes no creen grupos de más (el perdedor reintenta y entra al grupo nuevo).

## Cierre perezoso e idempotente

La primera petición de un miembro en una semana nueva (o `GET /history`) congela el grupo anterior: calcula puntos/ranking y escribe `finalPoints, finalRank, result, nextDivision` con filtro `result: null` (un resultado congelado nunca se reescribe, aunque lleguen pasos tardíos de esa semana), y marca `LeagueGroup.finalized`. Grupos cuyos miembros nunca vuelven quedan sin cerrar, sin efecto.

El resultado se muestra una vez: `pendingResult` (más reciente con `resultSeen: false`) → la app muestra la celebración → `POST /ack-result`.

## API `/api/leagues` (auth)

| Ruta | Respuesta |
|---|---|
| `GET /current` | `{ week, timezone, weekStart, weekEnd, serverNow, timeRemainingMs, division, divisions[], group: {id, size, maxSize, promoteCount, demoteCount}, pointsRules, me, standings[], pendingResult }`; cada fila: `{ userId, username, displayName, avatar, level, points, rank, zone: promote|stay|demote, isMe, breakdown: {steps:{value,points}, workouts:{count,points}, games:{count,points}, runs:{km,points}, total} }` |
| `GET /history` | `{ history: [{ week, weekStart, current, division, newDivision, finalRank, finalPoints, result, groupSize }] }` (12 semanas) |
| `POST /ack-result` | body `{ week? }` (sin `week` marca todas) → `{ acknowledged }` |

## Tests

Header `x-test-now: <ISO>` reemplaza el "ahora" **solo con `NODE_ENV=test`**. E2E (backend real + mongodb-memory-server): `scratchpad/e2e/leagues_e2e.js <ruta-backend>` — semanas ISO/Lima, dedupe y topes, ranking, 23 uniones concurrentes (20 + 3), cierre y promoción/descenso en 2 semanas, idempotencia con datos tardíos, ack.
