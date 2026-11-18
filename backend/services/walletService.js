// Economía de pasos: saldo, tienda, inventario y apuestas de retos.
// Reglas y decisiones documentadas en docs/WALLET.md.
const mongoose = require('mongoose');
const Wallet = require('../models/Wallet');
const WalletTransaction = require('../models/WalletTransaction');
const DailyStepCredit = require('../models/DailyStepCredit');
const StepEntry = require('../models/StepEntry');
const Challenge = require('../models/Challenge');

// ───────────── Catálogo (definido en el servidor, precios en pasos) ─────────────
// slot: hueco equipable ('skin' | 'trail'); los demás tipos solo se desbloquean.
const CATALOG = [
  // Sprint: equipaciones del corredor
  { id: 'skin_classic', type: 'skin', slot: 'skin', name: 'Clásica', description: 'Equipación azul de serie', price: 0 },
  { id: 'skin_fuego', type: 'skin', slot: 'skin', name: 'Fuego', description: 'Camiseta roja y zapatillas naranjas', price: 5000 },
  { id: 'skin_oceano', type: 'skin', slot: 'skin', name: 'Océano', description: 'Turquesa con detalles blancos', price: 5000 },
  { id: 'skin_selva', type: 'skin', slot: 'skin', name: 'Selva', description: 'Verde esmeralda de trail running', price: 8000 },
  { id: 'skin_neon', type: 'skin', slot: 'skin', name: 'Neón', description: 'Magenta fluorescente para correr de noche', price: 15000 },
  { id: 'skin_oro', type: 'skin', slot: 'skin', name: 'Oro olímpico', description: 'Dorado de campeón', price: 25000 },
  // Sprint: estelas
  { id: 'trail_chispas', type: 'trail', slot: 'trail', name: 'Chispas', description: 'Estela de chispas doradas', price: 6000 },
  { id: 'trail_fuego', type: 'trail', slot: 'trail', name: 'Fuego', description: 'Estela de llamas', price: 9000 },
  { id: 'trail_arcoiris', type: 'trail', slot: 'trail', name: 'Arcoíris', description: 'Estela multicolor', price: 12000 },
  { id: 'trail_cometa', type: 'trail', slot: 'trail', name: 'Cometa', description: 'Estela azul eléctrico', price: 15000 },
  // Portadas premium (Share Aura). Gratis: revista, minimal, polaroid.
  { id: 'cover_neon_nocturno', type: 'cover', name: 'Portada Neón Nocturno', description: 'Plantilla de portada premium', price: 8000 },
  { id: 'cover_atardecer', type: 'cover', name: 'Portada Atardecer', description: 'Plantilla de portada premium', price: 8000 },
  { id: 'cover_podio', type: 'cover', name: 'Portada Podio', description: 'Plantilla de portada premium', price: 10000 },
  { id: 'cover_dorsal', type: 'cover', name: 'Portada Dorsal Retro', description: 'Plantilla de portada premium', price: 10000 },
  { id: 'cover_foto_mapa', type: 'cover', name: 'Portada Foto + Mapa', description: 'Plantilla de portada premium', price: 12000 },
  // Packs de stickers del editor de portadas
  { id: 'stickers_running', type: 'stickers', name: 'Pack Running', description: '8 stickers para corredores', price: 4000 },
  { id: 'stickers_fiesta', type: 'stickers', name: 'Pack Fiesta', description: '8 stickers para celebrar', price: 4000 },
  { id: 'stickers_pro', type: 'stickers', name: 'Pack Pro', description: 'Insignias de atleta pro', price: 6000 },
];
const CATALOG_BY_ID = Object.fromEntries(CATALOG.map(i => [i.id, i]));
const FREE_ITEMS = CATALOG.filter(i => i.price === 0).map(i => i.id);
const DEFAULT_EQUIPPED = { skin: 'skin_classic', trail: null };
const SLOTS = ['skin', 'trail'];

