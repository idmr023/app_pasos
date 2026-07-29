# ROUTE_EDITOR — Módulo de Rutas

Editor de visualización de rutas GPS importadas (GPX/TCX de Strava, Garmin, Coros, etc.) con card personalizable.

## Estado actual (implementado)

### Importación
- **GPX**: parseo client-side con paquete `gpx` (`lib/utils/route_parser.dart` → `RouteParser.parseGpx`).
- **TCX**: parseo con paquete `xml` (`RouteParser.parseTcx`).
- Selector de archivos con `file_picker` (extensiones `gpx`, `tcx`).
- Detección automática de tipo de actividad (run/ride/walk/hike) desde metadatos del archivo.
- Edición del título y tipo de actividad antes de guardar.
- Cálculo de stats (distancia Haversine, duración, pace) en preview antes de subir.

### Visualización
- `RouteMapPainter` (`lib/widgets/routes/route_map_painter.dart`): CustomPainter que proyecta lat/lng al canvas con:
  - Cálculo de bounds (min/max lat/lng).
  - Escala uniforme preservando aspect ratio de la ruta (sin distorsión).
  - Padding automático proporcional al grosor de línea.
  - Polilínea con sombra (blur), strokeCap/strokeJoin redondos.
  - Estilos: sólido, gradiente (sombreado diagonal), punteado (segmentos).
  - Marcadores inicio (verde) / fin (naranja) con borde y centro blanco.
- `ElevationProfile` (`lib/widgets/routes/elevation_profile.dart`): perfil de elevación mini como área con gradient fill + línea.
- `RouteCardPreview` (`lib/widgets/routes/route_card_preview.dart`): card completa con:
  - Fondo con gradient sutil entre `backgroundColor` y un tono oscurecido.
  - Ruta (CustomPaint) en tercio superior.
  - Badge de tipo de actividad (run/ride/...).
  - Título + fecha (formato: `26 jul 2026`).
  - Fila de stats (Distancia, Tiempo, Ritmo, Elevación, FC, Calorías) — elegibles vía `showStats`.
  - 6 fuentes: Montserrat, Inter, Oswald, Raleway, Poppins, Bebas Neue.
  - Watermark opcional.

### Personalización (RouteShareScreen)
- Color de la ruta: 7 presets + seleccionables.
- Color de fondo: 7 presets oscuros.
- Fuente del texto (6 Google Fonts).
- Grosor de línea (slider 2–10).
- Estilo de línea: sólido / gradiente / punteado.
- Stats visibles: toggles por cada stat (distancia/tiempo/pace/elev/FC/cal).
- Guardar diseño en el backend (persistente por ruta).

### Persistencia (backend)
- Modelo `Route` (`backend/models/Route.js`): coordenadas, stats, metadata, `design` (estilo guardado).
- Endpoints en `backend/routes/routes.js`:
  - `GET /api/routes` — lista (sin coordenadas, respuesta ligera vía `.select('-coordinates')`).
  - `GET /api/routes/:id` — detalle completo con coordenadas.
  - `POST /api/routes` — crear (recibe coordenadas parseadas del cliente, calcula stats en servidor con Haversine).
  - `PUT /api/routes/:id` — actualizar título/design.
  - `DELETE /api/routes/:id`.
- Índice `{ user: 1, createdAt: -1 }` para listar rutas del usuario eficientemente.
- Stats calculadas servidor-side (Haversine para distancia, suma de diferencias positivas para elevation gain, timestamps para duración/pace).

## Flujo del usuario
1. **Tab Rutas** → `RouteLibraryScreen`: lista de rutas importadas con stats en chips + botón "Importar".
2. **Importar** → `RouteImportScreen`: elegir archivo, parsear, configurar título/tipo, guardar.
3. **Tocar una ruta** → `RouteShareScreen`: card preview (aspect 0.75) + panel de personalización + guardar diseño.

## Por implementar (futuras fases)
- **Editor visual tipo Canva**: drag-and-drop de elementos (ruta, título, stats), posiciones libres.
- **Generación de imagen shareable PNG**: `renderRouteImage` ya existe como helper en `route_map_painter.dart`; falta integrar `PictureRecorder` completo con texto + fondo para exportar a alta resolución (Instagram Post 1080×1080, Story 1080×1920, etc.) y compartir vía `share_plus`.
- **Templates**: guardar/cargar configuraciones de diseño predefinidas.
- **Strava OAuth + sync**: conectar cuenta de Strava para importar actividades automáticamente (scopes: `activity:read_all`), auto-refresh de tokens.

## Dependencias nuevas (pubspec.yaml)
- `gpx: ^2.4.1` — parsear GPX (waypoints, tracks, elevación, time).
- `xml: ^7.0.1` — parsear TCX (XML de Garmin) con `namespaceUri: '*'` para matching tolerante.
- `file_picker: ^8.1.2` — selector de archivos del dispositivo.

## Notas técnicas
- **Por qué parseo client-side** (no multer): GPX/TCX son XML de texto; el cliente los lee como string y parsea con paquetes Dart dedicados. Backend solo recibe JSON con coordenadas ya parseadas — sin Configuración de `multer` ni dependencias adicionales en Node.
- **`color.toARGB32()`** (Flutter 3.27+): reemplazo del deprecado `color.value` para obtener el entero ARGB y serializar a hex `#RRGGBB`.
- **`withValues(alpha:)`**: reemplazo del deprecado `withOpacity()` en todo el codebase.
- **`RouteDesign` inmutable con `copyWith`**: patrón idiomático Dart; en el editor se reemplaza el objeto entero vía `setState(() => _design = _design.copyWith(...))`.