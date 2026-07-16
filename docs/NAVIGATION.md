# Navegación de App Pasos

## BottomNavigationBar (4 tabs)

```
┌────────────────────────────────────────────────────┐
│  🏃 Pasos      💪 Gimnasio      🤖 Chat      👤 Perfil  │
└────────────────────────────────────────────────────┘
```

Cada tab es parte de `MainShell` (`lib/screens/main_shell.dart`), que usa un `IndexedStack` para mantener el estado de cada pantalla.

---

## Tab 0: Pasos (HomeScreen)

Pantalla principal de retos por pasos. Contenido:

```
┌─────────────────────────────────┐
│ Header                          │
│ ┌─────────────────────────────┐ │
│ │ 👤 Avatar    Nombre     🚪  │ │  ← avatar abre perfil, logout
│ └─────────────────────────────┘ │
│                                 │
│ Pasos de Hoy                    │
│ ┌─────────────────────────────┐ │
│ │        12,450               │ │  ← AnimatedCounter
│ │   tus pasos registrados hoy │ │
│ └─────────────────────────────┘ │
│                                 │
│ [ACTIVOS │ FINALIZADOS]         │  ← TabBar para filtrar retos
│                                 │
│ ┌── Reto: ABC123 ──────────┐   │
│ │ 🏆  vs Carlos  · 30d  🔥 │   │  ← tap → ChallengeRoomScreen
│ └───────────────────────────┘   │
│ ┌── Reto: XYZ789 ──────────┐   │
│ │ 🏆  vs María  · 7d   ✅ │   │  ← reto finalizado
│ └───────────────────────────┘   │
│                                 │
│ [+ CREAR RETO]  [UNIRME]       │  ← si no hay retos
│                               │
│                          [＋]   │  ← FAB (si hay retos)
└─────────────────────────────────┘
```

### Pantallas a las que navega desde Pasos:

| Acción | Pantalla | Ruta |
|---|---|---|
| Tap en reto activo | ChallengeRoomScreen | `/challenge-room` |
| Tap en botón + | ChallengeCreateScreen | `/challenge-create` |
| Tap en UNIRME | ChallengeJoinScreen | `/challenge-join` |
| Tap en Estadísticas | AnalyticsScreen | `/analytics` |

---

## Tab 1: Gimnasio (GymScreen)

```
┌─────────────────────────────────┐
│ GIMNASIO                        │
│                                 │
│ 🔥 5 semanas seguidas           │  ← racha semanal
│ ✓ Esta semana ya entrenaste     │
│                                 │
│ [NUEVA RUTINA] [EJERCICIOS]     │  ← acciones principales
│                                 │
│ MIS RUTINAS                     │
│                                 │
│ ┌── Full Body ──────────────┐   │
│ │ 💪  8 ejercicios          │   │  ← tap → RoutineBuilderScreen
│ └───────────────────────────┘   │
│ ┌── Calentamiento ──────────┐   │
│ │ 🔥  5 ejercicios · Calent. │   │
│ └───────────────────────────┘   │
└─────────────────────────────────┘
```

### Pantallas del módulo Gym:

| Pantalla | Descripción |
|---|---|
| **GymScreen** | Tab principal del gimnasio. Muestra racha semanal, botones de acción, lista de rutinas. |
| **ExerciseLibraryScreen** | Grid de ejercicios con imágenes GIF, filtro por categoría (Calentamiento/Fuerza/Cardio/Flexibilidad). Modo selección para armar rutinas. |
| **RoutineBuilderScreen** | Crea/edita rutinas: nombre, toggle warmup, selección de ejercicios, personalización de sets/reps/descanso, reordenar. Botón "Iniciar" para empezar workout. |
| **WorkoutScreen** | Ejecución de rutina: imagen del ejercicio, timer real (DateTime.now), timer de descanso, progreso de series, wakelock activo. |

---

## Tab 2: Chat (ChatScreen)

Placeholder del futuro Coach IA. Muestra mensajes de bienvenida precargados. Input deshabilitado. Preparado para conectar con API de chatbot.

---

## Tab 3: Perfil (ProfileScreen)

```
┌─────────────────────────────────┐
│ PERFIL                      🚪  │  ← logout
│                                 │
│ ┌── Nivel XP ──────────────┐   │
│ │ 👤 Nombre           NIVEL 5 │   │
│ │    Caminante         450 XP │   │
│ │ ████████░░░░░░░░  1000 XP  │   │  ← barra de progreso
│ └───────────────────────────┘   │
│                                 │
│ RECOMPENSAS                     │
│ ┌── Nivel 10: Caminante ────┐  │
│ │ 🔓 Avatar: walker [RECLAMAR]│  │
│ └───────────────────────────┘   │
│ ┌── Nivel 20: Maratonista ──┐  │
│ │ 🔒 Avatar: marathon      │  │
│ └───────────────────────────┘   │
│                                 │
│ 👤 Avatar Preview               │
│                                 │
│ Nombre: [_____________]         │
│                                 │
│ AVATAR                          │
│ [🏃][🏆][🔥][⭐][🚶][⛰️][⚡][✨][🌟] │
│                                 │
│ RECORDATORIO DIARIO             │
│ [Recordar registrar pasos] [🔘] │
│                                 │
│ [GUARDAR]                       │
└─────────────────────────────────┘
```

---

## Flujo de Navegación General

```
SplashScreen
  │
  ├─ ¿Autenticado? → MainShell (BottomNav)
  │                     │
  │                     ├─ Tab 0: Pasos → HomeScreen
  │                     │                  └─ push → ChallengeCreateScreen
  │                     │                  └─ push → ChallengeJoinScreen
  │                     │                  └─ push → ChallengeRoomScreen
  │                     │                              └─ push → AnalyticsScreen
  │                     │
  │                     ├─ Tab 1: Gimnasio → GymScreen
  │                     │                      └─ push → RoutineBuilderScreen
  │                     │                      │         └─ push → WorkoutScreen
  │                     │                      └─ push → ExerciseLibraryScreen
  │                     │
  │                     ├─ Tab 2: Chat → ChatScreen
  │                     │
  │                     └─ Tab 3: Perfil → ProfileScreen
  │
  └─ No autenticado → LoginScreen / RegisterScreen
                        │
                        └─ login exitoso → MainShell
```
