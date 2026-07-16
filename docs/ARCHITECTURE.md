# Arquitectura de App Pasos

## Stack Tecnológico

- **Mobile**: Flutter 3.7+ (Android, iOS, Web, Windows, Linux, macOS)
- **Backend**: Node.js + Express + MongoDB (Mongoose ODM)
- **Auth**: JWT + bcryptjs + flutter_secure_storage
- **State Management**: Provider (ChangeNotifier)

---

## Estructura del Proyecto

```
app-pasos/
├── app_pasos/              → Flutter app
│   └── lib/
│       ├── config/         → API URL, Theme
│       ├── models/         → User, Challenge, StepEntry, Exercise, Routine, Workout
│       ├── providers/      → AuthProvider, ChallengeProvider, StepProvider, XpProvider, GymProvider
│       ├── screens/        → 15+ pantallas
│       │   ├── chat/       → ChatScreen (placeholder coach)
│       │   └── gym/        → GymScreen, ExerciseLibraryScreen, RoutineBuilderScreen, WorkoutScreen
│       ├── services/       → Llamadas HTTP a la API
│       └── widgets/        → GlassCard, NeonButton, PlayerAvatar, AnimatedCounter, WorkoutTimer, etc.
├── backend/                → Node.js API
│   ├── middleware/         → JWT auth middleware
│   ├── models/             → Mongoose schemas
│   └── routes/             → Express routers
└── docs/                   → Documentación para el agente
```

---

## Flujo de Datos

```
UI (Screen)
  ↓ Provider (lectura/escritura)
    ↓ Service (HTTP)
      ↓ API (Express)
        ↓ Mongoose
          ↓ MongoDB Atlas
```

### Patrón Provider → Service

Cada provider instancia un service que hace llamadas HTTP. El token JWT se inyecta manualmente:

```dart
// En provider
void setToken(String token) {
  _service = XpService(token);
}
```

El token se setea desde `AuthProvider` después del login, en `MainShell._initProviders()`.

---

## Módulos y Sus Conexiones

```
Steps ──→ XP (1 XP = 10 pasos) ──→ Level ──→ Rewards (cada 10 niveles)
  │
  └──→ Challenges (competiciones entre usuarios)

Gym (independiente de pasos)
  ├── Exercise Library (predefinidos)
  ├── Routines (creadas por usuario)
  ├── Workouts (sesiones ejecutadas)
  └── Streak (semanas consecutivas)
```

---

## Backend: Modelos

| Modelo | Colección | Campos clave |
|---|---|---|
| User | users | username, password, displayName, avatar, xp, level, title, role |
| Challenge | challenges | code, creator, opponent, duration, status, startDate, endDate |
| StepEntry | stepentries | user, challenge, date, steps |
| UserReward | userrewards | user, reward |
| Exercise | exercises | name, category, imageUrl, defaultSets, defaultReps, restTime |
| Routine | routines | user, name, exercises[], isWarmup |
| Workout | workouts | user, routine, date, duration, exercises[] |

---

## Backend: Endpoints

| Ruta | Métodos |
|---|---|
| `/api/auth` | POST register, POST login, GET profile, PUT profile |
| `/api/challenges` | POST create, POST join, GET list, GET/:id, POST/:id/leave, DELETE/:id |
| `/api/steps` | POST save, GET list, GET calendar, GET/:challengeId/analytics |
| `/api/xp` | GET xp+level, GET rewards, POST claim/:rewardKey |
| `/api/gym` | GET exercises, GET/POST/PUT/DELETE routines, POST workouts, GET streak, GET workouts |
