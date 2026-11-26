# Plan: progresión de carga en el módulo Gimnasio

Plan de implementación para `idmr023/app_pasos`. Basado en el código del commit `ac27726` (rama por defecto).
Ubicación sugerida en el repo: `plans/progresion-de-carga.md` (el `AGENTS.md` de `app_pasos/` reserva `plans/` para esto).

## 1. Objetivo

Que la app haga sola lo que hoy se hace a mano con una tabla:

1. Guardar el **peso base** de cada ejercicio (el peso de trabajo actual del usuario).
2. Saber **cuándo subir** y **cuánto subir**, con la regla de doble progresión.
3. Ayudar a **encontrar la base** de un ejercicio nuevo.
4. Manejar los **saltos grandes** de peso y los **estancamientos**.

Al abrir un entrenamiento, cada ejercicio debe mostrar algo como:
`Press de pecho · 15 kg × 6-10 · Sube a 17.5 kg cuando logres 4 × 10`.

## 2. Reglas de negocio (lo que el motor debe reproducir)

| # | Regla | Detalle |
|---|---|---|
| R1 | Base | Peso con el que se completa el piso del rango y quedan unas 2 repeticiones de reserva. |
| R2 | Rango | Cada ejercicio de la rutina tiene `repsMin` y `repsMax` (ej. 6-10, 10-12, 12-15). |
| R3 | Subir | Si **todas** las series llegan a `repsMax` con el peso actual: nuevo peso = actual + incremento, y el objetivo vuelve a `repsMin`. |
| R4 | Mantener | Si no se llegó al tope en todas las series: mismo peso, objetivo = una repetición más en la serie más baja. |
| R5 | Bajar | Si la primera serie queda por debajo del piso de tolerancia (`repsMin - 2`, mínimo 5): volver al peso anterior. |
| R6 | Salto grande (puente) | Si `incremento / pesoActual > 0.20`: no se sube todo de golpe. Primera serie con el peso nuevo y el resto con el anterior; se agrega una serie pesada cada vez que la última serie pesada alcanza el umbral (`repsMin - 2`, mínimo 5). Cuando todas las series son pesadas, el peso nuevo pasa a ser la base. |
| R7 | Estancamiento | Dos sesiones seguidas con el mismo peso sin sumar repeticiones totales: sugerir bajar 10 % (redondeado al incremento) y volver a subir. |
| R8 | Ejercicios por tiempo | Si `reps` termina en `s` (ej. `45s`): no hay peso; al completar todas las series, sugerir +5 s. |
| R9 | Unidades | Se guarda siempre en kg. La unidad (kg o lb) es solo de visualización y se recuerda por ejercicio. |
| R10 | Cada máquina es un ejercicio | El mismo número pesa distinto en cada máquina. La progresión se lleva por `exerciseId`; ver decisión abierta D1. |

Casos reales para validar (salen de la rutina que originó esta función):

| Ejercicio | Peso | Rango | Incremento | Sesión | Resultado esperado |
|---|---|---|---|---|---|
| Press de pecho | 15 kg | 4 × 6-10 | 2.5 | 6, 6, 6, 6 | Mantener 15 kg, objetivo 7 |
| Press de pecho | 15 kg | 4 × 6-10 | 2.5 | 10, 10, 10, 10 | Subir a 17.5 kg (salto 16.7 %, sin puente), objetivo 6 |
| Elevaciones laterales | 7.5 kg | 3 × 12-15 | 2.5 | 15, 15, 15 | Puente: 1 serie con 10 kg + 2 con 7.5 kg (salto 33 %) |
| Elevaciones laterales (puente, 1 serie pesada) | 10 / 7.5 kg | 3 × 12-15 | 2.5 | 10, 15, 14 | Puente: 2 series con 10 kg + 1 con 7.5 kg |
| Curl con mancuernas | 12 kg | 3 × 6-10 | 2 | 6, 6, 5 | Mantener 12 kg, objetivo 6 en la tercera |
| Press francés barra Z | 10 kg | 3 × 10-12 | 2.5 | 12, 12, 12 | Puente (salto 25 %): 1 serie con 12.5 kg |
| Remo en discos | 15 kg | 3 × 10-12 | 2.5 | 10, 9, 9 en tres sesiones seguidas (dos sin mejorar) | Estancamiento: 15 × 0.9 = 13.5 kg → redondeado a 12.5 kg |
| Sentadilla en pared | sin peso | 4 × 45s | n/a | 4 series completas | Sugerir 50 s |

