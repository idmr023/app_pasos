# Cambio de API: WorkoutX / wger.de sync → Proxy directo a wger.de

## Fecha
2026-07-20

## Motivación
- **WorkoutX API** tenía límite de 500 requests totales y se agotó
- **wger.de API** es gratuita, sin API key, sin límite de requests
- El sync batch (3,302 ejercicios, ~75 requests) era redundante: los ejercicios viven en wger.de, no necesitan duplicarse en MongoDB
- Se elimina la dependencia de un sync programado y la duplicación de datos

## Qué cambió

### Antes
```
Flutter App → Backend (MongoDB: Exercise collection) ← sync-wger.js ← wger.de API
```
- Backend almacenaba 3,302+ ejercicios en MongoDB (colección `Exercise`)
- `npm run sync-exercises` ejecutaba `sync-wger.js` para poblar la BD
- Routines, Workouts, PersonalRecords referenciaban ejercicios por **ObjectId** de MongoDB
- Categorías: `warmup`, `strength`, `cardio`, `flexibility`

### Después
```
Flutter App → Backend (proxy) → wger.de API (en vivo)
```
- Backend **no almacena ejercicios**. El endpoint `GET /api/gym/exercises` proxy a `https://wger.de/api/v2/exerciseinfo/`
- Routines, Workouts, PersonalRecords referencian ejercicios por **String** (`"wger_123"`)
- Cada exercise incluye `exerciseName` denormalizado para mostrar sin llamar a wger
- Categorías: solo `strength` y `cardio`
- Sin sync, sin caché local, sin duplicación

## Archivos eliminados

| Archivo | Razón |
|---|---|
| `backend/models/Exercise.js` | Ya no existe colección Exercise en MongoDB |
| `backend/sync-wger.js` | Ya no hay sync batch |
| `backend/sync-workoutx.js` | Sync anterior de WorkoutX |

## Archivos modificados — Backend

### `backend/models/Routine.js`
- `exercises[].exercise`: `ObjectId` ref `'Exercise'` → `String`
- Nuevo campo: `exercises[].exerciseName` (String, denormalizado)

### `backend/models/Workout.js`
- `exercises[].exercise`: `ObjectId` ref `'Exercise'` → `String`

### `backend/models/PersonalRecord.js`
- `exercise`: `ObjectId` ref `'Exercise'` → `String`
- Índice único `{ user: 1, exercise: 1 }` funciona igual con String

### `backend/routes/gym.js`
- `GET /exercises` → proxy a `GET https://wger.de/api/v2/exerciseinfo/`
  - Transforma `translations` → `name`/`nameSpanish`, `description`/`descriptionSpanish`
  - Mapea `category.name` → app category (`Abs`→`strength`, `Cardio`→`cardio`)
  - Imágenes: `images[].is_main` → `imageUrl`
  - Musculatura: `muscles[].name_en` → `muscle`
  - Equipamiento: `equipment[].name` → `equipment`
- `GET /exercises/:id` → proxy individual a `exerciseinfo/{id}/`
- Quitados todos los `.populate('exercise')` en rutas de routines y personal-records
- `POST /routines`, `PUT /routines/:id`, `POST /workouts`: reciben `exerciseId` como String + `exerciseName`

### `backend/services/chatService.js`
- Quitado `.populate('exercise')` en consulta de PersonalRecords
- Usa `exerciseName` denormalizado directamente

### `backend/seed.js`
- Quitado `require('./models/Exercise')`
- Creada función `getExercisesForSeed()` que busca ejercicios por nombre (ya no por ObjectId)

### `backend/package.json`
- Eliminado script `"sync-exercises"`

## Archivos modificados — Flutter

### `lib/models/routine.dart`
- `RoutineExercise.exerciseName`: nuevo campo String (denormalizado)
- `RoutineExercise.exercise`: eliminado (ya no se popula el objeto Exercise completo)
- `fromJson`: `exerciseId` lee `json['exercise']` como String

### `lib/models/workout.dart`
- `WorkoutExercise.exerciseId`: lee `json['exercise']` como String directo

### `lib/providers/gym_provider.dart`
- Eliminada caché con SharedPreferences (`_loadExercisesFromCache`, `_saveExercisesFromCache`)
- Nuevo sistema de **scroll infinito**: `_exercises`, `_currentOffset`, `_hasMore`, `_isLoading`
- `loadExercises()` ahora acepta `limit` y `offset`, soporta reset
- `loadPersonalRecords()` parsea `exercise` como String (ya no como Map)

