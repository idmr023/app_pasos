const { GoogleGenerativeAI } = require('@google/generative-ai');
const CircuitBreaker = require('opossum');
const Workout = require('../models/Workout');
const Routine = require('../models/Routine');
const PersonalRecord = require('../models/PersonalRecord');
const Exercise = require('../models/Exercise');
const StepEntry = require('../models/StepEntry');
const Challenge = require('../models/Challenge');
const TrackingSession = require('../models/TrackingSession');
const GameScore = require('../models/GameScore');

function startOfDay(d = new Date()) {
  const s = new Date(d);
  s.setHours(0, 0, 0, 0);
  return s;
}

/**
 * Contexto "de hoy" para que el coach hable de la vida real del usuario:
 * pasos de hoy/semana, retos activos (marcador vs rival), carreras en vivo
 * recientes y Sprint. Los mismos pasos pueden estar registrados en varios
 * retos el mismo día, así que por día se toma el máximo (no la suma).
 */
async function buildDailyContext(userId) {
  const parts = [];
  const today = startOfDay();
  const weekAgo = new Date(today.getTime() - 6 * 24 * 3600 * 1000);

  const perDay = await StepEntry.aggregate([
    { $match: { user: userId, date: { $gte: weekAgo } } },
    {
      $group: {
        _id: { $dateToString: { format: '%Y-%m-%d', date: '$date' } },
        steps: { $max: '$steps' },
      },
    },
    { $sort: { _id: 1 } },
  ]);
  const todayKey = today.toISOString().slice(0, 10);
  const todaySteps = perDay.find(d => d._id === todayKey)?.steps || 0;
  const weekSteps = perDay.reduce((a, d) => a + d.steps, 0);
  parts.push(`PASOS: hoy ${todaySteps.toLocaleString('es-MX')} | últimos 7 días ${weekSteps.toLocaleString('es-MX')} (${perDay.length} días con registro)`);

  const challenges = await Challenge.find({
    status: 'active',
    $or: [{ creator: userId }, { opponent: userId }],
  })
    .populate('creator opponent', 'displayName username')
    .limit(5)
    .lean();
  if (challenges.length > 0) {
    const lines = [];
    for (const ch of challenges) {
      const totals = await StepEntry.aggregate([
        { $match: { challenge: ch._id } },
        { $group: { _id: '$user', steps: { $sum: '$steps' } } },
      ]);
      const mine = totals.find(t => String(t._id) === String(userId))?.steps || 0;
      const rival = String(ch.creator?._id) === String(userId) ? ch.opponent : ch.creator;
      const theirs = totals.find(t => String(t._id) === String(rival?._id))?.steps || 0;
      const daysLeft = ch.endDate ? Math.max(0, Math.ceil((new Date(ch.endDate) - Date.now()) / 86400000)) : '?';
      const diff = mine - theirs;
      lines.push(`- vs ${rival?.displayName || rival?.username || 'rival'}: tú ${mine} vs ${theirs} (${diff >= 0 ? `ganas por ${diff}` : `te faltan ${-diff} para empatar`}), quedan ${daysLeft} días`);
    }
    parts.push(`RETOS ACTIVOS:\n${lines.join('\n')}`);
  }

  const runs = await TrackingSession.find({ runner: userId, status: 'completed' })
    .sort({ endedAt: -1 })
    .limit(3)
    .select('totalDistance avgPace endedAt')
    .lean();
  if (runs.length > 0) {
    parts.push('CARRERAS RECIENTES:\n' + runs.map(r =>
      `- ${Number(r.totalDistance || 0).toFixed(2)} km, ritmo ${r.avgPace ? `${Math.floor(r.avgPace)}:${String(Math.round((r.avgPace % 1) * 60)).padStart(2, '0')}/km` : 'n/d'} (${r.endedAt ? new Date(r.endedAt).toLocaleDateString('es-MX') : ''})`
    ).join('\n'));
  }

  const best = await GameScore.findOne({ user: userId }).sort({ score: -1 }).select('score level').lean();
  if (best) parts.push(`JUEGO SPRINT: mejor puntaje ${best.score} (nivel ${best.level}). 2,000 pasos = 1 intento.`);

  return parts.join('\n\n');
}

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

const CHAT_MODEL = 'models/gemini-2.5-flash';
const MAX_HISTORY = 20;
const CACHE_TTL_MS = 3600 * 1000;