## 3. Estado actual del código (lo relevante)

**Backend**

- `backend/models/Routine.js`: cada ejercicio tiene `exercise` (String), `exerciseName`, `sets`, `reps` (String: `"10"`, `"30s"`, `"Al fallo"`), `restTime`, `order`. No hay rango, peso objetivo ni incremento.
- `backend/models/Workout.js`: cada ejercicio guarda `setsCompleted`, `repsCompleted` (String) y `weightKg`. **Un solo peso por ejercicio**, sin detalle por serie.
- `backend/models/PersonalRecord.js`: `{ user, exercise, maxWeightKg }` con índice único `{ user, exercise }`. Sirve de patrón para el nuevo modelo.
- `backend/routes/gym.js`: `POST /workouts` (línea 406) guarda el workout y actualiza PR con un bucle de upserts. `POST/PUT /routines` (líneas 286 y 355) mapean los campos del ejercicio uno por uno; un campo nuevo que no se agregue ahí se pierde.
- `backend/services/chatService.js` (línea 202 en adelante): el contexto del Coach incluye workouts recientes y PR. No sabe nada de progresión.
- No hay tests de backend ni runner configurado en `backend/package.json`.

**Flutter**

- `lib/screens/gym/workout_screen.dart`:
  - `_setWeights` guarda el peso por serie en kg, pero empieza en 0 en cada entrenamiento: **no recuerda el peso de la sesión anterior**.
  - El peso escrito solo se guarda en `onFieldSubmitted` (línea 457). Si el usuario escribe y toca "Completar serie" sin enviar el teclado, el valor se pierde.
  - `_finishWorkout` (línea 149) envía `setsCompleted: e.sets` y `repsCompleted: e.reps`: son los valores **planificados**, no los reales. Solo envía el peso máximo.
  - Usa `widget.exercises.indexOf(e)` para armar la clave de cada serie; conviene iterar con índice.
  - No envía `routineId`, así que `Workout.routine` queda siempre en `null`.
  - `_useLbs` es un estado de pantalla: se pierde al salir.
- `lib/models/routine.dart`: `RoutineExercise` con `sets`, `reps`, `restTime`, `order`.
- `lib/models/workout.dart`: `WorkoutExercise` no lee `weightKg`.
- `lib/screens/gym/routine_builder_screen.dart`: copia los campos de `RoutineExercise` uno por uno al editar (línea 35) y limita las series con `clamp(3, 5)` (línea 317). `routine_confirm_screen.dart` aplica series y repeticiones globales a todos los ejercicios (línea 244).
- `lib/providers/gym_provider.dart` y `lib/services/gym_service.dart`: patrón claro para sumar llamadas (`getPersonalRecords` es el más parecido).

**Conclusión:** hoy no se puede calcular la progresión porque no se registran las repeticiones reales por serie. Ese es el primer paso.

## 4. Diseño

### 4.1 Datos

**`Routine.exercises[]` (prescripción, campos nuevos opcionales)**

```js
repsMin:     { type: Number, default: null },  // 6
repsMax:     { type: Number, default: null },  // 10
incrementKg: { type: Number, default: 2.5 },   // cuánto sube cada salto
```

`reps` (String) se mantiene para compatibilidad y para mostrar: con rango se guarda `"6-10"`. Si `repsMin/repsMax` son `null`, el motor los deriva de `reps` (`"10"` → 10-10; `"45s"` → por tiempo; `"Al fallo"` → sin sugerencias).

**`Workout.exercises[]` (registro real, campo nuevo)**

```js
setLogs: [{ weightKg: Number, reps: Number, seconds: Number }]
```

`weightKg`, `setsCompleted` y `repsCompleted` se siguen llenando (el servidor los calcula desde `setLogs`) para no romper PR, logros ni versiones anteriores de la app.

**Modelo nuevo `backend/models/ExerciseProgress.js` (estado por usuario y ejercicio)**

```js
{
  user:            ObjectId,            // ref User
  exercise:        String,              // mismo id que Routine.exercises[].exercise
  exerciseName:    String,
  currentWeightKg: Number,              // peso base actual; 0 = sin calibrar
  unit:            'kg' | 'lb',         // solo visualización
  loadNote:        String,              // texto libre: "por lado", "por mancuerna", "máquina de discos"
  status:          'calibrating' | 'progressing' | 'bridge',
  bridgeTargetKg:  Number,              // peso nuevo durante el puente
  bridgeHeavySets: Number,              // cuántas series van con el peso nuevo
  stallCount:      Number,
  lastSession:     { date: Date, weightKg: Number, reps: [Number] },
  next:            { action, weightKg, targetReps, heavySets, message }  // sugerencia ya calculada
}
// índice único: { user: 1, exercise: 1 }
```

