# App Pasos

Flutter app + Node.js backend para competencias de pasos entre amigos + gimnasio con rutinas y temporizador.

## Estructura

```
app_pasos/       → Flutter app (Android, iOS, Web, Windows, Linux, macOS)
backend/         → Node.js/Express API + MongoDB
docs/            → Documentación para el agente (ARCHITECTURE, NAVIGATION, GYM_MODULE, XP_LEVELS)
```

## Navegación Principal

BottomNavigationBar con 4 tabs:
- **Pasos** 🏃 — HomeScreen: contador de pasos, retos activos/finalizados, crear/unirse a retos
- **Gimnasio** 💪 — GymScreen: racha semanal, rutinas, ejercicios, temporizador real
- **Chat** 🤖 — ChatScreen: placeholder del coach IA (no funcional aún)
- **Perfil** 👤 — ProfileScreen: nivel XP, recompensas, editar nombre/avatar, recordatorio

## Comandos

```bash
# Backend
cd backend && npm run dev        # Iniciar servidor (puerto 3000)
cd backend && npm run seed       # Poblar DB con usuarios + 27 ejercicios predefinidos

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
- **Librería de ejercicios**: 27 ejercicios predefinidos con GIFs, en 4 categorías (calentamiento, fuerza, cardio, flexibilidad)
- **Rutinas**: crear/editar rutinas seleccionando ejercicios, configurando sets, reps y descanso. Soporta rutinas de calentamiento.
- **Workout**: ejecutar rutinas paso a paso con temporizador real basado en DateTime.now() (preciso incluso con celular bloqueado)
- **Racha semanal**: seguimiento de semanas consecutivas entrenando
- **Wakelock**: pantalla encendida durante el workout
- **Alarma**: sonido al terminar cada timer

## Backend Rutas

| Ruta | Métodos |
|---|---|
| `/api/auth` | POST register, POST login, GET/PUT profile |
| `/api/challenges` | POST create, POST join, GET list/detail, POST leave, DELETE |
| `/api/steps` | POST save, GET list/calendar, GET analytics |
| `/api/xp` | GET xp+level+progress, GET rewards, POST claim |
| `/api/gym` | GET exercises, CRUD routines, POST workouts, GET streak |

## Seguridad

- JWT almacenado con `flutter_secure_storage` (Android Keystore)
- No hardcodear tokens ni secrets en el código
