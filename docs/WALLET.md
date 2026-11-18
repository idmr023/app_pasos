# Economía de pasos (monedero)

Los pasos registrados en los retos son la moneda de la app: se gastan en la tienda
(cosméticos del Sprint, portadas premium, stickers) o se apuestan en retos contra amigos.

## Saldo

```
saldo = earned + net
earned = Σ DailyStepCredit.steps            (pasos ganados)
net    = Σ movimientos (gastos < 0, premios/reembolsos > 0)
```

### Regla de pasos ganados (sin doble conteo)

El mismo día suele registrarse en varios retos a la vez (los mismos pasos). Por eso:

- **Por usuario y día cuenta el MÁXIMO** registrado entre todos sus retos, no la suma.
  (20.000 pasos hoy en el reto A y 20.000 en el reto B = 20.000 pasos ganados.)
- Se guarda en `DailyStepCredit {user, day, steps}` con `$max`: **nunca baja**. Borrar un reto
  (que borra sus `StepEntry`) o corregir pasos a la baja no quita saldo ya acreditado, así que el saldo
  nunca puede quedar negativo por cambios en los pasos.
- Se sincroniza (idempotente) al guardar pasos (`POST /api/steps`, sin bloquear la respuesta), antes de
  cualquier operación del monedero y antes de borrar/abandonar un reto.
- Nota: el XP y los intentos del Sprint siguen usando la suma de `StepEntry` (sin cambios).

## Atomicidad e idempotencia

Cada movimiento es **una sola operación atómica** sobre el documento `Wallet` del usuario:

```js
Wallet.findOneAndUpdate(
  { user, 'ops.k': { $ne: key }, $expr: { $gte: [{ $add: ['$earned', '$net'] }, coste] } },
  { $inc: { net: amount }, $push: { ops: { k: key, a: amount, t: type, r: ref, at } } })
```

- La condición de saldo y el cobro van juntos → **sin saldo negativo** con peticiones concurrentes.
- `key` es la clave de idempotencia (`purchase:<itemId>`, `stake:…`, `refund:…`, `win:<challengeId>`):
  la misma operación nunca se aplica dos veces (doble compra → 409, doble pago → ignorado).
- No necesita transacciones de MongoDB (funciona con standalone / memory server).
- `Wallet.ops` es el diario de escritura; **`WalletTransaction`** (user, key, amount, type, ref, createdAt;
  único `{user, key}`) es su copia consultable para el historial. Si el proceso muere entre ambas
  escrituras, `GET /api/wallet` reconcilia las que falten. Invariante auditable:
  `saldo = earned + Σ WalletTransaction.amount`.
- Tipos: `purchase | wager_stake | wager_win | wager_refund`.

## Tienda (`backend/services/walletService.js` → `CATALOG`)

| Tipo | Artículos (precio en pasos) | Efecto |
|---|---|---|
| `skin` (equipable) | Clásica 0 (de serie), Fuego 5.000, Océano 5.000, Selva 8.000, Neón 15.000, Oro olímpico 25.000 | Colores del corredor en el Sprint |
| `trail` (equipable) | Chispas 6.000, Fuego 9.000, Arcoíris 12.000, Cometa 15.000 | Estela detrás del corredor |
| `cover` | Neón Nocturno 8.000, Atardecer 8.000, Podio 10.000, Dorsal Retro 10.000, Foto + Mapa 12.000 | Desbloquea la portada en Share Aura. **Gratis: Revista, Minimal, Polaroid** (y los 5 moldes clásicos) |
| `stickers` | Pack Running 4.000, Pack Fiesta 4.000, Pack Pro 6.000 | Stickers extra en el editor de portadas |

Inventario = artículos gratis + compras (derivado del diario). Equipado: `Wallet.equipped {skin, trail}`.
Los temas de acento de la app (opcionales) no se implementaron.

Cliente: el contenido visual de cada id vive en `lib/games/sprint/sprint_cosmetics.dart` (skins/estelas) y
`lib/models/wallet.dart` (`premiumCoverItems`, `premiumStickerPacks`, `fallbackPrices`). Mantener los ids
sincronizados con `CATALOG`.

## Retos con apuesta

- `POST /api/challenges { duration, wager }` (entero 0–100.000). El creador apuesta al crear; sin saldo →
  400 `Saldo insuficiente: necesitas X pasos y tienes Y` y el reto **no** se crea.