const MAX_WAGER = 100000;
// Sprint: con estos pasos hoy, las carreras oficiales empiezan con un escudo.
const SHIELD_STEPS = 8000;
const RECENT_TX_LIMIT = 30;

class WalletError extends Error {
  constructor(status, message, extra = {}) {
    super(message);
    this.status = status;
    this.extra = extra;
  }
}

function toId(id) {
  return typeof id === 'string' ? new mongoose.Types.ObjectId(id) : id;
}

// 12345 → "12.345" (sin depender de los datos ICU de Node)
function formatSteps(n) {
  return String(Math.round(n)).replace(/\B(?=(\d{3})+(?!\d))/g, '.');
}

// ───────────── Saldo ─────────────

async function ensureWallet(userId) {
  try {
    await Wallet.updateOne({ user: userId }, { $setOnInsert: { user: userId } }, { upsert: true });
  } catch (e) {
    if (e.code !== 11000) throw e; // upsert concurrente: el otro ya lo creó
  }
}

// Acredita los pasos del usuario: por día, el máximo entre sus retos ($max, nunca baja).
async function syncEarned(userId) {
  const uid = toId(userId);
  const perDay = await StepEntry.aggregate([
    { $match: { user: uid } },
    { $group: { _id: '$date', steps: { $max: '$steps' } } }
  ]);
  if (perDay.length > 0) {
    await DailyStepCredit.bulkWrite(perDay.map(d => ({
      updateOne: {
        filter: { user: uid, day: d._id },
        update: { $max: { steps: d.steps } },
        upsert: true
      }
    })), { ordered: false }).catch(e => {
      // Upserts concurrentes del mismo día: el $max del otro ya quedó aplicado.
      if (e.code !== 11000 && !/E11000/.test(e.message || '')) throw e;
    });
  }
  const total = await DailyStepCredit.aggregate([
    { $match: { user: uid } },
    { $group: { _id: null, total: { $sum: '$steps' } } }
  ]);
  const earned = total[0]?.total || 0;
  await ensureWallet(uid);
  await Wallet.updateOne({ user: uid }, { $max: { earned } });
  return earned;
}

// Pasos de hoy sin contar dos veces los mismos pasos registrados en varios retos.
async function getTodayStepsDeduped(userId) {
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const end = new Date(start);
  end.setDate(end.getDate() + 1);
  const uid = toId(userId);
  const [live, credited] = await Promise.all([
    StepEntry.aggregate([
      { $match: { user: uid, date: { $gte: start, $lt: end } } },
      { $group: { _id: '$date', steps: { $max: '$steps' } } },
      { $group: { _id: null, total: { $sum: '$steps' } } }
    ]),
    // Lo ya acreditado hoy sigue contando aunque se borre el reto
    DailyStepCredit.aggregate([
      { $match: { user: uid, day: { $gte: start, $lt: end } } },
      { $group: { _id: null, total: { $sum: '$steps' } } }
    ]),
  ]);
  return Math.max(live[0]?.total || 0, credited[0]?.total || 0);
}

// Copia al ledger las operaciones del diario que falten (p. ej. si el proceso
// murió entre la operación atómica y la escritura en WalletTransaction).
async function reconcileLedger(wallet) {
  const count = await WalletTransaction.countDocuments({ user: wallet.user });
  if (count >= wallet.ops.length) return;
  await WalletTransaction.bulkWrite(wallet.ops.map(op => ({
    updateOne: {
      filter: { user: wallet.user, key: op.k },
      update: { $setOnInsert: { user: wallet.user, key: op.k, amount: op.a, type: op.t, ref: op.r, createdAt: op.at } },
      upsert: true
    }
  })), { ordered: false }).catch(() => {});
}

/**
 * Aplica un movimiento de forma atómica e idempotente.
 * amount < 0 exige saldo suficiente. Devuelve { applied, balance }.
 * applied=false si la clave ya se había aplicado (no se cobra/paga dos veces).
 * Lanza WalletError(400) si no hay saldo suficiente.
 */
