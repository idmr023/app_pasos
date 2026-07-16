# Sistema de Niveles y Experiencia (XP)

## Visión General

Cada usuario gana experiencia (XP) al registrar pasos. Con suficiente XP sube de nivel y desbloquea recompensas (títulos y avatares especiales) cada 10 niveles.

---

## Fórmulas

### 1 XP = 10 pasos

Cada 10 pasos registrados en cualquier reto = 1 punto de experiencia.

### XP necesario para subir de nivel

Para pasar del nivel **N** al nivel **N+1** se necesita:

```
XP_requerido = 1000 × (N + 1)
```

| De nivel | A nivel | XP necesario | XP acumulado total |
|---|---|---|---|
| 0 | 1 | 1,000 | 1,000 |
| 1 | 2 | 2,000 | 3,000 |
| 2 | 3 | 3,000 | 6,000 |
| 3 | 4 | 4,000 | 10,000 |
| ... | ... | ... | ... |
| 9 | 10 | 10,000 | 55,000 |
| 19 | 20 | 20,000 | 210,000 |
| 49 | 50 | 50,000 | 1,275,000 |

Fórmula de XP total para nivel L:

```
XP_total(L) = 1000 × L × (L + 1) / 2
```

### Cálculo del nivel actual

```javascript
function levelFromXp(totalXp) {
  let level = 0;
  while (xpForLevel(level + 1) <= totalXp) level++;
  return level;
}
```

---

## Recompensas por Nivel

Cada 10 niveles el usuario desbloquea una recompensa que incluye:
- **Título**: se muestra en el perfil junto al nombre
- **Avatar**: nuevo icono disponible en el selector de avatar

| Nivel | Título | Avatar | XP total necesario |
|---|---|---|---|
| 10 | Caminante | `walker` | 55,000 |
| 20 | Maratonista | `marathon` | 210,000 |
| 30 | Ultramaratonista | `ultra` | 465,000 |
| 40 | Leyenda | `legend` | 820,000 |
| 50 | Titán | `titan` | 1,275,000 |

### Cómo reclamar

1. El usuario ve la recompensa disponible en la sección "Recompensas" del perfil
2. Toca "RECLAMAR"
3. El backend:
   - Verifica que el nivel sea suficiente
   - Guarda el claim en `UserReward`
   - Actualiza `title` y `avatar` del usuario
4. La UI se actualiza automáticamente

---

## Endpoints API

### `GET /api/xp`

Devuelve el estado actual de XP del usuario:

```json
{
  "xp": 45000,
  "level": 9,
  "title": "",
  "progress": {
    "earned": 45000,
    "needed": 10000,
    "percent": 82
  },
  "rewards": [
    {
      "level": 10,
      "title": "Caminante",
      "avatar": "walker",
      "unlocked": false,
      "claimed": false
    },
    ...
  ]
}
```

### `GET /api/xp/rewards`

Lista todas las recompensas con estado:

```json
{
  "rewards": [...],
  "level": 9,
  "xp": 45000
}
```

### `POST /api/xp/claim/:rewardKey`

Reclama una recompensa (`reward_10`, `reward_20`, etc.):

```json
{
  "success": true,
  "reward": { "level": 10, "title": "Caminante", "avatar": "walker" },
  "user": { ... datos actualizados del usuario ... }
}
```

---

## Integración con Steps

Cuando el usuario guarda pasos (`POST /api/steps`), el backend automáticamente:

1. Calcula el total de pasos del usuario (sumando todos sus StepEntry)
2. Convierte a XP (pasos / 10)
3. Calcula el nuevo nivel
4. Actualiza `req.user.xp`, `req.user.level`, `req.user.title`
5. Guarda el usuario

Esto ocurre **inline** en el mismo request - no hay jobs asíncronos ni delays.

---

## Cómo se Muestra en la UI

### Perfil (ProfileScreen)

```dart
// Sección de nivel
_buildLevelSection(user, xpProv) → {
  Avatar + Nombre + Título
  Nivel X
  Barra de progreso: ████████░░  XP earned / XP needed
}

// Sección de recompensas
_buildRewardsSection(xpProv) → {
  🔓 Nivel 10: Caminante  [RECLAMAR]
  🔒 Nivel 20: Maratonista  (gris)
  ...
}
```

### Provider

```dart
class XpProvider extends ChangeNotifier {
  int xp, level;
  String title;
  Map progress;       // {earned, needed, percent}
  List<Reward> rewards;

  void setToken(String token);
  Future<void> loadXp();
  Future<bool> claimReward(String rewardKey);
}
```

### Servicio

```dart
class XpService {
  Future<Map> getXp();
  Future<Map> getRewards();
  Future<Map> claimReward(String rewardKey);
}
```