### `lib/services/gym_service.dart`
- `getExercises()` ahora acepta `limit` y `offset`
- `createRoutine()` envía `exerciseId` + `exerciseName`
- `saveWorkout()` envía `exerciseId` + `exerciseName`
- `setPersonalRecord()` envía `exerciseId` + `exerciseName`

### `lib/screens/gym/exercise_library_screen.dart`
- Scroll infinito con `ScrollController`
- Solo 2 categorías en el filtro: **Todos**, **Fuerza**, **Cardio**
- Eliminados `warmup` y `flexibility` del selector de categorías

### `lib/screens/gym/gym_screen.dart`
- Solo muestra resumen de `strength` y `cardio`
- Eliminadas referencias a `warmup` y `flexibility`

### `lib/screens/gym/routine_confirm_screen.dart`
- Envía `exerciseName` junto a `exerciseId` al crear rutina

### `lib/screens/gym/routine_builder_screen.dart`
- Fallback a `exerciseName` cuando no hay objeto Exercise cargado

### `lib/screens/gym/workout_screen.dart`
- Fallback a `exerciseName` para mostrar nombre
- Fallback a cadena vacía para `imageUrl`

### `lib/screens/gym/exercise_detail_sheet.dart`
- Sin cambios estructurales (ya usaba `displayName`)

## Detalle del proxy

### Endpoint: `GET /api/gym/exercises`

```
Query params: search, category (strength|cardio), limit (default 20), offset (default 0)
```

**Mapeo de categorías app → wger:**
```
sin category param → todos los ejercicios
category=strength → ?category=8,9,10,11,12,13,14
category=cardio   → ?category=15
```

**Transformación de cada ejercicio wger → app:**

| wger field | app field | Notas |
|---|---|---|
| `id` | `id` | Prefijo `"wger_"` + id numérico |
| `translations[lang=2].name` | `name` | Inglés |
| `translations[lang=4].name` | `nameSpanish` | Español (si existe) |
| `category.name` | `category` | `Abs,Arms,Back,Calves,Chest,Legs,Shoulders` → `strength`; `Cardio` → `cardio` |
| `images[is_main].image` | `imageUrl` | PNG thumbnail |
| `translations[lang=2].description` | `description` | Con HTML removido |
| `translations[lang=4].description` | `descriptionSpanish` | Con HTML removido |
| `muscles[].name_en` | `muscle` | Join por coma |
| `equipment[].name` | `equipment` | Join por coma |
| — | `defaultSets` | Siempre 3 |
| — | `defaultReps` | Siempre "10" |
| — | `restTime` | Siempre 60 |

### Endpoint: `GET /api/gym/exercises/:id`

Extrae el ID numérico del formato `"wger_123"` y llama a `exerciseinfo/{id}/`.

## Carga de datos (scroll infinito)

- Al abrir el gimnasio: `loadExercises(limit: 20, offset: 0)`
- Al scrollear al fondo: `loadExercises(limit: 20, offset: _currentOffset)`
- Al buscar: `loadExercises(search: term, reset: true)`
- Al cambiar categoría: `loadExercises(category: cat, reset: true)`
- Sin caché en disco (SharedPreferences eliminado)
- Caché en memoria: el `GymProvider` retiene los ejercicios cargados mientras el widget esté vivo (IndexedStack)

## Categorías: estado final

| Categoría app | Color | Icono | wger filter |
|---|---|---|---|
| `strength` | Naranja | 💪 | `category=8,9,10,11,12,13,14` |
| `cardio` | Rojo | ❤️ | `category=15` |

## Rendimiento

- wger.de responde en ~150-300ms por página de 20 ejercicios
- Sin filtro: primer request devuelve 20 ejercicios + `total: 844` → scroll infinito
- Búsqueda: wger busca server-side en nombres y descripciones
- Debounce de 300ms en el buscador (sin cambios)
- MongoDB ya no almacena ejercicios → base de datos más liviana, conexiones más rápidas

---

# Cambio: wger.de proxy → ExerciseDB + wger fallback

## Fecha
2026-07-21

## Motivación
- wger.de solo tiene imagen para ~31% de los 844 ejercicios
- GIPHY API como fallback de imágenes no funcionó: las búsquedas devolvían GIFs irrelevantes (cachetadas, chistes)
- **ExerciseDB (RapidAPI)** tiene ~1,300 ejercicios con **GIFs animados reales** del ejercicio
- Free tier de RapidAPI: 100 requests/día. Como el seed hace **10 paginaciones** (`limit=130`), alcanza para una sola corrida
- Después del seed, **nada más habla con RapidAPI** — todo vive en MongoDB

## Qué cambió