async function applyOp(userId, { key, amount, type, ref = '' }) {
  const uid = toId(userId);
  await ensureWallet(uid);
  const op = { k: key, a: amount, t: type, r: String(ref), at: new Date() };
  const filter = { user: uid, 'ops.k': { $ne: key } };
  if (amount < 0) {
    filter.$expr = { $gte: [{ $add: ['$earned', '$net'] }, -amount] };
  }
  const updated = await Wallet.findOneAndUpdate(
    filter,
    { $inc: { net: amount }, $push: { ops: op } },
    { new: true, projection: { earned: 1, net: 1 } }
  );
  if (!updated) {
    const w = await Wallet.findOne({ user: uid }, { earned: 1, net: 1, ops: { $elemMatch: { k: key } } });
    const balance = w ? w.earned + w.net : 0;
    if (w && w.ops && w.ops.length > 0) return { applied: false, balance };
    throw new WalletError(400,
      `Saldo insuficiente: necesitas ${formatSteps(-amount)} pasos y tienes ${formatSteps(balance)}`,
      { balance, required: -amount });
  }
  await WalletTransaction.updateOne(
    { user: uid, key },
    { $setOnInsert: { user: uid, key, amount, type, ref: op.r, createdAt: op.at } },
    { upsert: true }
  ).catch(e => { if (e.code !== 11000) console.error('Ledger:', e.message); });
  return { applied: true, balance: updated.earned + updated.net };
}

function ownedFromOps(ops) {
  const owned = new Set(FREE_ITEMS);
  for (const op of ops || []) {
    if (op.t === 'purchase') owned.add(op.r);
  }
  return owned;
}

function equippedOf(wallet) {
  return {
    skin: wallet?.equipped?.skin || DEFAULT_EQUIPPED.skin,
    trail: wallet?.equipped?.trail || DEFAULT_EQUIPPED.trail,
  };
}

async function getWalletSummary(userId) {
  const uid = toId(userId);
  await syncEarned(uid);
  await settlePendingForUser(uid).catch(e => console.error('Settle wagers:', e.message));
  const wallet = await Wallet.findOne({ user: uid }).lean();
  await reconcileLedger(wallet);
  const transactions = await WalletTransaction.find({ user: uid })
    .sort({ createdAt: -1, _id: -1 })
    .limit(RECENT_TX_LIMIT)
    .lean();
  let spent = 0;
  let won = 0;
  for (const op of wallet.ops) {
    if (op.a < 0) spent += -op.a; else won += op.a;
  }
  return {
    balance: wallet.earned + wallet.net,
    earned: wallet.earned,
    spent,
    credited: won,
    transactions: transactions.map(t => ({
      id: t._id, type: t.type, amount: t.amount, ref: t.ref, createdAt: t.createdAt,
      label: transactionLabel(t)
    })),
    inventory: [...ownedFromOps(wallet.ops)],
    equipped: equippedOf(wallet),
  };
}

function transactionLabel(t) {
  switch (t.type) {
    case 'purchase': return `Compra: ${CATALOG_BY_ID[t.ref]?.name || t.ref}`;
    case 'wager_stake': return 'Apuesta de reto';
    case 'wager_win': return 'Premio de reto ganado';
    case 'wager_refund': return 'Reembolso de apuesta';
    default: return t.type;
  }
}

// ───────────── Tienda ─────────────

async function getCatalog(userId) {
  const wallet = await Wallet.findOne({ user: toId(userId) }, { ops: 1, equipped: 1 }).lean();
  const owned = ownedFromOps(wallet?.ops);
  const equipped = equippedOf(wallet);
  return {
    items: CATALOG.map(i => ({
      ...i,
      owned: owned.has(i.id),
      equipped: i.slot ? equipped[i.slot] === i.id : false,
    })),
    equipped,
  };
}