const _responseCache = new Map();

const geminiBreaker = new CircuitBreaker(async ({ model, history, systemPrompt, lastMessage }) => {
  const chat = model.startChat({
    history,
    systemInstruction: { role: 'system', parts: [{ text: systemPrompt }] },
    generationConfig: {
      temperature: 0.7,
      // gemini-2.5-flash gasta tokens de "thinking" dentro de maxOutputTokens:
      // con 1024 y thinking activo la respuesta llegaba vacía. Se desactiva el
      // thinking y se sube el límite.
      maxOutputTokens: 2048,
      thinkingConfig: { thinkingBudget: 0 },
    },
  });
  const result = await chat.sendMessage(lastMessage);
  return result.response.text();
}, {
  timeout: 25000,
  errorThresholdPercentage: 50,
  resetTimeout: 30000,
  rollingCountTimeout: 60000,
  rollingCountBuckets: 6,
  name: 'gemini',
  // Errores de petición (400/403: historial inválido, API key) no indican que
  // Gemini esté saturado: no deben abrir el circuito.
  errorFilter: (err) => [400, 401, 402, 403, 404].includes(err?.status),
});
// Sin fallback genérico: antes cualquier error (API key inválida, historial mal
// formado) se convertía en "procesando muchas solicitudes" y ocultaba la causa.

const BUSY_MESSAGE = 'El asistente está procesando muchas solicitudes. Intenta en un minuto.';

class CoachUnavailableError extends Error {
  constructor(message) {
    super(message);
    this.name = 'CoachUnavailableError';
  }
}

/**
 * Gemini exige que el historial empiece con rol 'user' y alterne
 * user/model. Al recortar con slice(-N) el historial podía empezar por
 * 'model' y la API respondía 400 en cada mensaje.
 */
function sanitizeHistory(history) {
  const clean = [];
  for (const item of history) {
    const text = item.parts?.[0]?.text?.trim();
    if (!text) continue;
    const last = clean[clean.length - 1];
    if (last && last.role === item.role) {
      last.parts[0].text += `\n${text}`;
    } else {
      clean.push({ role: item.role, parts: [{ text }] });
    }
  }
  while (clean.length > 0 && clean[0].role !== 'user') clean.shift();
  // El último mensaje (el actual) se envía aparte como 'user'; el historial
  // debe terminar en 'model' para mantener la alternancia.
  while (clean.length > 0 && clean[clean.length - 1].role !== 'model') clean.pop();
  return clean;
}

function _normalize(text) {
  return text.toLowerCase().replace(/[^\w\s]/g, '').trim();
}

function _checkCache(text) {
  const key = _normalize(text);
  const entry = _responseCache.get(key);
  if (entry && Date.now() - entry.timestamp < CACHE_TTL_MS) {
    return entry.response;
  }
  if (entry) _responseCache.delete(key);
  return null;
}

function _setCache(text, response) {
  const key = _normalize(text);
  _responseCache.set(key, { response, timestamp: Date.now() });
}

setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of _responseCache) {
    if (now - entry.timestamp >= CACHE_TTL_MS) {
      _responseCache.delete(key);
    }
  }
}, 600000);

const goalLabels = {
  lose_weight: 'Bajar de peso',
  gain_muscle: 'Ganar músculo',
  maintain: 'Mantener',
  endurance: 'Resistencia',
  general: 'General',
};

