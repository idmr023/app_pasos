const { GoogleGenerativeAI } = require('@google/generative-ai');
const CircuitBreaker = require('opossum');
const Exercise = require('../models/Exercise');
const Workout = require('../models/Workout');
const Routine = require('../models/Routine');
const PersonalRecord = require('../models/PersonalRecord');

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

const CHAT_MODEL = 'models/gemini-2.5-flash';
const MAX_HISTORY = 20;
const CACHE_TTL_MS = 3600 * 1000; // 1 hora

// Caché en memoria: pregunta → { response, timestamp }
const _responseCache = new Map();

// Circuit breaker para Gemini
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

// Limpiar caché expirada cada 10 minutos
setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of _responseCache) {
    if (now - entry.timestamp >= CACHE_TTL_MS) {
      _responseCache.delete(key);
    }
  }
}, 600000);

function getCategorySpanish(cat) {
  const map = { warmup: 'Calentamiento', strength: 'Fuerza', cardio: 'Cardio', flexibility: 'Flexibilidad' };
  return map[cat] || cat;
}

async function searchExercises(text) {
  const keywords = text.toLowerCase().split(' ').filter(w => w.length > 2);
  const categoryMap = {
    calentamiento: 'warmup', warmup: 'warmup',
    fuerza: 'strength', strength: 'strength', peso: 'strength', pesas: 'strength',
    cardio: 'cardio', aerobico: 'cardio', aerobic: 'cardio',
    flexibilidad: 'flexibility', flexibility: 'flexibility', estiramiento: 'flexibility', estiramientos: 'flexibility',
    pecho: 'strength', pectoral: 'strength', pectorales: 'strength',
    espalda: 'strength', dorsal: 'strength',
    pierna: 'strength', piernas: 'strength', cuadriceps: 'strength', femoral: 'strength', gluteo: 'strength',
    brazo: 'strength', brazos: 'strength', biceps: 'strength', triceps: 'strength',
    hombro: 'strength', hombros: 'strength', deltoides: 'strength',
    abdominales: 'strength', core: 'strength', abdomen: 'strength',
  };

  let categoryFilter;
  for (const word of keywords) {
    if (categoryMap[word]) {
      categoryFilter = categoryMap[word];
      break;
    }
  }

  const filter = {};
  if (categoryFilter) filter.category = categoryFilter;

  let exercises;
  if (text.length > 2) {
    exercises = await Exercise.find({
      $or: [
        { name: { $regex: text, $options: 'i' } },
        { nameSpanish: { $regex: text, $options: 'i' } },
        { muscle: { $regex: text, $options: 'i' } },
        { ...filter }
      ]
    }).limit(20).lean();
  } else {
    exercises = await Exercise.find(filter).limit(20).lean();
  }

  if (exercises.length === 0 && !categoryFilter) {
    exercises = await Exercise.find().limit(10).lean();
  }

  return exercises.map(e => ({
    name: e.nameSpanish || e.name,
    category: getCategorySpanish(e.category),
    description: e.description || '',
    muscle: e.muscle || '',
    equipment: e.equipment || '',
    difficulty: e.difficulty || '',
    defaultSets: e.defaultSets,
    defaultReps: e.defaultReps,
    restTime: e.restTime,
  }));
}

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
    .populate('exercise', 'name nameSpanish')
    .sort({ maxWeightKg: -1 })
    .limit(5)
    .lean();

  if (records.length > 0) {
    const prText = records.map(r =>
      `- ${r.exercise?.nameSpanish || r.exerciseName || 'Ejercicio'}: ${r.maxWeightKg} kg`
    ).join('\n');
    contextParts.push(`MARCAS PERSONALES:\n${prText}`);
  }

  return contextParts.join('\n\n');
}

