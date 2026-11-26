# Módulo Gimnasio

## Visión General

El módulo de gimnasio es independiente del sistema de pasos. Permite crear rutinas de ejercicios, ejecutarlas con un cronómetro real (basado en `DateTime.now()`) y llevar un registro de la racha semanal de entrenamiento.

---

## Modelos Backend

### Exercise (`backend/models/Exercise.js`)

```javascript
{
  name:        String,      // "Flexiones de Brazos"
  category:    String,      // "warmup" | "strength" | "cardio" | "flexibility"
  imageUrl:    String,      // URL pública del GIF del ejercicio
  defaultSets: Number,      // 3
  defaultReps: String,      // "12" o "30s"
  restTime:    Number,      // segundos de descanso (60)
  description: String       // texto breve de cómo se hace
}
```

Hay **1,327+ ejercicios** sincronizados desde la **WorkoutX API** (`api.workoutxapp.com/v1`) con GIFs animados, más **322 ejercicios predefinidos en español** del seed.
- Seed local: `npm run seed`
- Sync desde WorkoutX: `npm run sync-exercises` (manual, no se ejecuta automáticamente)

### Routine (`backend/models/Routine.js`)

```javascript
{
  user:      ObjectId,       // dueño de la rutina
  name:      String,         // "Full Body", "Push Pull", etc.
  exercises: [{
    exercise: ObjectId,      // ref a Exercise
    sets:     Number,        // 3
    reps:     String,        // "10" o "30s"
    restTime: Number,        // segundos
    order:    Number,        // posición en la rutina
    repsMin:  Number,        // rango para la progresión (null → se deriva de reps)
    repsMax:  Number,        // con rango, reps se guarda también como "6-10"
    incrementKg: Number      // salto de peso (default 2.5)
  }],
  isWarmup:  Boolean         // true = aparece en sección calentamiento
}
```

### Workout (`backend/models/Workout.js`)

```javascript
{
  user:      ObjectId,
  routine:   ObjectId,       // null si fue workout libre
  routineName: String,
  date:      Date,
  duration:  Number,         // segundos totales
  exercises: [{
    exercise:      ObjectId,
    exerciseName:  String,
    setsCompleted: Number,   // con setLogs, lo calcula el servidor
    repsCompleted: String,
    weightKg:      Number,   // peso máximo (PR y logros)
    setLogs: [{ weightKg, reps, seconds, rir }]  // series reales (opcional)
  }]
}
```

### ExerciseProgress (`backend/models/ExerciseProgress.js`)

Estado de progresión por usuario y ejercicio. Índice único `{ user: 1, exercise: 1 }`.

```javascript
{
  user, exercise, exerciseName,
  currentWeightKg,   // peso base; 0 = sin calibrar
  previousWeightKg,  // para volver atrás (R5)
  currentSeconds,    // ejercicios por tiempo
  unit: 'kg' | 'lb', // solo visualización, se recuerda por ejercicio
  loadNote,          // "por lado", "por mancuerna"...
  status: 'calibrating' | 'progressing' | 'bridge',
  bridgeTargetKg, bridgeHeavySets, stallCount,
  lastSession: { date, weightKg, reps: [Number] },
  next: { action, weightKg, targetReps, heavySets, baseWeightKg, targetSeconds, message }
}
```

---

## Endpoints API

| Método | Endpoint | Descripción |
|---|---|---|
| GET | `/api/gym/exercises?category=` | Lista de ejercicios (filtro opcional) |
| GET | `/api/gym/exercises/:id` | Detalle de ejercicio |
| POST | `/api/gym/routines` | Crear rutina |
| GET | `/api/gym/routines?isWarmup=` | Mis rutinas |
| GET | `/api/gym/routines/:id` | Detalle de rutina |
| PUT | `/api/gym/routines/:id` | Editar rutina |
| DELETE | `/api/gym/routines/:id` | Eliminar rutina |
| POST | `/api/gym/workouts` | Registrar sesión. Acepta `routineId` y por ejercicio `setLogs` + `prescription`; responde `progression[]` |
| GET | `/api/gym/progress?exerciseIds=a,b` | Estado y sugerencia vigente por ejercicio |
| PUT | `/api/gym/progress/:exerciseId` | Ajuste manual: `currentWeightKg` (reinicia puente y estancamiento), `unit`, `loadNote` |
| GET | `/api/gym/streak` | Racha de semanas |
| GET | `/api/gym/workouts?limit=` | Historial de entrenamientos |

---

## Progresión de carga (doble progresión)

Motor puro en `backend/services/progressionService.js` (`computeNext(prescription, state, session)`), tests en `backend/tests/progressionService.test.js` (`npm test`). Corre en `POST /workouts` tras guardar; un fallo del motor no impide guardar el workout. La prescripción sale de `exercises[].prescription` (lo usado hoy), si no de la rutina (`routineId`), si no de `setLogs`/`repsCompleted`. Versiones antiguas sin `setLogs`: sesión aproximada solo si `repsCompleted` es numérico y hay peso.