async function buildUserContext(userId) {
  const contextParts = [];

  try {
    const daily = await buildDailyContext(userId);
    if (daily) contextParts.push(daily);
  } catch (err) {
    // Best-effort: un fallo del contexto diario no debe tumbar el chat.
    console.error('[Coach] daily context error:', err.message);
  }

  const recentWorkouts = await Workout.find({ user: userId })
    .sort({ date: -1 })
    .limit(5)
    .select('routineName date duration exercises')
    .lean();

  if (recentWorkouts.length > 0) {
    const wText = recentWorkouts.map(w =>
      `- ${w.routineName || 'Entreno libre'} (${new Date(w.date).toLocaleDateString('es-MX')}, ${Math.round(w.duration / 60)} min, ${w.exercises?.length || 0} ejercicios)`
    ).join('\n');
    contextParts.push(`ENTRENAMIENTOS RECIENTES:\n${wText}`);
  }

  const routines = await Routine.find({ user: userId })
    .select('name exercises isWarmup')
    .lean();

  if (routines.length > 0) {
    const rText = routines.map(r =>
      `- ${r.name}${r.isWarmup ? ' (calentamiento)' : ''} (${r.exercises?.length || 0} ejercicios)`
    ).join('\n');
    contextParts.push(`RUTINAS GUARDADAS:\n${rText}`);
  }

  const records = await PersonalRecord.find({ user: userId })
    .select('exerciseName maxWeightKg')
    .sort({ maxWeightKg: -1 })
    .limit(5)
    .lean();

  if (records.length > 0) {
    const prText = records.map(r =>
      `- ${r.exerciseName || 'Ejercicio'}: ${r.maxWeightKg} kg`
    ).join('\n');
    contextParts.push(`MARCAS PERSONALES:\n${prText}`);
  }

  const ejercicios = await Exercise.find()
    .select('name nameSpanish category bodyPart equipment')
    .limit(40)
    .lean();

  if (ejercicios.length > 0) {
    const catMap = {};
    for (const ex of ejercicios) {
      const cat = ex.category || 'strength';
      if (!catMap[cat]) catMap[cat] = [];
      catMap[cat].push(ex.nameSpanish || ex.name);
    }
    const catText = Object.entries(catMap)
      .map(([cat, names]) => `  ${cat}: ${names.slice(0, 10).join(', ')}${names.length > 10 ? `... (+${names.length - 10} más)` : ''}`)
      .join('\n');
    contextParts.push(`CATÁLOGO DE EJERCICIOS DISPONIBLES (${ejercicios.length} en total):\n${catText}`);
  }

  return contextParts.join('\n\n');
}

function buildSystemPrompt(user, userContext) {
  const levelTitles = ['Novato', 'Principiante', 'Aprendiz', 'Intermedio', 'Avanzado', 'Experto', 'Élite', 'Master', 'Leyenda', 'Titán'];
  const hasPhysicalData = user.weight > 0 && user.height > 0;

  let prompt = `Eres "Coach IA", un entrenador fitness virtual dentro de la app "App Pasos". Tu personalidad es motivadora, enérgica, informativa y profesional. Respondes SIEMPRE en español de forma clara y concisa.

NORMAS FUNDAMENTALES:
1. Usas tu conocimiento global sobre ejercicios, deporte y nutrición, pero SIEMPRE que sea posible, basa tus recomendaciones en los ejercicios del CATÁLOGO DE EJERCICIOS DISPONIBLES incluido en el contexto.
2. Si el usuario pregunta por un ejercicio específico, revísalo primero en el catálogo. Si existe en la BD, menciónalo por su nombre en español y usa sus datos (categoría, grupo muscular, equipo). Si el usuario pregunta por un ejercicio que NO está en el catálogo, indícale que no está disponible actualmente y sugiere alternativas similares del catálogo.
3. Si el usuario te pregunta algo fuera del ámbito fitness, redirige amablemente al tema de entrenamiento.
4. Sé motivador pero realista. No prometas resultados irreales.
5. Adapta el nivel de detalle a lo que el usuario pida: sé breve si no pide más, extenso si lo solicita.

DATOS DEL USUARIO:
- Usuario: ${user.displayName || user.username}
- Nivel: ${user.level} (${levelTitles[Math.min(user.level, levelTitles.length - 1)] || 'Novato'})
- XP total: ${user.xp || 0}
- Título actual: ${user.title || 'Ninguno'}`;

  if (hasPhysicalData) {
    prompt += `\n- Peso: ${user.weight} kg
- Altura: ${user.height} cm
- Meta: ${goalLabels[user.goal] || 'General'}`;
  } else {
    prompt += `\n\n⚠️ IMPORTANTE: El usuario aún no ha registrado su peso, altura ni meta fitness. En tu PRIMER mensaje (si el historial está vacío o es el inicio de la conversación), saluda y PREGÚNTALE amablemente por su peso, altura y meta fitness (bajar de peso, ganar músculo, mantener, resistencia, o general) para poder personalizar mejor sus recomendaciones. NO des recomendaciones genéricas extensas sin antes conocer sus datos.`;
  }

  prompt += `\n\nPERSONALIZACIÓN:
- Usa los datos del usuario (nivel, racha, entrenamientos recientes, rutinas, marcas personales) para adaptar cada recomendación.
- Si conoces su peso, altura y meta, úsalos para calcular IMC si es relevante y ajustar intensidad/recomendaciones.
- Pregunta por equipo disponible, días de entrenamiento, lesiones, etc. para refinar aún más.
- Usa PASOS, RETOS ACTIVOS, CARRERAS RECIENTES y JUEGO SPRINT para dar consejos concretos del día. Ej.: "Te faltan 1,200 pasos para alcanzar a Carlos: una caminata de 12 min y lo pasas". Cuando sea útil, calcula minutos de caminata (~100 pasos/min).`;

  if (userContext) {
    prompt += `\n\nCONTEXTO DEL USUARIO:\n${userContext}`;
  }

  return prompt;
}

