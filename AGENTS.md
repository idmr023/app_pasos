# App Pasos

Flutter app + Node.js backend para competencias de pasos entre amigos + gimnasio con rutinas y temporizador.

## Estructura

```
app_pasos/       → Flutter app (Android, iOS, Web, Windows, Linux, macOS)
backend/         → Node.js/Express API + MongoDB
docs/            → Documentación para el agente (ARCHITECTURE, NAVIGATION, GYM_MODULE, XP_LEVELS, THEME)
```

## Navegación Principal

BottomNavigationBar con 4 tabs (IndexedStack, todos vivos en memoria):
- **Pasos** 🏃 — HomeScreen: contador de pasos, retos activos/finalizados, crear/unirse a retos
- **Gimnasio** 💪 — GymScreen: racha semanal, rutinas, ejercicios, flujo 3-pasos nueva rutina
- **Chat** 🤖 — ChatScreen: Coach IA con Grok (xAI), chat funcional con memoria persistente y RAG sobre ejercicios
- **Perfil** 👤 — ProfileScreen: nivel XP, recompensas, editar nombre/avatar, recordatorio

## Comandos

```bash
# Backend
cd backend && npm run dev              # Iniciar servidor (puerto 3000)
cd backend && npm run seed             # Poblar DB con usuarios + 27 ejercicios predefinidos
cd backend && npm run sync-exercises   # Sincronizar 1327+ ejercicios desde WorkoutX API (manual)

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

### Módulo Gimnasio
- **Librería de ejercicios**: 1,327+ ejercicios desde WorkoutX API con GIFs animados y nombres/descripciones en español, en 4 categorías (calentamiento, fuerza, cardio, flexibilidad) + 322 ejercicios predefinidos en español del seed
- **Rutinas**: flujo de 3 pasos para crear rutinas — (1) seleccionar ejercicios en `ExerciseLibraryScreen`, (2) configurar nombre/series/reps/descanso global en `RoutineConfigScreen`, (3) confirmar y guardar en `RoutineConfirmScreen`. Editar rutinas existentes con `RoutineBuilderScreen`.
- **Workout**: ejecutar rutinas paso a paso con temporizador real basado en DateTime.now() (preciso incluso con celular bloqueado)
- **Racha semanal**: seguimiento de semanas consecutivas entrenando (limitado a 52 workouts)
- **Wakelock**: pantalla encendida durante el workout
- **Alarma**: sonido al terminar cada timer

### Módulo Chat / Coach IA
- **Coach IA**: chatbot con Grok (xAI, compatible con API OpenAI) integrado vía backend Express
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
| `/api/challenges` | POST create, POST join, GET list/detail, POST leave, DELETE |
| `/api/steps` | POST save, GET list/calendar, GET analytics |
| `/api/xp` | GET xp+level+progress, GET rewards, POST claim, GET weight-rewards |
| `/api/gym` | GET exercises, CRUD routines, POST workouts, GET streak, GET/POST personal-records |
| `/api/chat` | POST send message, GET history, DELETE history |

## Índices MongoDB

| Colección | Índice | Query que optimiza |
|---|---|---|
| Challenge | `{ creator: 1, status: 1 }` + `{ opponent: 1, status: 1 }` | Listar retos del usuario por status |
| Exercise | `{ category: 1, name: 1 }` + text index en `name`/`nameSpanish` | Filtrar y buscar ejercicios |
| Workout | `{ user: 1, date: -1 }` | Cálculo de racha semanal + listar workouts |
| Routine | `{ user: 1, createdAt: -1 }` | Listar rutinas del usuario |
| StepEntry | `{ challenge: 1, date: 1 }` | Calendario y analytics de retos |
| ChatConversation | `{ user: 1 }` (unique) | Obtener/conversación del usuario |

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
