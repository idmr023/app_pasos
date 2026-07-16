# Cambios a revisar

## Pendientes de release

| Fecha | Tipo | Descripción | BD | Rompe? | Estado |
|-------|------|-------------|----|--------|--------|
| 2026-07-16 | Frontend | Fix spinner infinito en pantalla de estadísticas | No | No | Desplegado |
| 2026-07-16 | Frontend | Fix UI: texto sobresale botones gimnasio (NeonButton padding + Flexible) | No | No | Desplegado |
| 2026-07-16 | Frontend | Fix rendimiento: CachedNetworkImage en GIFs ejercicios + quitar llamadas duplicadas | No | No | Desplegado |
| 2026-07-16 | Frontend | Fix api.dart: leer --dart-define BACKEND_URL en vez de ignorarlo | No | No | Desplegado |
| 2026-07-16 | Frontend | Fix perfil: error state visible + diálogo info XP al tocar nivel | No | No | Desplegado |
| 2026-07-16 | Backend | Fix xp.js: llamar recalculateXp en GET /xp para persistir datos | No | No | Desplegado |

## Historial de cambios desplegados

| Fecha | Tipo | Descripción | BD | Rompe? | Estado |
|-------|------|-------------|----|--------|--------|
| 2026-07-13 | Ambos | Salir/eliminar reto + estadísticas con gráfica de barras | Sí (endpoint nuevo) | No | Desplegado |
| 2026-07-13 | Ambos | Perfil de usuario, duración del reto, tabs activos/finalizados, recordatorio diario, compartir resultado | Sí (duration, endDate, profile PUT) | No | Desplegado |
| 2026-07-12 | Frontend | Configurar app para Android físico (INTERNET permission, URL Render, timeout 60s) | No | No | Desplegado |