### 4.2 Motor de progresión

Archivo nuevo `backend/services/progressionService.js` con una **función pura**, sin acceso a base de datos:

```js
// prescription: { sets, repsMin, repsMax, incrementKg, isTimed }
// state:        ExerciseProgress (o valores por defecto)
// session:      [{ weightKg, reps, seconds }]
// devuelve:     { state, suggestion }
function computeNext(prescription, state, session) { ... }
```

Constantes en el mismo archivo, fáciles de ajustar:

```js
const BIG_JUMP_RATIO = 0.20;
const STALL_SESSIONS = 2;
const DELOAD_FACTOR  = 0.90;
const TIME_STEP_S    = 5;
const tolerance = (repsMin) => Math.max(5, repsMin - 2);
```

Orden de evaluación:

1. `isTimed` → R8.
2. `currentWeightKg === 0` → la base es el mayor peso de la sesión con `reps >= repsMin`; `status = 'progressing'`.
3. `status === 'bridge'` → R6 (avanzar series pesadas o cerrar el puente).
4. Primera serie `< tolerance(repsMin)` → R5.
5. Todas las series `>= repsMax` → R3, o R6 si el salto supera `BIG_JUMP_RATIO`.
6. Repeticiones totales `<=` sesión anterior con el mismo peso → `stallCount++`; si llega a `STALL_SESSIONS` → R7.
7. En cualquier otro caso → R4 y `stallCount = 0`.

`suggestion.action` es uno de: `calibrate`, `increase`, `hold`, `bridge`, `decrease`, `deload`.
`suggestion.message` va en español y listo para mostrar, por ejemplo: `"Sube a 17.5 kg y vuelve a 6 repeticiones"`.

Todo peso sugerido se redondea a múltiplos de `incrementKg`.

### 4.3 API

| Método | Endpoint | Cambio |
|---|---|---|
| POST | `/api/gym/workouts` | Acepta `exercises[].setLogs` y `routineId`. Tras guardar, corre el motor por ejercicio, hace upsert de `ExerciseProgress` y responde también `progression: [{ exerciseId, action, weightKg, targetReps, heavySets, message }]`. |
| GET | `/api/gym/progress?exerciseIds=a,b,c` | Nuevo. Devuelve el estado y la sugerencia vigente de cada ejercicio, para precargar el entrenamiento. |
| PUT | `/api/gym/progress/:exerciseId` | Nuevo. Ajuste manual: `currentWeightKg`, `unit`, `loadNote`. Reinicia `stallCount` y el puente. |
| POST / PUT | `/api/gym/routines` | Aceptan `repsMin`, `repsMax`, `incrementKg` por ejercicio (validar `1 <= repsMin <= repsMax <= 100`, `0 < incrementKg <= 50`). |

Compatibilidad: si una versión anterior de la app no envía `setLogs`, el servidor arma una sesión aproximada con `setsCompleted`, `repsCompleted` y `weightKg`, o no calcula progresión si no alcanza.

## 5. Fases

Cada fase es un cambio pequeño y verificable por separado (el `AGENTS.md` pide diffs menores a 300 líneas). Los cambios de esquema están en la lista de "preguntar antes": este plan es la aprobación, pero conviene confirmarlo al iniciar la sesión con el agente.

### Fase 1: registrar las series reales

Sin esto no hay datos para el motor. Entrega valor sola: el historial queda correcto.

- [ ] `backend/models/Workout.js`: agregar `setLogs` al esquema de ejercicio.
- [ ] `backend/routes/gym.js` (`POST /workouts`): leer `setLogs` (máximo 20 por ejercicio; `reps` 0-200; `weightKg` 0-500), calcular `weightKg` máximo, `setsCompleted` y `repsCompleted` desde ahí, y aceptar `routineId`.
- [ ] `lib/models/workout.dart`: clase `WorkoutSet` y campos `weightKg` y `setLogs` en `WorkoutExercise`.
- [ ] `lib/screens/gym/workout_screen.dart`:
  - [ ] Guardar el peso en `onChanged`, no solo en `onFieldSubmitted`.
  - [ ] Agregar un selector de repeticiones logradas por serie (por defecto, el objetivo), junto al de peso.
  - [ ] Al pasar de serie, precargar el peso de la serie anterior.
  - [ ] `_finishWorkout`: iterar con índice, enviar `setLogs` solo de las series completadas y enviar `routineId`.
  - [ ] Recibir `routineId` como parámetro opcional de `WorkoutScreen` y pasarlo desde `routine_builder_screen.dart`.