async function searchExercises(query) {
  if (!query || query.trim().length < 2) return [];
  const terms = query.trim().toLowerCase().split(/\s+/).filter(Boolean);
  try {
    const filter = {
      $or: terms.map(t => {
        const escaped = t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        return {
          $or: [
            { name: { $regex: escaped, $options: 'i' } },
            { nameSpanish: { $regex: escaped, $options: 'i' } },
            { category: { $regex: escaped, $options: 'i' } },
            { bodyPart: { $regex: escaped, $options: 'i' } },
          ],
        };
      }),
    };
    return await Exercise.find(filter)
      .select('name nameSpanish category bodyPart equipment description')
      .limit(8)
      .lean();
  } catch (_) {
    return [];
  }
}

async function getCoachResponse(user, messages) {
  const lastMessage = messages[messages.length - 1]?.content || '';
  const cacheKey = `${user._id}:${lastMessage.trim()}`;

  const cached = _checkCache(cacheKey);
  if (cached) return cached;

  if (!process.env.GEMINI_API_KEY) {
    throw new CoachUnavailableError('El Coach IA no está configurado en el servidor (falta GEMINI_API_KEY).');
  }

  if (geminiBreaker.opened) {
    return BUSY_MESSAGE;
  }

  const userContext = await buildUserContext(user._id);

  const relevantExercises = await searchExercises(lastMessage);
  let exerciseContext = '';
  if (relevantExercises.length > 0) {
    exerciseContext = '\n\nEJERCICIOS RELEVANTES A LA CONSULTA:\n' +
      relevantExercises.map(ex =>
        `- ${ex.nameSpanish || ex.name} (${ex.category || ''} | ${ex.bodyPart || ''} | ${ex.equipment || 'sin equipo'})`
      ).join('\n');
  }

  const combinedContext = userContext + exerciseContext;
  const systemPrompt = buildSystemPrompt(user, combinedContext);

  const model = genAI.getGenerativeModel({ model: CHAT_MODEL });

  const history = sanitizeHistory(messages.slice(-MAX_HISTORY, -1).map(m => ({
    role: m.role === 'assistant' ? 'model' : 'user',
    parts: [{ text: m.content || '' }],
  })));

  let reply;
  try {
    reply = await geminiBreaker.fire({ model, history, systemPrompt, lastMessage });
  } catch (err) {
    console.error('[Coach] Gemini error:', err.status || '', err.message);
    if (geminiBreaker.opened || err.code === 'ETIMEDOUT' || err.code === 'EOPENBREAKER') {
      return BUSY_MESSAGE;
    }
    if (err.status === 429 || (err.message && err.message.includes('429'))) {
      return BUSY_MESSAGE;
    }
    if (err.status === 400 && /api key/i.test(err.message || '')) {
      throw new CoachUnavailableError('La API key de Gemini del servidor no es válida.');
    }
    if (err.status === 402) {
      throw new CoachUnavailableError('El Coach IA está sin créditos de Gemini. El administrador debe recargar la cuenta de Google AI.');
    }
    if (err.status === 403) {
      throw new CoachUnavailableError('La API key de Gemini no tiene permiso para este modelo.');
    }
    throw new CoachUnavailableError('El Coach IA no pudo responder. Intenta de nuevo.');
  }

  if (!reply || !reply.trim()) {
    throw new CoachUnavailableError('El Coach IA devolvió una respuesta vacía. Reformula tu pregunta.');
  }
  if (reply.length >= 10) {
    _setCache(cacheKey, reply);
  }
  return reply;
}

module.exports = { getCoachResponse, sanitizeHistory, buildDailyContext, CoachUnavailableError };