async function purchase(userId, itemId) {
  const item = CATALOG_BY_ID[itemId];
  if (!item) throw new WalletError(404, 'Artículo no encontrado');
  if (item.price <= 0) throw new WalletError(409, 'Este artículo es gratis y ya lo tienes');
  await syncEarned(userId);
  const res = await applyOp(userId, { key: `purchase:${item.id}`, amount: -item.price, type: 'purchase', ref: item.id });
  if (!res.applied) throw new WalletError(409, 'Ya tienes este artículo', { balance: res.balance });
  return { item, balance: res.balance };
}

async function getInventory(userId) {
  const wallet = await Wallet.findOne({ user: toId(userId) }, { ops: 1, equipped: 1 }).lean();
  const owned = ownedFromOps(wallet?.ops);
  return {
    items: CATALOG.filter(i => owned.has(i.id)),
    equipped: equippedOf(wallet),
  };
}

async function equip(userId, slot, itemId) {
  if (!SLOTS.includes(slot)) throw new WalletError(400, 'Hueco no válido (skin o trail)');
  const uid = toId(userId);
  await ensureWallet(uid);
  if (itemId !== null && itemId !== undefined && itemId !== '') {
    const item = CATALOG_BY_ID[itemId];
    if (!item || item.slot !== slot) throw new WalletError(400, 'Ese artículo no se puede equipar ahí');
    const wallet = await Wallet.findOne({ user: uid }, { ops: 1 }).lean();
    if (!ownedFromOps(wallet.ops).has(itemId)) throw new WalletError(403, 'Primero compra este artículo');
  } else if (slot === 'skin') {
    itemId = DEFAULT_EQUIPPED.skin;
  } else {
    itemId = null;
  }
  const w = await Wallet.findOneAndUpdate({ user: uid }, { $set: { [`equipped.${slot}`]: itemId } }, { new: true }).lean();
  return { equipped: equippedOf(w) };
}

// ───────────── Apuestas de retos ─────────────
// Claves: stake:<cid>:creator | stake:<cid>:<userId>:<joinCount> | refund:<stakeKey> | win:<cid>
// El estado del reto (wagerState: open → paid | refunded) es el cerrojo entre
// "pagar al ganador" y "reembolsar al borrar": solo una de las dos transiciones gana.

function validateWager(raw) {
  if (raw === undefined || raw === null || raw === '' || raw === 0) return 0;
  const n = Number(raw);
  if (!Number.isInteger(n) || n < 0 || n > MAX_WAGER) {
    throw new WalletError(400, `La apuesta debe ser un número entero entre 0 y ${formatSteps(MAX_WAGER)} pasos`);
  }
  return n;
}

async function stake(userId, challengeId, amount, stakeKey) {
  await syncEarned(userId);
  return applyOp(userId, { key: stakeKey, amount: -amount, type: 'wager_stake', ref: String(challengeId) });
}

// Reembolsa todas las apuestas no reembolsadas de [userId] en el reto.
async function refundUserStakes(userId, challengeId) {
  const cid = String(challengeId);
  const wallet = await Wallet.findOne({ user: toId(userId) }, { ops: 1 }).lean();
  if (!wallet) return 0;
  let refunded = 0;
  for (const op of wallet.ops) {
    if (op.t === 'wager_stake' && op.r === cid) {
      const res = await applyOp(userId, { key: `refund:${op.k}`, amount: -op.a, type: 'wager_refund', ref: cid });
      if (res.applied) refunded += -op.a;
    }
  }
  return refunded;
}

function isChallengeOver(challenge) {
  return challenge.status === 'finished' || (challenge.endDate && new Date() > challenge.endDate);
}

// Reembolsa a ambos participantes (reto borrado antes de terminar).
// Si el reto ya había terminado, liquida en su lugar (el ganador cobra).
async function refundChallenge(challenge) {
  if (!challenge.wager || challenge.wager <= 0) return;
  if (challenge.opponent && isChallengeOver(challenge) && challenge.status !== 'waiting') {
    await settleChallenge(challenge);
    return;
  }
  const locked = await Challenge.findOneAndUpdate(
    { _id: challenge._id, wagerState: 'open' },
    { $set: { wagerState: 'refunded' } },
    { new: true }
  );
  const state = locked ? 'refunded' : (await Challenge.findById(challenge._id, { wagerState: 1 }))?.wagerState;
  if (state !== 'refunded') return; // ya pagado al ganador
  const participants = [challenge.creator, challenge.opponent].filter(Boolean);
  for (const u of participants) await refundUserStakes(u._id || u, challenge._id);
  await Challenge.updateOne({ _id: challenge._id }, { $set: { wagerSettledAt: new Date() } });
}

