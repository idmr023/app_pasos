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

`lib/config/api.dart` usa `String.fromEnvironment('BACKEND_URL')` con fallback local.

Prioridad:
1. `--dart-define=BACKEND_URL=...` (al compilar)
2. `http://192.168.18.15:3000/api` (fallback local para dispositivo físico)

## Android

- `AndroidManifest.xml` tiene `usesCleartextTraffic="true"` para HTTP plano
- Min SDK: definido por Flutter
- Target SDK: definido por Flutter

## Seguridad

- JWT almacenado con `flutter_secure_storage` (Android Keystore)
- No hardcodear tokens ni secrets en el código
