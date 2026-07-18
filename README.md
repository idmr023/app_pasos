# App Pasos

Competencias de pasos entre amigos + gimnasio con rutinas y temporizador.

Flutter app (Android/iOS/Web/Desktop) + Node.js/Express API + MongoDB Atlas.

## Stack

- **Frontend**: Flutter 3.x, Provider, CachedNetworkImage, flutter_secure_storage
- **Backend**: Node.js, Express, Mongoose, JWT (bcrypt)
- **Base de datos**: MongoDB Atlas
- **Ejercicios**: WorkoutX API (`api.workoutxapp.com/v1`) + seed local

## Requisitos

- Node.js 18+
- Flutter 3.22+
- MongoDB Atlas URI (free tier suficiente)

## Setup rápido

```bash
# Backend
cd backend
cp .env.example .env   # configurar MONGODB_URI y WORKOUTX_API_KEY
npm install
npm run dev            # http://localhost:3000

# Poblar DB (opcional)
npm run seed           # usuarios demo + 27 ejercicios
npm run sync-exercises # 1,327+ ejercicios desde WorkoutX

# Flutter
cd app_pasos
flutter pub get
flutter run --dart-define=BACKEND_URL=http://10.0.2.2:3000/api  # emulador
```

## Scripts backend

| Comando | Descripción |
|---|---|
| `npm run dev` | Servidor con nodemon (hot reload) |
| `npm start` | Servidor producción |
| `npm run seed` | Pobla DB con datos demo |
| `npm run sync-exercises` | Sincroniza ejercicios desde WorkoutX |

## Estructura

```
app_pasos/          → Flutter app
  lib/
    config/         → Tema, API config
    models/         → Exercise, Routine, Challenge...
    providers/      → Auth, Gym, Challenge, Step, Xp
    screens/        → home/, gym/, profile/, chat/
    services/       → HTTP clients para cada módulo
    widgets/        → GlassCard, NeonButton, AnimatedCounter

backend/            → Node.js API
  models/           → Schemas Mongoose (con índices compuestos)
  routes/           → auth, challenges, steps, xp, gym
  middleware/       → JWT auth
  seed.js           → Datos de prueba
  sync-workoutx.js  → Sincronizador WorkoutX

docs/               → Documentación para agentes IA
```

## Performance

- Health check fire-and-forget (no bloquea startup)
- Debounce 300ms en búsqueda de ejercicios
- Selectors para evitar rebuilds innecesarios
- Índices MongoDB compuestos en todas las colecciones
- XP cacheados en User (sin recálculo en GET)
- Streak limitado a 52 workouts
- N+1 eliminados en endpoints de challenges
- Caché de ejercicios en SharedPreferences
