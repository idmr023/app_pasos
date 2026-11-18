// Ligas semanales (estilo Duolingo). Reglas completas en docs/LEAGUES.md.
//
// - Semana ISO lunes 00:00 → lunes siguiente 00:00 en America/Lima (UTC-5 fijo, sin horario de verano).
// - Unión perezosa: el usuario entra a un grupo la primera vez que consulta la liga en la semana.
// - Cierre perezoso e idempotente: al llegar la primera consulta de una semana nueva se congela
//   el resultado de la semana anterior (solo escribe miembros con result == null).
// - Los puntos se calculan en solo-lectura a partir de StepEntry, Workout, GameScore y TrackingSession.

const mongoose = require('mongoose');
const LeagueGroup = require('../models/LeagueGroup');
const LeagueMembership = require('../models/LeagueMembership');
const StepEntry = require('../models/StepEntry');
const Workout = require('../models/Workout');
const GameScore = require('../models/GameScore');
const TrackingSession = require('../models/TrackingSession');
const User = require('../models/User');

const TIMEZONE = 'America/Lima';
const TZ_OFFSET_MS = -5 * 60 * 60 * 1000; // Lima = UTC-5 todo el año
const TZ_MONGO = '-05:00';
const DAY_MS = 24 * 60 * 60 * 1000;
const WEEK_MS = 7 * DAY_MS;

const DIVISIONS = [
  { index: 0, key: 'bronce', name: 'Bronce', color: '#CD7F32' },
  { index: 1, key: 'plata', name: 'Plata', color: '#C0C8D4' },
  { index: 2, key: 'oro', name: 'Oro', color: '#F59E0B' },
  { index: 3, key: 'platino', name: 'Platino', color: '#5EEAD4' },
  { index: 4, key: 'diamante', name: 'Diamante', color: '#60A5FA' },
  { index: 5, key: 'leyenda', name: 'Leyenda', color: '#A855F7' },
];
const MAX_DIVISION = DIVISIONS.length - 1;

const MAX_GROUP_SIZE = 20;
const MAX_ZONE = 5; // máximo de ascensos / descensos por grupo

// Fórmula de puntos
const POINTS = {
  stepsPerPoint: 100,        // 1 pt cada 100 pasos
  maxDailySteps: 30000,      // tope de pasos por día que cuentan
  perWorkout: 50,            // 50 pts por entrenamiento
  maxWorkoutsPerDay: 2,
  perGame: 10,               // 10 pts por partida de Sprint
  maxGamesPerDay: 5,
  perKm: 20,                 // 20 pts por km de carrera en vivo finalizada
  maxKmPerRun: 50,
};

const CACHE_MS = Number.isFinite(Number(process.env.LEAGUE_CACHE_MS))
  ? Number(process.env.LEAGUE_CACHE_MS)
  : 15000;
const standingsCache = new Map(); // groupId → { at, rows }

// ───────────────────────── Tiempo ─────────────────────────

// "now" inyectable solo en tests: header x-test-now con NODE_ENV=test.
function nowFromRequest(req) {
  if (process.env.NODE_ENV === 'test') {
    const h = req.header('x-test-now');
    if (h) {
      const d = new Date(h);
      if (!isNaN(d.getTime())) return d;
    }
  }
  return new Date();
}

// Datos de la semana que contiene `date` (en hora de Lima).
function weekInfo(date) {
  const local = new Date(date.getTime() + TZ_OFFSET_MS); // campos UTC = hora local de Lima
  const dow = (local.getUTCDay() + 6) % 7; // lunes = 0
  const y = local.getUTCFullYear();
  const m = local.getUTCMonth();
  const d = local.getUTCDate() - dow;
  const mondayLocalMs = Date.UTC(y, m, d);
  const start = new Date(mondayLocalMs - TZ_OFFSET_MS);
  const end = new Date(start.getTime() + WEEK_MS);

  // Clave ISO: el jueves de la semana define el año ISO.
  const thursday = new Date(mondayLocalMs + 3 * DAY_MS);
  const isoYear = thursday.getUTCFullYear();
  const weekNo = Math.floor((thursday.getTime() - Date.UTC(isoYear, 0, 1)) / WEEK_MS) + 1;
  const key = `${isoYear}-W${String(weekNo).padStart(2, '0')}`;

  // StepEntry guarda la fecha como medianoche en la hora local del servidor
  // (routes/steps.js hace setHours(0,0,0,0)), así que la ventana de pasos usa los
  // mismos días calendario lunes..domingo pero en medianoche local del servidor.
  const monday = new Date(mondayLocalMs);
  const stepsStart = new Date(monday.getUTCFullYear(), monday.getUTCMonth(), monday.getUTCDate());
  const stepsEnd = new Date(monday.getUTCFullYear(), monday.getUTCMonth(), monday.getUTCDate() + 7);

  return { key, start, end, stepsStart, stepsEnd };
}