- [ ] Corregir el texto del PR, que hoy trunca decimales (`toInt()` muestra 12 para 12.5).

**Listo cuando:** un workout guardado tiene en MongoDB el peso y las repeticiones reales de cada serie, y un workout enviado sin `setLogs` se sigue guardando igual que antes.

### Fase 2: rango de repeticiones e incremento en la rutina

- [ ] `backend/models/Routine.js`: `repsMin`, `repsMax`, `incrementKg`.
- [ ] `backend/routes/gym.js`: mapearlos y validarlos en `POST` y `PUT /routines`.
- [ ] `lib/models/routine.dart`: campos nuevos en `RoutineExercise`, en `fromJson` y en `toJson`.
- [ ] `lib/screens/gym/routine_builder_screen.dart`:
  - [ ] Copiar los campos nuevos al editar (línea 35); si no, se pierden al guardar.
  - [ ] En cada ejercicio: campos "Mín" y "Máx" de repeticiones e "Incremento (kg)".
  - [ ] Al guardar con rango, escribir también `reps = "6-10"`.
- [ ] `routine_config_screen.dart` y `routine_confirm_screen.dart`: sin cambios en el flujo de 3 pasos; el rango se ajusta después desde el editor.

**Listo cuando:** una rutina editada conserva el rango y el incremento tras cerrar y volver a abrir la app, y las rutinas antiguas siguen cargando sin cambios.

### Fase 3: motor y estado de progresión

- [ ] `backend/services/progressionService.js`: `computeNext` según la sección 4.2.
- [ ] `backend/tests/progressionService.test.js`: un test por cada fila de la tabla de casos de la sección 2, más los bordes (sin base, `reps` no numérico, incremento 0). Usar `node:test`, que viene con Node y no agrega dependencias.
- [ ] `backend/package.json`: script `"test": "node --test tests/"`.
- [ ] `backend/models/ExerciseProgress.js` con su índice único.
- [ ] `backend/routes/gym.js`:
  - [ ] `POST /workouts`: tras guardar, obtener la prescripción desde la rutina (`routineId`) o desde los valores por defecto, correr el motor, hacer upsert y devolver `progression`. Un fallo del motor no debe impedir guardar el workout (envolver en `try/catch`, igual que el contexto diario del chat).
  - [ ] `GET /progress` y `PUT /progress/:exerciseId`.

**Listo cuando:** `npm test` pasa en `backend/` y, después de dos workouts de prueba, `GET /api/gym/progress` devuelve la sugerencia esperada.

### Fase 4: mostrar la sugerencia en el entrenamiento

- [ ] `lib/models/exercise_progress.dart`: modelo nuevo.
- [ ] `lib/services/gym_service.dart`: `getProgress(ids)` y `updateProgress(id, body)`, con el mismo patrón que `getPersonalRecords`.
- [ ] `lib/providers/gym_provider.dart`: mapa `_progress` por `exerciseId`, `loadProgress(ids)`, y hacer que `logWorkout` guarde la `progression` de la respuesta.
- [ ] `lib/screens/gym/workout_screen.dart`:
  - [ ] En `initState`, cargar el progreso de los ejercicios de la rutina.
  - [ ] Precargar el peso de cada serie con la sugerencia (en puente, las primeras `heavySets` series con `bridgeTargetKg`).
  - [ ] Tarjeta "Objetivo de hoy" bajo el nombre del ejercicio: peso, rango y condición para subir.
  - [ ] Recordar kg o lb por ejercicio usando `unit`, en lugar de `_useLbs` global.
  - [ ] Pantalla final: sección "Próxima sesión" con el mensaje de cada ejercicio.
- [ ] Seguir la convención de rendimiento del repo: `Selector<GymProvider, ...>` para reconstruir solo la tarjeta que cambia.

**Listo cuando:** al repetir una rutina, los pesos aparecen precargados y la pantalla final dice qué hacer la próxima vez.

### Fase 5: encontrar la base, puente y estancamiento