- `POST /api/challenges/join`: el rival apuesta lo mismo; sin saldo → 400
  `Este reto tiene una apuesta de X pasos. Saldo insuficiente…` y la unión se revierte (el reto sigue esperando).
- Al terminar (`endDate` pasada) se **liquida**: quien tenga más pasos en el reto gana el **bote = 2 × apuesta**.
  **Empate (incluido 0-0) → cada uno recupera su apuesta.**
- Liquidación perezosa e idempotente: se ejecuta en `GET /api/challenges`, `GET /api/challenges/:id` y
  `GET /api/wallet` (el ganador cobra aunque no abra el reto). Pago con clave `win:<challengeId>` → una sola vez.
- `Challenge.wagerState`: `none | open | paid | refunded` (+ `wagerWinner`, `wagerSettledAt`, `joinCount`).
  La transición `open → paid/refunded` es atómica y actúa de cerrojo entre "pagar" y "reembolsar".

| Caso | Regla |
|---|---|
| Creador borra / sale de un reto **sin terminar** (en espera o activo) | Reembolso a ambos |
| Rival abandona un reto activo | El rival recupera su apuesta; la del creador sigue en juego. Si otro (o él mismo) se une, apuesta de nuevo (clave `stake:<id>:<user>:<joinCount>`) |
| Borrar / abandonar un reto **ya terminado** | Primero se liquida (el ganador cobra); no hay reembolso |
| Reto terminado con apuesta ya liquidada que vuelve a quedar "en espera" | No admite nuevas uniones con apuesta (400) |

## Boost del Sprint

`GET /api/game/fuel` incluye `shield: { active, stepsRequired: 8000, stepsToday }`. Con ≥ 8.000 pasos hoy
(sin doble conteo entre retos) las **carreras oficiales** empiezan con un **escudo**: el primer choque sin
turbo rompe el escudo en lugar de terminar la carrera. Visible en el hub (tarjeta "Escudo de pasos"),
en el HUD (chip 🛡 x1) y como anillo azul alrededor del corredor.

## API (`/api/wallet`, auth)

| Endpoint | Respuesta |
|---|---|
| `GET /` | `balance, earned, spent, credited, transactions[{id,type,amount,ref,label,createdAt}] (últimos 30), inventory[ids], equipped{skin,trail}` |
| `GET /catalog` | `items[{id,type,slot?,name,description,price,owned,equipped}], equipped` |
| `POST /purchase {itemId}` | 201 `{item, balance}` · 404 no existe · 409 ya lo tienes / gratis · 400 saldo insuficiente (`balance`, `required`) |
| `GET /inventory` | `items[], equipped` |
| `POST /equip {slot: 'skin'|'trail', itemId|null}` | `{equipped}` · 403 si no es tuyo · 400 hueco incorrecto. `null` en skin → Clásica; en trail → sin estela |

## Flutter

```
lib/models/wallet.dart                    → WalletItem, WalletTransaction, portadas premium, packs de stickers
lib/services/wallet_service.dart          → HTTP /api/wallet
lib/providers/wallet_provider.dart        → WalletProvider (registrado en main.dart)
lib/widgets/wallet_widgets.dart           → ensureWalletLoaded, WalletBalanceChip, LockedPriceBadge, showWalletPurchaseSheet
lib/screens/wallet/wallet_screen.dart     → WalletScreen() — saldo animado, Tienda / Inventario (equipar) / Historial
lib/games/sprint/sprint_cosmetics.dart    → SprintSkin / SprintTrail por id
```

- Token: `main_shell` no inicializa el provider; cada pantalla que lo usa llama
  `ensureWalletLoaded(context)` en un post-frame callback (como `GameHubScreen` con `GameProvider`).
- Chip de saldo en el hub del Sprint, Share Aura y el editor de portadas.
- Share Aura: portadas premium con candado + precio en la grilla, en el selector y en el carrusel; se pueden
  previsualizar, pero Guardar/Compartir se sustituye por "Desbloquear por N pasos" (compra en línea).
- Crear reto: selector de apuesta (sin apuesta, 1.000, 5.000, 10.000, 25.000; las que no puedes pagar se desactivan).
- La navegación a `WalletScreen` desde Explorar/Menú la cablea quien integre:
  `import 'screens/wallet/wallet_screen.dart';` → `const WalletScreen()`.
