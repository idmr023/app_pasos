# Módulo Entrenamiento (resistencia)

Análisis profesional de carrera (y otros deportes de resistencia) con sesiones
importadas de Strava **a elección del usuario** o registradas a mano.

Entrada: Explorar → **Entrenamiento** (`TrainingHubScreen`).

## Flujo

1. **Conectar Strava** (reutiliza el OAuth de `/api/routes/strava/*`, scope `activity:read_all`).
2. **Elegir actividades** (`StravaImportScreen`): lista paginada de `GET /athlete/activities`;
   las ya importadas aparecen marcadas. Máx. 15 por importación.
3. **Importar**: por cada actividad se pide el detalle (`GET /activities/:id`) → splits por km,
   vueltas, mejores esfuerzos, cadencia, `workout_type`, `perceived_exertion`. Se guarda en
   `TrainingSession` (upsert por `user + stravaActivityId`; reimportar no pisa RPE/notas/tipo).
4. **Analizar**: detalle de sesión con insights + el atleta anota tipo, RPE, sensación y notas.
5. **Progresar**: el hub muestra forma, nivel, objetivo y plan de la próxima semana.

Independiente de `Route` (portadas/mapas): una actividad puede estar en ambos.

## Motor (`backend/services/trainingAnalysisService.js`, funciones puras)

| Concepto | Cálculo |
|---|---|
| FC máx | Perfil → si no, la mayor `maxHeartRate` observada (≥150) → si no, sin zonas |
| Zonas | % FC máx: Z1 <60, Z2 60–70, Z3 70–80, Z4 80–90, Z5 ≥90 (por split si hay FC por km) |
| Carga | TRIMP Banister `min × HRR × 0.64 × e^(1.92·HRR)`; sin FC: `RPE × min × 0.4` (misma escala); sin nada: `min × factor deporte` |
| Splits | CV de ritmo, 1ª vs 2ª mitad (negativo < −2 %, positivo > +3 %), desacople Pa:HR |
| Tipo auto | `workout_type` 1 → carrera; vueltas/splits con CV > 12 % → series; ≥ 80 min o ≥ 16 km → larga; FC ≥ 84 % o RPE ≥ 7 → tempo; FC < 68 % → suave/recuperación |
| Comparación | Última sesión del mismo deporte y tipo con distancia ±25 %: Δ ritmo y Δ FC |
| CTL / ATL / TSB | EWMA 42 d / 7 d de la carga diaria (días en hora de Lima); TSB = CTL − ATL |
| ACWR | carga 7 d ÷ (carga 28 d / 4): <0.8 baja, 0.8–1.3 óptima, 1.3–1.5 precaución, >1.5 riesgo |
| VDOT | Daniels sobre la mejor actividad ≥ 3 km o mejor esfuerzo ≥ 3 km de los últimos 90 días (cota inferior) |
| Predicciones / ritmos | Bisección sobre la fórmula de Daniels; E 62–70 %, M 81 %, T 88 %, I 98 %, R 105 % del VDOT |
| Eficiencia | (m/min) / FC en rodajes; últimas 3 semanas vs 3–9 semanas atrás |
| Objetivo | VDOT requerido para la marca; VDOT/semana necesario: ≤0.3 alcanzable, ≤0.6 ambicioso; fase base/construcción/específica/taper |

### Recomendación semanal (`weeklyRecommendation`)

Base = km de la semana pasada (o media de 4). Orden de reglas:
`start` (sin datos → 15 km) · `taper` (≤ 2 semanas a la carrera: ×0.7, última ×0.5) ·
`reduce` (ACWR > 1.5 o TSB < −30: ×0.75) · `hold` (ACWR 1.3–1.5 o TSB < −20) ·
`deload` (3 semanas seguidas subiendo: ×0.75) · `rebuild` (carga baja) · `build` (×1.08).
Plan 80/20: 1 tirada larga (30 %), 1–2 sesiones de calidad (tempo, series) según días/semana,
resto suaves; con ritmos VDOT si hay nivel, si no por RPE.

## API `/api/training`

| Método | Ruta | Descripción |
|---|---|---|
| GET/PUT | `/profile` | FC máx/reposo, `weeklySessions` (2–7), `goal {name, distanceKm, targetTimeSec, date}` |
| GET | `/summary` | `summary` (weeks, load, fitness, intensity, efficiency, goal, recommendation) + `hasStrava` |
| GET | `/sessions?limit&before` | Lista con análisis ligero (tipo, carga, ritmo) |
| GET | `/sessions/:id` | Sesión completa + `analysis` (insights, zonas, splits, comparison) |
| POST | `/sessions` | Registro manual (`movingTime` s obligatorio, `distance` m) |
| PUT | `/sessions/:id` | `sessionType`, `rpe`, `feeling`, `notes`, `title` |
| DELETE | `/sessions/:id` | Borra solo del módulo (no de Strava) |
| GET | `/strava/activities?page` | Actividades de Strava con `imported`/`sessionId` |
| POST | `/strava/import {activityIds}` | Importa ≤ 15; secuencial; corta al primer 429 y devuelve `failed` |

Token de Strava: `services/stravaClient.js` (`getStravaAccessToken` refresca y persiste cifrado;
compartido con `/api/routes/strava/sync`).

## Flutter

- `lib/models/training.dart`, `lib/services/training_service.dart`, `lib/providers/training_provider.dart`
- `lib/screens/training/`: `training_hub_screen.dart`, `strava_import_screen.dart`,
  `training_session_screen.dart`, `training_log_screen.dart`, `training_profile_sheet.dart`, `training_widgets.dart`

## Tests

`cd backend && npm test` → `tests/trainingAnalysisService.test.js` (VDOT, ritmos, carga, splits,
clasificación, comparación, semanas, build/reduce/deload, objetivo).

## Pendiente / ideas

- Importar también las carreras del Tracking en vivo como `TrainingSession`.
- Webhook de Strava para avisar de actividades nuevas (sigue siendo opcional importarlas).
- Pasar el resumen al Coach IA como contexto RAG.