- [ ] Asistente de calibración cuando `currentWeightKg == 0`. Tras la primera serie pregunta "¿Cuántas repeticiones te quedaban?":
  - "4 o más" → sugerir un escalón más en la siguiente serie.
  - "2 o 3" → ese peso queda como base.
  - "0 o 1" o "No llegué" → sugerir un escalón menos.
- [ ] Indicador visible del puente: "Serie 1 con 10 kg, series 2 y 3 con 7.5 kg".
- [ ] Aviso de estancamiento con la sugerencia de bajar 10 % y el recordatorio de revisar sueño y comida.
- [ ] `lib/screens/gym/exercise_detail_sheet.dart`: bloque "Tu progresión" con peso base, estado y botón "Ajustar peso base" (`PUT /progress/:id`).

**Listo cuando:** un ejercicio nuevo queda con base definida al terminar su primer entrenamiento, sin escribir el peso a mano en ajustes.

### Fase 6: Coach IA y documentación

- [ ] `backend/services/chatService.js`: bloque `PROGRESIÓN DE CARGA` en el contexto, con peso base y próxima acción de hasta 8 ejercicios recientes.
- [ ] `docs/GYM_MODULE.md`: modelos, endpoints y reglas R1-R10.
- [ ] `AGENTS.md` (raíz): fila de `/api/gym` en "Backend Rutas" e índice de `ExerciseProgress` en "Índices MongoDB".
- [ ] `app_pasos/docs/ai/how-to-test.md`: comandos reales de verificación.

## 6. Verificación

```bash
# Backend
cd backend && npm test          # motor de progresión (desde la fase 3)
cd backend && npm run dev       # probar endpoints a mano

# Flutter
cd app_pasos && flutter analyze
cd app_pasos && flutter test
```

Prueba manual de punta a punta, con la rutina real:

1. Crear "Día 1" con press de pecho 4 × 6-10, incremento 2.5.
2. Entrenar con 15 kg y 6, 6, 6, 6 → debe decir "mantén 15 kg, busca 7".
3. Entrenar con 15 kg y 10, 10, 10, 10 → debe decir "sube a 17.5 kg".
4. Abrir de nuevo la rutina → el peso precargado debe ser 17.5 kg.
5. Repetir con elevaciones laterales 7.5 kg, 3 × 12-15 y 15, 15, 15 → debe proponer el puente con 10 kg.

## 7. Decisiones abiertas

| # | Decisión | Opción recomendada |
|---|---|---|
| D1 | Misma máquina con dos equipos distintos (remo de discos vs. remo de placas) | Tratarlos como dos ejercicios de la librería. Alternativa más cara: campo `variant` en `ExerciseProgress` y en el índice. |
| D2 | Cómo se cuenta el peso (total, por lado, por mancuerna) | No calcular nada: guardar el número tal como lo cuenta el usuario y mostrar `loadNote` al lado. |
| D3 | Pedir repeticiones de reserva en cada serie | Solo en la calibración (fase 5). En el día a día agrega fricción. |
| D4 | Dónde vive el motor | En el backend, porque el Coach IA también lo usa y la app ya depende de la red para guardar. |
| D5 | Descarga programada cada 6 o 7 semanas | Fuera de la primera versión; el aviso de estancamiento cubre el caso más común. |
| D6 | Límite de series `clamp(3, 5)` en el editor | Ampliar a 1-10 para igualar a `routine_config_screen.dart`, en un cambio aparte. |

## 8. Fuera de alcance

- Estimación de 1RM y porcentajes.
- Calculadora de discos por lado.
- Funcionamiento sin conexión.
- Gráficas de evolución por ejercicio (candidata natural para una fase 7, en `analytics_screen.dart`).
- Migración de workouts antiguos: no tienen datos por serie, así que la progresión empieza desde el primer entrenamiento nuevo.

## 9. Riesgos

- **Versiones antiguas de la app:** todos los campos nuevos son opcionales y el servidor conserva `weightKg`, `setsCompleted` y `repsCompleted`.
- **Fricción al registrar:** el selector de repeticiones debe venir precargado con el objetivo, para que la serie normal siga siendo un solo toque.
- **Sugerencias equivocadas:** el usuario siempre puede escribir otro peso, y `PUT /progress/:id` permite corregir la base. La sugerencia nunca bloquea.
- **Costo en `POST /workouts`:** suma un upsert por ejercicio a los que ya hace el PR. Si crece, agrupar ambos en un `bulkWrite` (ya anotado como mejora pendiente en `AGENTS.md`).
