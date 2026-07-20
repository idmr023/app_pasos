const { GoogleGenerativeAI } = require('@google/generative-ai');
const CircuitBreaker = require('opossum');
const Workout = require('../models/Workout');
const Routine = require('../models/Routine');
const PersonalRecord = require('../models/PersonalRecord');

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

const CHAT_MODEL = 'models/gemini-2.5-flash';
const MAX_HISTORY = 20;
const CACHE_TTL_MS = 3600 * 1000;

const _responseCache = new Map();

const geminiBreaker = new CircuitBreaker(async ({ model, history, systemPrompt, lastMessage }) => {
  const chat = model.startChat({
    history,
    systemInstruction: { parts: [{ text: systemPrompt }] },
    generationConfig: { temperature: 0.7, maxOutputTokens: 1024 },
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
});

geminiBreaker.fallback(() => 'El asistente está procesando muchas solicitudes. Intenta en un minuto.');

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

  return contextParts.join('\n\n');
}

function buildSystemPrompt(user, userContext) {
  const levelTitles = ['Novato', 'Principiante', 'Aprendiz', 'Intermedio', 'Avanzado', 'Experto', 'Élite', 'Master', 'Leyenda', 'Titán'];
  const hasPhysicalData = user.weight > 0 && user.height > 0;

  let prompt = `Eres "Coach IA", un entrenador fitness virtual dentro de la app "App Pasos". Tu personalidad es motivadora, enérgica, informativa y profesional. Respondes SIEMPRE en español de forma clara y concisa.

NORMAS FUNDAMENTALES:
1. Usas tu conocimiento global sobre ejercicios, deporte y nutrición para dar recomendaciones. NO estás limitado a un catálogo local.
2. Si el usuario te pregunta algo fuera del ámbito fitness, redirige amablemente al tema de entrenamiento.
3. Sé motivador pero realista. No prometas resultados irreales.
4. Adapta el nivel de detalle a lo que el usuario pida: sé breve si no pide más, extenso si lo solicita.

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
- Pregunta por equipo disponible, días de entrenamiento, lesiones, etc. para refinar aún más.`;

  if (userContext) {
    prompt += `\n\nCONTEXTO DEL USUARIO:\n${userContext}`;
  }

  return prompt;
}

async function getCoachResponse(user, messages) {
  const lastMessage = messages[messages.length - 1]?.content || '';
  const cacheKey = '${user._id}:${lastMessage.trim()}';

  const cached = _checkCache(cacheKey);
  if (cached) return cached;

  if (geminiBreaker.opened) {
    return 'El asistente está procesando muchas solicitudes. Intenta en un minuto.';
  }

  const userContext = await buildUserContext(user._id);
  const systemPrompt = buildSystemPrompt(user, userContext);

  const model = genAI.getGenerativeModel({ model: CHAT_MODEL });

  const history = messages.slice(-MAX_HISTORY, -1).map(m => ({
    role: m.role === 'assistant' ? 'model' : 'user',
    parts: [{ text: m.content }],
  }));

  try {
    const reply = await geminiBreaker.fire({ model, history, systemPrompt, lastMessage });
    if (reply && reply.length >= 10) {
      _setCache(lastMessage.trim(), reply);
    }
    return reply;
  } catch (err) {
    if (geminiBreaker.opened) {
      return 'El asistente está procesando muchas solicitudes. Intenta en un minuto.';
    }
    if (err.status === 429 || (err.message && err.message.includes('429'))) {
      return 'El asistente está procesando muchas solicitudes. Intenta en un minuto.';
    }
    throw err;
  }
}

module.exports = { getCoachResponse };
