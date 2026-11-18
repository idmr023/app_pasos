// Power-ups de espectadores ("Ánimo en vivo") para el tracking en vivo.
// Fuente única de verdad: tipos válidos, texto mostrado, texto hablado (TTS
// del corredor), rate limit y agregaciones para estadísticas / recap.
// Ver docs/LIVE_CHEERS.md.
const LiveMessage = require('../models/LiveMessage');

// Cooldown por socket (server-side): 1 power-up cada 5 s.
const POWER_UP_COOLDOWN_MS = 5000;
// Largo máximo del ánimo personalizado ("voz") que se lee por TTS.
const MAX_CUSTOM_CHEER_LENGTH = 80;

// {name} se reemplaza por el nombre de quien envía.
const POWER_UP_TYPES = {
  turbo: { emoji: '🔥', label: 'Turbo', text: '¡{name} te manda TURBO!' },
  agua: { emoji: '💧', label: 'Agua', text: '¡{name} dice: hidrátate!' },
  aplausos: { emoji: '👏', label: 'Aplausos', text: '¡{name} te está aplaudiendo!' },
  ultimoKm: { emoji: '🏁', label: 'Último km', text: '¡{name} dice: último kilómetro, a por todas!' },
  ritmo: { emoji: '⚡', label: 'Sube el ritmo', text: '¡{name} dice: sube el ritmo!' },
  fuerza: { emoji: '💪', label: 'Tú puedes', text: '¡{name} dice: tú puedes!' },
  // Ánimo personalizado: el texto lo escribe el espectador.
  voz: { emoji: '🎙️', label: 'Ánimo de voz', text: '{name} dice: {text}' },
};

function isValidPowerUpType(type) {
  return typeof type === 'string' && Object.prototype.hasOwnProperty.call(POWER_UP_TYPES, type);
}

/**
 * Normaliza el texto del ánimo personalizado: sin saltos de línea, espacios
 * colapsados y recortado a MAX_CUSTOM_CHEER_LENGTH. Devuelve '' si no hay texto.
 */
function sanitizeCustomText(text) {
  if (typeof text !== 'string') return '';
  return text.replace(/\s+/g, ' ').trim().slice(0, MAX_CUSTOM_CHEER_LENGTH);
}

/** Texto que lee el TTS del corredor (sin emoji). */
function buildSpeech(type, senderName, customText) {
  const def = POWER_UP_TYPES[type];
  return def.text.replace('{name}', senderName || 'Alguien').replace('{text}', customText || '');
}

/** Texto mostrado en el chat / overlay (con emoji). */
function buildDisplayMessage(type, senderName, customText) {
  const def = POWER_UP_TYPES[type];
  if (type === 'voz') return `${def.emoji} ${customText}`;
  return `${def.emoji} ${buildSpeech(type, senderName, customText)}`;
}

/**
 * Comprueba el rate limit de un socket. Devuelve 0 si puede enviar (y marca
 * el envío), o los ms que faltan para el próximo power-up permitido.
 */
function consumePowerUpSlot(socket, now = Date.now()) {
  const last = socket.lastPowerUpAt || 0;
  const elapsed = now - last;
  if (elapsed < POWER_UP_COOLDOWN_MS) return POWER_UP_COOLDOWN_MS - elapsed;
  socket.lastPowerUpAt = now;
  return 0;
}

// Clave de agrupación por "supporter": usuario registrado por _id; invitados
// (sender null) por nombre.
const supporterKey = { $ifNull: [{ $toString: '$sender' }, { $concat: ['guest:', '$senderName'] }] };

/** Estadísticas en vivo: total de ánimos y el top supporter. */
async function getLiveCheerStats(roomCode) {
  const [res] = await LiveMessage.aggregate([
    { $match: { roomCode, kind: 'powerUp' } },
    {
      $facet: {
        total: [{ $count: 'n' }],
        top: [
          { $group: { _id: supporterKey, name: { $last: '$senderName' }, count: { $sum: 1 } } },
          { $sort: { count: -1, name: 1 } },
          { $limit: 1 },
        ],
        supporters: [{ $group: { _id: supporterKey } }, { $count: 'n' }],
      },
    },
  ]);
  const top = res?.top?.[0];
  return {
    total: res?.total?.[0]?.n || 0,
    supporters: res?.supporters?.[0]?.n || 0,
    topSupporter: top ? { name: top.name, count: top.count } : null,
  };
}

/** Recap completo para el resumen de fin de carrera. */
async function getCheersRecap(roomCode) {
  const [res] = await LiveMessage.aggregate([
    { $match: { roomCode, kind: 'powerUp' } },
    {
      $facet: {
        byType: [{ $group: { _id: '$powerUpType', count: { $sum: 1 } } }],
        topSupporters: [
          { $group: { _id: supporterKey, name: { $last: '$senderName' }, count: { $sum: 1 } } },
          { $sort: { count: -1, name: 1 } },
        ],
        samples: [
          { $match: { powerUpType: 'voz' } },
          { $sort: { timestamp: -1 } },
          { $limit: 5 },
          { $project: { _id: 0, senderName: 1, message: 1, timestamp: 1 } },
        ],
      },
    },
  ]);

  const byType = {};
  for (const t of Object.keys(POWER_UP_TYPES)) byType[t] = 0;
  let total = 0;
  for (const row of res?.byType || []) {
    if (row._id && byType[row._id] !== undefined) byType[row._id] = row.count;
    total += row.count;
  }
  const supporters = res?.topSupporters || [];
  return {
    total,
    supporters: supporters.length,
    byType,
    topSupporters: supporters.slice(0, 5).map((s) => ({ name: s.name, count: s.count })),
    // Mensajes de voz: se devuelve el texto sin el emoji del prefijo.
    samples: (res?.samples || []).map((s) => ({
      senderName: s.senderName,
      text: (s.message || '').replace(/^🎙️\s*/u, ''),
      timestamp: s.timestamp,
    })),
  };
}

/** Conteo de ánimos por roomCode, para el listado "Mis carreras". */
async function getCheerCountsByRoom(roomCodes) {
  if (!roomCodes.length) return {};
  const rows = await LiveMessage.aggregate([
    { $match: { roomCode: { $in: roomCodes }, kind: 'powerUp' } },
    { $group: { _id: '$roomCode', count: { $sum: 1 } } },
  ]);
  const out = {};
  for (const r of rows) out[r._id] = r.count;
  return out;
}

module.exports = {
  POWER_UP_TYPES,
  POWER_UP_COOLDOWN_MS,
  MAX_CUSTOM_CHEER_LENGTH,
  isValidPowerUpType,
  sanitizeCustomText,
  buildSpeech,
  buildDisplayMessage,
  consumePowerUpSlot,
  getLiveCheerStats,
  getCheersRecap,
  getCheerCountsByRoom,
};
