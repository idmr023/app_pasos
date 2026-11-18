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

## Share Aura v4 — Portadas (implementado)

Entrada: `RouteDetailScreen` → botón Share Aura → `ShareAuraScreen(routeId)` (grilla con todos los moldes) → tocar uno abre `CoverEditorScreen` en esa plantilla.

### Plantillas (`TemplateType` en `lib/models/route_card_template.dart`)
- **Clásicas** (5): Cartógrafo, Diario, Timeline (pintadas por `AuraCardPainter`), Distancia Rey, Cyber HUD (widgets en `aura_card_builder.dart`).
- **Portadas v4** (8, `lib/widgets/aura_cover_templates.dart`, `TemplateType.isCover == true`):
  | Plantilla | Idea | Fuente por defecto |
  |---|---|---|
  | Portada Revista (`revista`) | Masthead con el título, titulares de stats, sello del día, código de barras | Playfair Display |
  | Neón Nocturno (`neonNocturno`) | Grilla synthwave, ruta con glow, píldoras neón | Orbitron |
  | Minimal (`minimal`) | Fondo crema, número gigante, grilla de stats | Montserrat |
  | Polaroid (`polaroid`) | Foto instantánea inclinada con cinta + nota adhesiva con stats | Permanent Marker |
  | Podio (`podio`) | Medalla dorada con km, confeti, podio 2-1-3 con stats | Oswald |
  | Dorsal Retro (`dorsal`) | Dorsal de carrera con imperdibles y línea de corte | Bebas Neue |
  | Foto + Mapa (`fotoMapa`) | 55% foto arriba, mapa + stats abajo, badge de km en el corte | Montserrat |
  | Atardecer (`atardecer`) | Degradado sunset + sol retro con franjas | Bebas Neue |
- Todas usan la unidad `u = ancho/100` → la previsualización y el PNG se ven idénticos.
- `CoverRoutePainter` proyecta la ruta (equirectangular con corrección `cos(lat)`), con glow y marcadores inicio/fin; submuestrea a ~1500 puntos.
- `TemplateType.accent` da el color base de cada plantilla (grilla, selector y acento por defecto).

### Personalización (`CoverStyle` en `lib/models/cover_style.dart`)
- **Foto de fondo**: galería o cámara con `image_picker`; se guarda SOLO en memoria como `Uint8List` (`XFile.readAsBytes()` + `Image.memory`, sin `dart:io` → funciona en web). No se sube al backend. Controles: oscurecer (0–0.85), desenfoque (sigma 0–15, `ImageFiltered`), zoom (1–2.5×), encuadre horizontal/vertical (`Alignment`), ajuste Rellenar/Completa (`BoxFit.cover/contain`).
- **Foto pequeña (inset)**: marco blanco inclinado en una de las 4 esquinas (todas las plantillas).
- **Estilo**: título personalizado, color de acento (10 presets o Auto), tipografía (Bebas Neue, Montserrat, Oswald, Playfair Display, Permanent Marker, Orbitron o Auto) vía `GoogleFonts.getFont`.
- **Datos**: toggles de `AuraMetricsConfig` (mapa, km, ritmo, tiempo, calorías, elevación, FC). Las portadas ocultan solas los valores en 0.
- **Stickers**: 16 emojis + 6 badges de texto ("NUEVO PR", "MODO BESTIA"...), máx. 8, arrastrables (posición en `Alignment` relativo, se exporta igual). En la pestaña Stickers se bloquea el swipe del carrusel para poder arrastrar.
- Las plantillas clásicas solo aplican foto pequeña, stickers y toggles (no foto de fondo/acento/fuente/título); el editor lo indica.
- Botón "Sorpréndeme" (dado): portada, acento y fuente al azar.

### Editor (`lib/screens/share_aura/cover_editor_screen.dart`)
- Carrusel `PageView` (viewportFraction 0.72) con escala/opacidad animadas según la página; `AnimatedSwitcher` para nombre/subtítulo; `TemplateSelector` (`lib/widgets/template_selector.dart`) sincronizado con auto-scroll.
- Exporta: `RepaintBoundary` por página → `toImage(pixelRatio: 1080 / ancho)` → PNG 1080×1920. Compartir con `share_plus` (`Share.shareXFiles`), guardar con `gal` (álbum "App Pasos"); en web "Guardar" usa compartir/descarga.
- Si `AuraData.routeTexture` es null y hay coordenadas, genera la textura de Distancia Rey en `initState`.

### Abrir desde una carrera en vivo (tracking)
```dart
Navigator.push(context, MaterialPageRoute(
  builder: (_) => CoverEditorScreen.forRun(
    distanceKm: 5.2,
    duration: const Duration(minutes: 28, seconds: 10),
    pace: '5:25',            // opcional, formato m:ss sin "/km"; si es null se calcula
    routePoints: points,     // List<LatLng> (latlong2)
    title: 'Carrera en vivo', // opcional
  ),
));
```
Equivale a `CoverEditorScreen(data: AuraData.fromRun(...))` (sin mapa 3D de backend; abre en Neón Nocturno).

### Permisos
- iOS `Info.plist`: `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription` (gal).
- Android: `image_picker` no requiere permisos (no se declara `CAMERA`); `WRITE_EXTERNAL_STORAGE` con `maxSdkVersion="29"` para que `gal` guarde en Android ≤ 9.

## Por implementar (futuras fases)
- **Editor visual tipo Canva**: drag-and-drop de elementos (ruta, título, stats), posiciones libres.
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