/**
 * Liquida la apuesta de un reto terminado. Idempotente: se puede llamar en cada GET.
 * Ganador (más pasos en el reto) → recibe el bote (2 × apuesta).
 * Empate (incluido 0-0) o sin rival → se reembolsa a cada uno su apuesta.
 */
async function settleChallenge(challenge) {
  if (!challenge.wager || challenge.wager <= 0) return null;
  if (challenge.wagerSettledAt) return challenge.wagerWinner ? String(challenge.wagerWinner) : null;
  if (!isChallengeOver(challenge)) return null;

  const creatorId = String(challenge.creator._id || challenge.creator);
  const opponentId = challenge.opponent ? String(challenge.opponent._id || challenge.opponent) : null;

  let winner = null;
  if (opponentId) {
    const totals = await StepEntry.aggregate([
      { $match: { challenge: toId(challenge._id) } },
      { $group: { _id: '$user', total: { $sum: '$steps' } } }
    ]);
    const byUser = Object.fromEntries(totals.map(t => [String(t._id), t.total]));
    const a = byUser[creatorId] || 0;
    const b = byUser[opponentId] || 0;
    if (a > b) winner = creatorId; else if (b > a) winner = opponentId;
  }
  const outcome = winner ? 'paid' : 'refunded';

  // Transición única open → paid/refunded. Si ya estaba en `outcome` (reintento tras
  // un fallo) se continúa: las operaciones del monedero son idempotentes.
  await Challenge.updateOne(
    { _id: challenge._id, wagerState: 'open' },
    { $set: { wagerState: outcome, wagerWinner: winner ? toId(winner) : null } }
  );
  const current = await Challenge.findById(challenge._id, { wagerState: 1, wagerWinner: 1 }).lean();
  if (!current) return null;

  if (current.wagerState === 'paid' && current.wagerWinner) {
    await applyOp(current.wagerWinner, {
      key: `win:${challenge._id}`, amount: challenge.wager * 2, type: 'wager_win', ref: String(challenge._id)
    });
  } else if (current.wagerState === 'refunded') {
    for (const u of [creatorId, opponentId].filter(Boolean)) await refundUserStakes(u, challenge._id);
  }
  await Challenge.updateOne({ _id: challenge._id }, { $set: { wagerSettledAt: new Date() } });
  return current.wagerWinner ? String(current.wagerWinner) : null;
}

// Liquida las apuestas pendientes de los retos terminados del usuario.
async function settlePendingForUser(userId) {
  const uid = toId(userId);
  const now = new Date();
  const pending = await Challenge.find({
    $or: [{ creator: uid }, { opponent: uid }],
    wager: { $gt: 0 },
    wagerSettledAt: null,
    wagerState: { $in: ['open', 'paid', 'refunded'] },
    opponent: { $ne: null },
    $and: [{ $or: [{ status: 'finished' }, { status: 'active', endDate: { $lt: now } }] }]
  });
  for (const c of pending) {
    if (c.status === 'active') {
      c.status = 'finished';
      await c.save();
    }
    await settleChallenge(c);
  }
}

module.exports = {
  CATALOG,
  CATALOG_BY_ID,
  MAX_WAGER,
  SHIELD_STEPS,
  WalletError,
  syncEarned,
  getTodayStepsDeduped,
  applyOp,
  getWalletSummary,
  getCatalog,
  purchase,
  getInventory,
  equip,
  validateWager,
  stake,
  refundUserStakes,
  refundChallenge,
  settleChallenge,
  settlePendingForUser,
  isChallengeOver,
  formatSteps,
};