| # | Regla |
|---|---|
| R1 | Base: sin calibrar, la base es la serie con 2-3 reps en reserva (`rir`) o el mayor peso que llegó a `repsMin`. Si no se puede, sugiere un escalón menos (`calibrate`). |
| R2 | Rango `repsMin`-`repsMax` por ejercicio (o derivado de `reps`: `"10"` → 10-10). |
| R3 | Todas las series ≥ `repsMax` → peso + incremento, objetivo vuelve a `repsMin`. |
| R4 | Si no → mismo peso, objetivo = la serie más baja + 1. |
| R5 | Primera serie < `max(5, repsMin - 2)` → volver al peso anterior. |
| R6 | Salto > 20 % → puente: 1 serie pesada; +1 cada vez que la última pesada llega a la tolerancia; con todas pesadas el peso nuevo es la base. |
| R7 | 2 sesiones seguidas, mismo peso, sin sumar reps totales → bajar 10 % (redondeado) y volver a subir. |
| R8 | Por tiempo (`"45s"`): todas las series completas → +5 s. |
| R9 | Siempre en kg; `unit` es solo visualización. |
| R10 | La progresión va por `exerciseId` (cada máquina = un ejercicio). |

Acciones: `calibrate`, `increase`, `hold`, `bridge`, `decrease`, `deload`. Todo peso se redondea al incremento. Si el usuario usa otro peso del sugerido, manda lo que hizo de verdad.

Flutter: `WorkoutScreen` carga `GET /progress` al abrir, precarga el peso por serie (en puente, las primeras `heavySets` con el peso nuevo), muestra "Objetivo de hoy" (`Selector<GymProvider, ExerciseProgress?>`), registra reps por serie (precargadas con el objetivo), pregunta reps en reserva mientras calibra y muestra "Próxima sesión" al terminar. El rango y el incremento se editan en `RoutineBuilderScreen`; la base se ajusta en `ExerciseDetailSheet` ("Tu progresión").

---

## Racha Semanal (Streak)

Se calcula así:
1. Se obtienen todos los `Workout` del usuario ordenados por fecha descendente
2. Se calcula el inicio de la semana actual (lunes)
3. Se verifica si hay un workout en la semana actual
4. Se retrocede semana por semana hasta encontrar una sin workout
5. Cada semana con al menos un workout suma 1 a la racha

Endpoint: `GET /api/gym/streak`

Respuesta:
```json
{
  "streak": 5,
  "currentWeekChecked": true,
  "weekStart": "2026-07-13T00:00:00.000Z"
}
```

---

## Temporizador Real (WorkoutTimer)

### Problema que resuelve

Muchas apps de fitness tienen temporizadores imprecisos porque cuentan "ticks" de `Timer.periodic`, que se atrasan cuando el celular está bloqueado o la app en background.

### Solución implementada

```dart
// 1. Registrar el momento exacto en que empieza
_startTime = DateTime.now();

// 2. Timer.periodic SOLO para refrescar la UI (cada 100ms)
_timer = Timer.periodic(Duration(milliseconds: 100), (_) {
  // 3. Calcular tiempo REAL transcurrido
  final elapsed = DateTime.now().difference(_startTime).inSeconds;
  final remaining = max(0, widget.totalSeconds - elapsed);
  // 4. Mostrar remaining en UI
});
```

Esto asegura que aunque el `Timer.periodic` se atrase (lo cual pasa en background), el tiempo mostrado siempre es correcto porque se calcula contra `DateTime.now()`.

### Funcionalidades del timer

- **Play/Pause**: detiene el cálculo elapsed
- **Skip**: salta al siguiente ejercicio/descanso
- **Alarma**: suena un beep al terminar (usando `audioplayers`)
- **Auto-descanso**: al completar un ejercicio, inicia automáticamente el timer de descanso

### Wakelock

```dart
// En WorkoutScreen.initState:
WakelockPlus.enable();   // Mantiene pantalla encendida

// En WorkoutScreen.dispose:
WakelockPlus.disable();  // Libera cuando se sale
```

---

## Pantallas Flutter del Módulo Gym

| Archivo | Widget | Descripción |
|---|---|---|
| `lib/screens/gym/gym_screen.dart` | GymScreen | Tab principal: racha, acciones, lista rutinas |
| `lib/screens/gym/exercise_library_screen.dart` | ExerciseLibraryScreen | Grid ejercicios con filtros, modo selección |
| `lib/screens/gym/routine_builder_screen.dart` | RoutineBuilderScreen | Crear/editar rutina, elegir ejercicios, configurar |
| `lib/screens/gym/workout_screen.dart` | WorkoutScreen | Ejecutar rutina paso a paso con timer |
| `lib/widgets/workout_timer.dart` | WorkoutTimer | Widget reutilizable de cronómetro |

---

## Paquetes Flutter Nuevos

| Paquete | Propósito |
|---|---|
| `wakelock_plus` | Mantener pantalla encendida durante el workout |
| `audioplayers` | Reproducir sonido de alarma al terminar timer |
