# App Pasos

Flutter app + Node.js backend para competencias de pasos entre amigos.

## Estructura

```
app_pasos/       → Flutter app (Android, iOS, Web, Windows, Linux, macOS)
backend/         → Node.js/Express API + MongoDB
```

## Comandos

```bash
# Backend
cd backend && npm run dev        # Iniciar servidor (puerto 3000)
cd backend && npm run seed       # Poblar DB con datos de prueba

# Flutter (Android - dispositivo físico)
cd app_pasos
flutter run --dart-define=BACKEND_URL=http://192.168.18.15:3000/api

# Flutter (Android - emulador)
flutter run --dart-define=BACKEND_URL=http://10.0.2.2:3000/api

# Build APK para compartir (con Render)
flutter build apk --dart-define=BACKEND_URL=https://app-pasos.onrender.com/api

# Build APK con ngrok
flutter build apk --dart-define=BACKEND_URL=https://url-publica.ngrok.io/api
```

## Configuración de Backend URL

`lib/config/api.dart` usa URL hardcodeada para Android físico.

Prioridad:
1. `https://app-pasos.onrender.com/api` (Android - Render)
2. `http://localhost:3000/api` (Windows/Web - local)

## Android

- `AndroidManifest.xml` tiene `usesCleartextTraffic="true"` para HTTP plano
- `AndroidManifest.xml` tiene `INTERNET` permission para release builds
- Min SDK: definido por Flutter
- Target SDK: definido por Flutter

## Funcionalidades agregadas

- **Salir/Eliminar reto**: Botón en Challenge Room. Participante sale, creador elimina.
- **Estadísticas**: Pantalla con gráfica de barras semanal/mensual comparando pasos entre competidores.
- Backend: Endpoints `POST /api/challenges/:id/leave`, `DELETE /api/challenges/:id`, `GET /api/steps/:challengeId/analytics`

## Seguridad

- JWT almacenado con `flutter_secure_storage` (Android Keystore)
- No hardcodear tokens ni secrets en el código