### Antes
```
Flutter App → Backend (proxy) → wger.de API (en vivo)
```
- Backend proxy a wger en cada request de ejercicios
- `imageUrl` = foto estática JPEG de wger (31% cobertura)
- Sin GIFs animados

### Después
```
Seed (1 sola vez):
  ExerciseDB (RapidAPI, 10 requests) → traduce con MyMemory → MongoDB: Exercise collection

Runtime:
  Flutter App → Backend → MongoDB.find() (ExerciseDB data, GIFs animados)
                            ↓ fallback
                           wger.de proxy (para los no cubiertos por ExerciseDB)
```

### Modelo `Exercise` en MongoDB

```js
{
  externalId: 'exercisedb_001',  // primary key, indexed
  source: 'exercisedb' | 'wger',
  name: 'Push Up',
  nameSpanish: 'Flexión de brazos',  // traducido con MyMemory
  category: 'strength' | 'cardio',
  bodyPart: 'chest',         // ExerciseDB
  target: 'pectorals',       // ExerciseDB
  equipment: 'body weight',  // ExerciseDB
  gifUrl: 'https://...gif',  // ✅ ExerciseDB GIF (primary)
  imageUrl: '',              // wger static image (fallback)
  instructions: ['Step 1...', 'Step 2...'],         // en inglés
  instructionsSpanish: ['Paso 1...', 'Paso 2...'],  // traducido
  description: '...',
  descriptionSpanish: '...',
  defaultSets: 3,
  defaultReps: '10',
  restTime: 60
}
```

### Backend

- `backend/models/Exercise.js` — Schema unificado ExerciseDB + wger
- `backend/seed-exercisedb.js` — Script de seed (10 paginaciones, traduce con MyMemory)
- `backend/routes/gym.js` — `GET /exercises`:
  1. Si hay documentos en `Exercise`, busca en MongoDB
  2. Si no hay resultados y no hay búsqueda → fallback a wger.de
  3. Si no hay datos en MongoDB en absoluto → wger.de directo
- `GET /exercises/:id`:
  - `exercisedb_*` → MongoDB
  - `wger_*` → wger.de proxy
  - sin prefijo → busca en MongoDB, fallback a wger
- Helper `exerciseToResponse()` mapea MongoDB Exercise → JSON para Flutter (incluye `gifUrl || imageUrl` como `imageUrl`)

### Flutter

- **Eliminado**: `lib/services/giphy_service.dart` y `lib/widgets/exercise_image.dart`
- `Exercise` model: **sin cambios** — el backend ahora sirve GIFs en el campo `imageUrl`
- `CachedNetworkImage` ahora muestra GIFs animados directamente (soporte nativo en Flutter)
- Pantallas: `exercise_library_screen.dart` y `exercise_detail_sheet.dart` vuelven a `CachedNetworkImage` directo con placeholder

## Cobertura

| Fuente | GIF/Imagen | % |
|---|---|---|
| ExerciseDB GIF animado | ✅ Real, animado, demostrativo | ~95% de los 1,300 ejercicios seedeados |
| wger.de fallback | 📷 Foto estática | ~31% (de los 844 de wger, los que ExerciseDB no cubre) |
| Placeholder | 🚫 Icono de categoría | <5% |

## Cómo ejecutar el seed

1. Crear cuenta en https://rapidapi.com/ y subscribirse a **ExerciseDB** (free tier)
2. Copiar la API key de RapidAPI
3. Ejecutar:
   ```bash
   cd backend
   RAPIDAPI_KEY=tu_key_aqui npm run seed-exercisedb
   ```
4. Esperar ~5-10 min (1,300 ejercicios × traducción MyMemory con delay 250ms = ~5min de traducción)
5. Reiniciar el backend: `npm start`

## Verificación

```bash
# Backend debe tener ejercicios seedeados
mongo> db.exercises.countDocuments()
# Esperado: 1300

# Endpoint de prueba
curl -H "Authorization: Bearer TOKEN" http://localhost:3000/api/gym/exercises?limit=5
# Esperado: 5 ejercicios con gifUrl poblado
```

## Decisiones de diseño

- **MyMemory en seed, no en runtime**: traduce una sola vez, no en cada request. Rate limit de MyMemory (1000/día) no es problema
- **GIF como `imageUrl`**: el campo `imageUrl` del backend ahora entrega GIF cuando viene de ExerciseDB, foto cuando viene de wger. Flutter no necesita saber de dónde viene
- **wger como fallback secundario**: mantiene cobertura de ~5-10% de ejercicios que ExerciseDB no tiene
- **Sin re-importación runtime**: después del seed inicial, no se vuelve a llamar a ExerciseDB ni a wger en cada request. La fuente de verdad es MongoDB