function buildSystemPrompt(user, exerciseCatalog, userContext) {
  const levelTitles = ['Novato', 'Principiante', 'Aprendiz', 'Intermedio', 'Avanzado', 'Experto', 'Élite', 'Master', 'Leyenda', 'Titán'];

  return `Eres "Coach IA", un entrenador fitness virtual dentro de la app "App Pasos". Tu personalidad es motivadora, enérgica, informativa y profesional. Respondes SIEMPRE en español de forma clara y concisa.

NORMAS FUNDAMENTALES:
1. SOLO recomiendas ejercicios del catálogo proporcionado abajo. NUNCA inventes ejercicios ni recomiendes ejercicios que no estén en la lista.
2. Si el usuario pregunta por un ejercicio que no está en el catálogo, sé honesto y dile que no está disponible en la app, pero sugiere alternativas del catálogo.
3. Usa los datos del usuario para personalizar tus recomendaciones (nivel, racha, entrenamientos recientes).
4. Puedes sugerir cómo combinar ejercicios del catálogo en rutinas.
5. Si te preguntan algo fuera del ámbito fitness, redirige amablemente al tema de entrenamiento.
6. Sé breve y directo. No des respuestas extensas a menos que el usuario pida más detalles.
7. Cuando sugieras ejercicios, incluye series, repeticiones y descanso sugerido basado en los valores por defecto.

DATOS DEL USUARIO:
- Usuario: ${user.displayName || user.username}
- Nivel: ${user.level} (${levelTitles[Math.min(user.level, levelTitles.length - 1)] || 'Novato'})
- XP total: ${user.xp || 0}
- Título actual: ${user.title || 'Ninguno'}

${userContext ? `CONTEXTO DEL USUARIO:\n${userContext}\n` : ''}

CATÁLOGO DE EJERCICIOS DISPONIBLES (${exerciseCatalog.length} ejercicios):
${exerciseCatalog.map((e, i) =>
  `${i + 1}. ${e.name} [${e.category}]${e.muscle ? ` - Músculo: ${e.muscle}` : ''}${e.difficulty ? ` - Dificultad: ${e.difficulty}` : ''}${e.equipment ? ` - Equipo: ${e.equipment}` : ''}${e.description ? ` | ${e.description}` : ''} (Series: ${e.defaultSets || 3}, Reps: ${e.defaultReps || '10'}, Descanso: ${e.restTime || 60}s)`
).join('\n')}

RECOMENDACIONES POR DEFECTO:
- Calentamiento: 5-10 min antes de entrenar, ejercicios de baja intensidad.
- Fuerza: 3-4 series de 8-12 repeticiones, 60-90s de descanso.
- Cardio: 15-30 min, 30-60s de descanso entre ejercicios.
- Flexibilidad: Al final del entrenamiento, mantener estiramientos 15-30s.`;
}

async function getCoachResponse(user, messages) {
  const lastMessage = messages[messages.length - 1]?.content || '';
  const cacheKey = lastMessage.trim();

  // Caché exacta: responder sin llamar a Gemini
  const cached = _checkCache(cacheKey);
  if (cached) return cached;

  // Circuito abierto: devolver fallback sin intentar
  if (geminiBreaker.opened) {
    return 'El asistente está procesando muchas solicitudes. Intenta en un minuto.';
  }

  const [exercises, userContext] = await Promise.all([
    searchExercises(lastMessage),
    buildUserContext(user._id),
  ]);

  const systemPrompt = buildSystemPrompt(user, exercises, userContext);

  const model = genAI.getGenerativeModel({ model: CHAT_MODEL });

  const history = messages.slice(-MAX_HISTORY, -1).map(m => ({
    role: m.role === 'assistant' ? 'model' : 'user',
    parts: [{ text: m.content }],
  }));

  try {
    const reply = await geminiBreaker.fire({ model, history, systemPrompt, lastMessage });
    // Cachear respuestas de más de 10 caracteres
    if (reply && reply.length >= 10) {
      _setCache(cacheKey, reply);
    }
    return reply;
  } catch (err) {
    // Si el breaker devolvió fallback, ese mensaje ya es la respuesta
    if (geminiBreaker.opened) {
      return 'El asistente está procesando muchas solicitudes. Intenta en un minuto.';
    }
    // 429 detectado explícitamente
    if (err.status === 429 || (err.message && err.message.includes('429'))) {
      return 'El asistente está procesando muchas solicitudes. Intenta en un minuto.';
    }
    throw err;
  }
}

module.exports = { getCoachResponse };
