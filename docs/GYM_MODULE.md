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

Hay 27 ejercicios predefinidos que se cargan vía `npm run seed`.

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
    order:    Number         // posición en la rutina
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
    setsCompleted: Number,
    repsCompleted: String
  }]
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
| POST | `/api/gym/workouts` | Registrar sesión |
| GET | `/api/gym/streak` | Racha de semanas |
| GET | `/api/gym/workouts?limit=` | Historial de entrenamientos |

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
