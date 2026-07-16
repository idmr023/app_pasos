# App Pasos 🏃💪

App móvil para competencias de pasos entre amigos + gimnasio con rutinas, temporizador real y coach IA.

## Stack

- **Frontend**: Flutter (Android, iOS, Web, Windows, Linux, macOS)
- **Backend**: Node.js + Express + MongoDB Atlas
- **Auth**: JWT + bcryptjs

## Características

### 🏃 Pasos y Retos
- Registrar pasos diarios en retos 1v1
- Código de invitación de 6 caracteres
- Calendario mensual de pasos
- Gráficas comparativas semanales/mensuales

### 💪 Gimnasio
- 27 ejercicios predefinidos con GIFs (calentamiento, fuerza, cardio, flexibilidad)
- Crear rutinas personalizadas seleccionando ejercicios
- Temporizador preciso basado en `DateTime.now()` (funciona con celular bloqueado)
- Racha de semanas consecutivas entrenando
- Pantalla encendida durante el workout (wakelock)
- Alarma sonora al finalizar cada timer

### 🏆 Experiencia y Niveles
- 1 XP por cada 10 pasos
- Sube de nivel y desbloquea títulos cada 10 niveles
- Recompensas: Caminante, Maratonista, Ultramaratonista, Leyenda, Titán

### 🤖 Coach IA
- Chat placeholder (próximamente)

## Inicio Rápido

```bash
# Backend
cd backend
npm install
npm run seed      # Poblar DB con usuarios y ejercicios
npm run dev       # Servidor en :3000

# Flutter
cd app_pasos
flutter pub get
flutter run       # Con dispositivo/emulador conectado
```

## Documentación

Ver `docs/` para documentación detallada del agente:
- `ARCHITECTURE.md` — estructura del proyecto y flujo de datos
- `NAVIGATION.md` — navegación y todas las pantallas
- `GYM_MODULE.md` — módulo de gimnasio
- `XP_LEVELS.md` — sistema de experiencia y niveles