// ───────────────────────── Puntos ─────────────────────────

function emptyBreakdown() {
  return {
    steps: { value: 0, points: 0 },
    workouts: { count: 0, points: 0 },
    games: { count: 0, points: 0 },
    runs: { km: 0, points: 0 },
    total: 0,
  };
}

// Puntos de varios usuarios en una semana: 4 agregaciones en total.
async function computePoints(userIds, week) {
  const ids = userIds.map((id) => new mongoose.Types.ObjectId(String(id)));
  const [steps, workouts, games, runs] = await Promise.all([
    // Pasos: un mismo día puede estar registrado en varios retos (son los mismos pasos del
    // podómetro) → se toma el MÁXIMO por (usuario, día), con tope diario.
    StepEntry.aggregate([
      { $match: { user: { $in: ids }, date: { $gte: week.stepsStart, $lt: week.stepsEnd } } },
      { $group: { _id: { u: '$user', d: '$date' }, steps: { $max: '$steps' } } },
      { $group: { _id: '$_id.u', value: { $sum: { $min: ['$steps', POINTS.maxDailySteps] } } } },
    ]),
    Workout.aggregate([
      { $match: { user: { $in: ids }, date: { $gte: week.start, $lt: week.end } } },
      { $group: {
        _id: { u: '$user', d: { $dateToString: { format: '%Y-%m-%d', date: '$date', timezone: TZ_MONGO } } },
        n: { $sum: 1 },
      } },
      { $group: { _id: '$_id.u', count: { $sum: { $min: ['$n', POINTS.maxWorkoutsPerDay] } } } },
    ]),
    GameScore.aggregate([
      { $match: { user: { $in: ids }, createdAt: { $gte: week.start, $lt: week.end } } },
      { $group: {
        _id: { u: '$user', d: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt', timezone: TZ_MONGO } } },
        n: { $sum: 1 },
      } },
      { $group: { _id: '$_id.u', count: { $sum: { $min: ['$n', POINTS.maxGamesPerDay] } } } },
    ]),
    TrackingSession.aggregate([
      { $match: { runner: { $in: ids }, status: 'completed', endedAt: { $gte: week.start, $lt: week.end } } },
      { $group: { _id: '$runner', km: { $sum: { $min: [{ $ifNull: ['$totalDistance', 0] }, POINTS.maxKmPerRun] } } } },
    ]),
  ]);

  const map = new Map();
  for (const id of ids) map.set(String(id), emptyBreakdown());
  for (const r of steps) {
    const b = map.get(String(r._id));
    b.steps.value = r.value;
    b.steps.points = Math.floor(r.value / POINTS.stepsPerPoint);
  }
  for (const r of workouts) {
    const b = map.get(String(r._id));
    b.workouts.count = r.count;
    b.workouts.points = r.count * POINTS.perWorkout;
  }
  for (const r of games) {
    const b = map.get(String(r._id));
    b.games.count = r.count;
    b.games.points = r.count * POINTS.perGame;
  }
  for (const r of runs) {
    const b = map.get(String(r._id));
    b.runs.km = Math.round(r.km * 100) / 100;
    b.runs.points = Math.floor(r.km * POINTS.perKm);
  }
  for (const b of map.values()) {
    b.total = b.steps.points + b.workouts.points + b.games.points + b.runs.points;
  }
  return map;
}

// ───────────────────────── Zonas y ranking ─────────────────────────

function zoneCounts(size, division) {
  const promote = division < MAX_DIVISION && size >= 1
    ? Math.min(MAX_ZONE, Math.max(1, Math.floor(size / 4)))
    : 0;
  const demote = division > 0 && size >= 4 ? Math.min(MAX_ZONE, Math.floor(size / 4)) : 0;
  return { promote, demote };
}

// Zona de un puesto. Para subir hay que tener puntos > 0; con 0 puntos (fuera de Bronce) se baja.
function zoneFor(rank, size, division, points) {
  const { promote, demote } = zoneCounts(size, division);
  if (rank <= promote && points > 0) return 'promote';
  if (division > 0 && (rank > size - demote || points <= 0)) return 'demote';
  return 'stay';
}

// memberships: documentos LeagueMembership de un grupo.
async function rankGroup(group, memberships, week) {
  const cacheKey = String(group._id);
  const cached = standingsCache.get(cacheKey);
  if (CACHE_MS > 0 && cached && Date.now() - cached.at < CACHE_MS && cached.size === memberships.length) {
    return cached.rows;
  }
  const points = await computePoints(memberships.map((m) => m.user), week);
  const rows = memberships
    .map((m) => ({ membership: m, breakdown: points.get(String(m.user)) || emptyBreakdown() }))
    .sort((a, b) => (b.breakdown.total - a.breakdown.total)
      || (new Date(a.membership.joinedAt) - new Date(b.membership.joinedAt))
      || String(a.membership.user).localeCompare(String(b.membership.user)));
  rows.forEach((r, i) => {
    r.rank = i + 1;
    r.zone = zoneFor(r.rank, rows.length, group.division, r.breakdown.total);
  });
  if (CACHE_MS > 0) {
    if (standingsCache.size > 500) standingsCache.clear();
    standingsCache.set(cacheKey, { at: Date.now(), rows, size: memberships.length });
  }
  return rows;
}

// ───────────────────────── Cierre de semana ─────────────────────────

async function finalizeGroup(groupId, now) {
  if (!groupId) return;
  const group = await LeagueGroup.findById(groupId);
  if (!group || group.finalized) return;
  const memberships = await LeagueMembership.find({ group: group._id });
  if (memberships.length === 0) return;
  const week = weekInfo(memberships[0].weekStart);
  if (week.end > now) return; // la semana aún no termina

  standingsCache.delete(String(group._id));
  const rows = await rankGroup(group, memberships, week);
  const ops = rows.map((r) => {
    const result = r.zone === 'promote' ? 'promoted' : r.zone === 'demote' ? 'demoted' : 'stayed';
    const delta = result === 'promoted' ? 1 : result === 'demoted' ? -1 : 0;
    const nextDivision = Math.max(0, Math.min(MAX_DIVISION, group.division + delta));
    return {
      updateOne: {
        // result:null → idempotente: un resultado ya congelado nunca se reescribe
        filter: { _id: r.membership._id, result: null },
        update: { $set: { finalPoints: r.breakdown.total, finalRank: r.rank, result, nextDivision } },
      },
    };
  });
  await LeagueMembership.bulkWrite(ops, { ordered: false });
  await LeagueGroup.updateOne({ _id: group._id }, { $set: { finalized: true, finalizedAt: now } });
  standingsCache.delete(String(group._id));
}

// ───────────────────────── Unión perezosa ─────────────────────────

async function assignGroup(membership) {
  const userId = membership.user;
  const { week, division } = membership;
  let group = null;
  await LeagueGroup.init(); // asegura el índice único (memoizado por Mongoose)
  for (let attempt = 0; attempt < 8 && !group; attempt++) {
    // 1) Entrar a un grupo con cupo (operación atómica: members.19 no existe ⇒ < 20)
    group = await LeagueGroup.findOneAndUpdate(
      { week, division, finalized: false, [`members.${MAX_GROUP_SIZE - 1}`]: { $exists: false } },
      { $addToSet: { members: userId } },
      { sort: { seq: 1 }, new: true },
    );
    if (group) break;
    // 2) Todos llenos: crear el siguiente seq. Si otra petición lo creó primero (E11000),
    //    se reintenta el paso 1 y se entra a ese grupo nuevo.
    const last = await LeagueGroup.findOne({ week, division }).sort({ seq: -1 }).select('seq').lean();
    try {
      group = await LeagueGroup.create({ week, division, seq: last ? last.seq + 1 : 0, members: [userId] });
    } catch (e) {
      if (!e || e.code !== 11000) throw e;
    }
  }
  if (!group) throw new Error('No se pudo asignar grupo de liga');
  const res = await LeagueMembership.updateOne({ _id: membership._id, group: null }, { $set: { group: group._id } });
  if (res.modifiedCount === 0) {
    // Otra petición concurrente ya asignó grupo: deshacer este cupo si no es el mismo.
    const fresh = await LeagueMembership.findById(membership._id);
    if (fresh && String(fresh.group) !== String(group._id)) {
      await LeagueGroup.updateOne({ _id: group._id }, { $pull: { members: userId } });
    }
    return fresh;
  }
  membership.group = group._id;
  standingsCache.delete(String(group._id));
  return membership;
}

async function ensureMembership(userId, now) {
  const week = weekInfo(now);
  let membership = await LeagueMembership.findOne({ user: userId, week: week.key });
  if (!membership) {
    let prev = await LeagueMembership.findOne({ user: userId, weekStart: { $lt: week.start } }).sort({ weekStart: -1 });
    if (prev && prev.result === null) {
      await finalizeGroup(prev.group, now);
      prev = await LeagueMembership.findById(prev._id);
    }
    const division = prev ? (prev.nextDivision ?? prev.division) : 0;
    try {
      membership = await LeagueMembership.create({
        user: userId, week: week.key, weekStart: week.start, division, joinedAt: now,
      });
    } catch (e) {
      if (e && e.code === 11000) {
        membership = await LeagueMembership.findOne({ user: userId, week: week.key });
      } else {
        throw e;
      }
    }
  }
  if (!membership.group) membership = await assignGroup(membership);
  return { membership, week };
}

// ───────────────────────── API pública ─────────────────────────

function divisionInfo(index) {
  return DIVISIONS[Math.max(0, Math.min(MAX_DIVISION, index))];
}

function resultPayload(m) {
  if (!m) return null;
  return {
    week: m.week,
    division: divisionInfo(m.division),
    newDivision: divisionInfo(m.nextDivision ?? m.division),
    finalRank: m.finalRank,
    finalPoints: m.finalPoints,
    result: m.result,
  };
}

async function getCurrent(userId, now) {
  const { membership, week } = await ensureMembership(userId, now);
  const group = await LeagueGroup.findById(membership.group);
  const memberships = await LeagueMembership.find({ group: group._id });
  const rows = await rankGroup(group, memberships, week);

  const users = await User.find({ _id: { $in: memberships.map((m) => m.user) } })
    .select('username displayName avatar level').lean();
  const userMap = new Map(users.map((u) => [String(u._id), u]));

  const standings = rows.map((r) => {
    const u = userMap.get(String(r.membership.user)) || {};
    return {
      userId: String(r.membership.user),
      username: u.username || 'usuario',
      displayName: u.displayName || u.username || 'Usuario',
      avatar: u.avatar || '',
      level: u.level || 0,
      points: r.breakdown.total,
      rank: r.rank,
      zone: r.zone,
      isMe: String(r.membership.user) === String(userId),
      breakdown: r.breakdown,
    };
  });
  const me = standings.find((s) => s.isMe) || null;

  const pending = await LeagueMembership.findOne({
    user: userId, weekStart: { $lt: week.start }, result: { $ne: null }, resultSeen: false,
  }).sort({ weekStart: -1 });

  const zones = zoneCounts(standings.length, group.division);
  return {
    week: week.key,
    timezone: TIMEZONE,
    weekStart: week.start,
    weekEnd: week.end,
    serverNow: now,
    timeRemainingMs: Math.max(0, week.end.getTime() - now.getTime()),
    division: divisionInfo(group.division),
    divisions: DIVISIONS,
    group: {
      id: String(group._id),
      size: standings.length,
      maxSize: MAX_GROUP_SIZE,
      promoteCount: zones.promote,
      demoteCount: zones.demote,
    },
    pointsRules: POINTS,
    me,
    standings,
    pendingResult: resultPayload(pending),
  };
}

async function getHistory(userId, now) {
  const week = weekInfo(now);
  // Congela semanas pasadas que nadie cerró todavía (máx. 5 por petición).
  const open = await LeagueMembership.find({ user: userId, weekStart: { $lt: week.start }, result: null })
    .sort({ weekStart: -1 }).limit(5);
  for (const m of open) await finalizeGroup(m.group, now);

  const list = await LeagueMembership.find({ user: userId }).sort({ weekStart: -1 }).limit(12).lean();
  const groups = await LeagueGroup.find({ _id: { $in: list.map((m) => m.group).filter(Boolean) } })
    .select('members').lean();
  const sizes = new Map(groups.map((g) => [String(g._id), (g.members || []).length]));
  return list.map((m) => ({
    week: m.week,
    weekStart: m.weekStart,
    current: m.week === week.key,
    division: divisionInfo(m.division),
    newDivision: m.nextDivision === null ? null : divisionInfo(m.nextDivision),
    finalRank: m.finalRank,
    finalPoints: m.finalPoints,
    result: m.result,
    groupSize: sizes.get(String(m.group)) || 0,
  }));
}

async function ackResult(userId, weekKey, now) {
  const week = weekInfo(now);
  const filter = { user: userId, weekStart: { $lt: week.start }, result: { $ne: null }, resultSeen: false };
  if (typeof weekKey === 'string' && weekKey) filter.week = weekKey;
  const res = await LeagueMembership.updateMany(filter, { $set: { resultSeen: true } });
  return res.modifiedCount || 0;
}

module.exports = {
  TIMEZONE,
  DIVISIONS,
  POINTS,
  MAX_GROUP_SIZE,
  nowFromRequest,
  weekInfo,
  computePoints,
  zoneCounts,
  zoneFor,
  finalizeGroup,
  ensureMembership,
  getCurrent,
  getHistory,
  ackResult,
};
