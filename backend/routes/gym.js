const express = require('express');
const https = require('https');
const auth = require('../middleware/auth');
const Routine = require('../models/Routine');
const Workout = require('../models/Workout');
const PersonalRecord = require('../models/PersonalRecord');
const Quote = require('../models/Quote');
const User = require('../models/User');
const Exercise = require('../models/Exercise');
const { levelFromXp, bestTitleForLevel, getUserXpData } = require('../services/xpService');
const mongoose = require('mongoose');
const ExerciseProgress = require('../models/ExerciseProgress');
const { computeNext, parsePrescription } = require('../services/progressionService');

const EXERCISE_XP = 5;
const STREAK_XP = 500;
const WGER_BASE = 'https://wger.de/api/v2';

const CATEGORY_IDS = {
  strength: '8,9,10,11,12,13,14',
  cardio: '15',
};

const WGER_CAT_MAP = {
  'Abs': 'strength', 'Arms': 'strength', 'Back': 'strength',
  'Calves': 'strength', 'Cardio': 'cardio', 'Chest': 'strength',
  'Legs': 'strength', 'Shoulders': 'strength',
};

const router = express.Router();

/**
 * Mapea y valida un ejercicio de rutina (POST/PUT /routines).
 * Devuelve { value } o { error } si el rango/incremento es inválido.
 */
function mapRoutineExercise(e, i) {
  const value = {
    exercise: e.exerciseId || e.exercise,
    exerciseName: (e.exerciseName || e.name || '').toString().slice(0, 200),
    sets: Math.min(100, Math.max(1, parseInt(e.sets) || 3)),
    reps: (e.reps || '10').toString().slice(0, 20),
    restTime: Math.min(3600, Math.max(0, parseInt(e.restTime) || 60)),
    order: i,
    repsMin: null,
    repsMax: null,
    incrementKg: 2.5
  };
  const hasMin = e.repsMin !== undefined && e.repsMin !== null && e.repsMin !== '';
  const hasMax = e.repsMax !== undefined && e.repsMax !== null && e.repsMax !== '';
  if (hasMin || hasMax) {
    const min = Number(e.repsMin);
    const max = Number(e.repsMax);
    if (!Number.isInteger(min) || !Number.isInteger(max) || min < 1 || min > max || max > 100) {
      return { error: 'Rango de repeticiones inválido (1 ≤ mín ≤ máx ≤ 100)' };
    }
    value.repsMin = min;
    value.repsMax = max;
  }
  if (e.incrementKg !== undefined && e.incrementKg !== null && e.incrementKg !== '') {
    const inc = Number(e.incrementKg);
    if (!Number.isFinite(inc) || inc <= 0 || inc > 50) {
      return { error: 'Incremento inválido (entre 0 y 50 kg)' };
    }
    value.incrementKg = inc;
  }
  return { value };
}

function mapRoutineExercises(exercises) {
  const out = [];
  for (let i = 0; i < exercises.length; i++) {
    const r = mapRoutineExercise(exercises[i], i);
    if (r.error) return { error: r.error };
    out.push(r.value);
  }
  return { value: out };
}

/** Series reales de un ejercicio del workout; acota valores y descarta basura. */
function parseSetLogs(raw) {
  if (!Array.isArray(raw)) return [];
  return raw.slice(0, 20).map(s => {
    const rir = s && s.rir !== undefined && s.rir !== null ? parseInt(s.rir) : null;
    return {
      weightKg: Math.min(500, Math.max(0, parseFloat(s?.weightKg) || 0)),
      reps: Math.min(200, Math.max(0, parseInt(s?.reps) || 0)),
      seconds: Math.min(3600, Math.max(0, parseInt(s?.seconds) || 0)),
      rir: Number.isInteger(rir) ? Math.min(10, Math.max(-1, rir)) : null
    };
  });
}

function progressToResponse(p) {
  return {
    exerciseId: p.exercise,
    exerciseName: p.exerciseName || '',
    currentWeightKg: p.currentWeightKg || 0,
    currentSeconds: p.currentSeconds || 0,
    unit: p.unit || 'kg',
    loadNote: p.loadNote || '',
    status: p.status || 'calibrating',
    bridgeTargetKg: p.bridgeTargetKg || 0,
    bridgeHeavySets: p.bridgeHeavySets || 0,
    stallCount: p.stallCount || 0,
    lastSession: p.lastSession || null,
    next: p.next && p.next.action ? p.next : null
  };
}

/**
 * Corre el motor de progresión para cada ejercicio del workout y hace upsert
 * de ExerciseProgress. Devuelve la lista `progression` para la respuesta.
 */
async function updateProgression(userId, routineId, exercises) {
  const withLogs = exercises.filter(e => e.exercise && e.setLogs && e.setLogs.length > 0);
  if (!withLogs.length) return [];

  let routine = null;
  if (routineId && mongoose.Types.ObjectId.isValid(routineId)) {
    routine = await Routine.findOne({ _id: routineId, user: userId }).lean();
  }
  const ids = withLogs.map(e => e.exercise);
  const states = await ExerciseProgress.find({ user: userId, exercise: { $in: ids } }).lean();
  const stateById = new Map(states.map(s => [s.exercise, s]));

  const progression = [];
  for (const e of withLogs) {
    const routineEx = routine?.exercises?.find(r => r.exercise === e.exercise);
    const prescription = parsePrescription(e.prescription || routineEx || {
      sets: e.setLogs.length,
      reps: e.repsCompleted
    });
    const prev = stateById.get(e.exercise) || null;
    const { state, suggestion } = computeNext(prescription, prev, e.setLogs);
    const { _id, user, exercise, createdAt, updatedAt, __v, ...fields } = state;
    await ExerciseProgress.updateOne(
      { user: userId, exercise: e.exercise },
      { $set: { ...fields, exerciseName: e.exerciseName || prev?.exerciseName || '' } },
      { upsert: true }
    );
    if (suggestion) progression.push({ exerciseId: e.exercise, exerciseName: e.exerciseName || '', ...suggestion });
  }
  return progression;
}

function exerciseToResponse(ex) {
  const extUrl = ex.gifUrl || ex.imageUrl || '';
  const hasLocal = ex.localImage != null && (
    Buffer.isBuffer(ex.localImage) ? ex.localImage.length > 0 :
    typeof ex.localImage === 'object' && ex.localImage.buffer != null
  );
  const imgId = ex.externalId || ex._id;
  const localUrl = extUrl || !hasLocal || !imgId ? '' : `/api/gym/exercise-image/${imgId}`;
  const imageUrl = extUrl || localUrl || (ex.imageUrl || '');
  return {
    id: ex.externalId || String(ex._id || ''),
    name: ex.name,
    nameSpanish: ex.nameSpanish || ex.name,
    category: ex.category,
    imageUrl,
    hasImage: !!(extUrl || localUrl || ex.imageUrl),
    defaultSets: ex.defaultSets,
    defaultReps: ex.defaultReps,
    restTime: ex.restTime,
    description: ex.description || (ex.instructions || []).join(' '),
    descriptionSpanish: ex.descriptionSpanish || (ex.instructionsSpanish || []).join(' '),
    videoUrl: '',
    muscle: ex.target || ex.bodyPart || '',
    equipment: ex.equipment || '',
    difficulty: '',
  };
}

function fetchJson(url, timeoutMs = 15000) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { 'Accept': 'application/json' } }, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          return resolve(fetchJson(new URL(res.headers.location, url).href, timeoutMs));
        }
        if (res.statusCode === 200) return resolve(JSON.parse(data));
        reject(new Error(`HTTP ${res.statusCode}: ${data.slice(0, 200)}`));
      });
    })
    .on('error', reject)
    .setTimeout(timeoutMs, function () { this.destroy(); reject(new Error('Timeout')); });
  });
}

function cleanHtml(html) {
  if (!html) return '';
  return html.replace(/<[^>]*>/g, '').replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'").trim();
}

function transformWgerExercise(wgerEx) {
  const en = wgerEx.translations?.find(t => t.language === 2) || {};
  const es = wgerEx.translations?.find(t => t.language === 4) || {};
  const img = wgerEx.images?.find(i => i.is_main) || wgerEx.images?.[0] || {};
  return {
    id: `wger_${wgerEx.id}`,
    name: en.name || '',
    nameSpanish: es.name || '',
    category: WGER_CAT_MAP[wgerEx.category?.name] || 'strength',
    imageUrl: img.image || (img.thumbnails?.medium || ''),
    defaultSets: 3,
    defaultReps: '10',
    restTime: 60,
    description: cleanHtml(en.description),
    descriptionSpanish: cleanHtml(es.description),
    videoUrl: '',
    muscle: (wgerEx.muscles || []).map(m => m.name_en || m.name).join(', '),
    equipment: (wgerEx.equipment || []).map(e => e.name).join(', '),
    difficulty: '',
  };
}

router.get('/exercises', auth, async (req, res) => {
  try {
    const { search, category, limit = 20, offset = 0, excludeWarmup } = req.query;
    const lim = Math.min(parseInt(limit) || 20, 100);
    const off = parseInt(offset) || 0;

    const localCount = await Exercise.countDocuments();
    const useLocal = localCount > 0;

    if (useLocal) {
      const andClauses = [
        {
          $or: [
            { gifUrl: { $ne: '' } },
            { imageUrl: { $ne: '' } },
            { localImage: { $exists: true, $ne: null } },
          ],
        },
        {
          $or: [
            { localImageMime: { $ne: 'image/svg+xml' } },
            { localImageMime: { $exists: false } },
            { localImageMime: '' },
          ],
        },
        {
          $or: [
            { imageUrl: { $not: /wikimedia\.org/ } },
            { imageUrl: '' },
            { imageUrl: { $exists: false } },
          ],
        },
      ];
      if (category) {
        andClauses.push({ category });
      } else if (excludeWarmup === 'true') {
        andClauses.push({ category: { $ne: 'warmup' } });
      }
      if (search) {
        const terms = search.trim().split(/\s+/).filter(Boolean);
        if (terms.length === 1) {
          const escaped = terms[0].replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
          andClauses.push({
            $or: [
              { name: { $regex: `\\b${escaped}`, $options: 'i' } },
              { nameSpanish: { $regex: `\\b${escaped}`, $options: 'i' } },
            ],
          });
        } else if (terms.length > 1) {
          andClauses.push(...terms.map(t => {
            const escaped = t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
            return {
              $or: [
                { name: { $regex: `\\b${escaped}`, $options: 'i' } },
                { nameSpanish: { $regex: `\\b${escaped}`, $options: 'i' } },
              ],
            };
          }));
        }
      }
      const filter = { $and: andClauses };

      const pipeline = [
        { $match: filter },
        { $sort: { name: 1, nameSpanish: -1, imageUrl: -1, description: -1 } },
        { $group: {
          _id: '$name',
          doc: { $first: '$$ROOT' },
        }},
        { $replaceRoot: { newRoot: '$doc' } },
        { $skip: off },
        { $limit: lim },
      ];
      const localExercises = await Exercise.aggregate(pipeline);

      const totalPipeline = [
        { $match: filter },
        { $group: { _id: '$name', count: { $sum: 1 } } },
        { $count: 'total' },
      ];
      const totalResult = await Exercise.aggregate(totalPipeline);
      const total = totalResult[0]?.total || 0;

      if (localExercises.length > 0 || total > 0) {
        return res.json({
          exercises: localExercises.map(exerciseToResponse),
          total,
        });
      }

      if (!search) {
        return res.json({ exercises: [], total: 0 });
      }
    }

    const params = new URLSearchParams();
    params.set('limit', lim.toString());
    params.set('offset', off.toString());
    if (search) params.set('search', search);
    if (category && CATEGORY_IDS[category]) params.set('category', CATEGORY_IDS[category]);

    const data = await fetchJson(`${WGER_BASE}/exerciseinfo/?${params}`);
    const exercises = (data.results || []).map(transformWgerExercise);

    res.json({ exercises, total: data.count });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener ejercicios' });
  }
});

router.get('/exercise-image/:id', auth, async (req, res) => {
  try {
    const id = req.params.id;
    const isObjectId = /^[0-9a-fA-F]{24}$/.test(id);
    const ex = isObjectId
      ? await Exercise.findById(id).select('localImage localImageMime')
      : await Exercise.findOne({ externalId: id }).select('localImage localImageMime');
    if (!ex || !ex.localImage) {
      return res.status(404).json({ error: 'Imagen no encontrada' });
    }
    const buf = Buffer.isBuffer(ex.localImage) ? ex.localImage : Buffer.from(ex.localImage.buffer);
    if (buf.length === 0) {
      return res.status(404).json({ error: 'Imagen vacía' });
    }
    res.set('Content-Type', ex.localImageMime || 'image/jpeg');
    res.set('Cache-Control', 'public, max-age=31536000');
    res.send(buf);
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener imagen' });
  }
});

router.post('/exercise-image/:id', auth, async (req, res) => {
  try {
    const { image, mime } = req.body;
    if (!image) {
      return res.status(400).json({ error: 'Imagen requerida (base64)' });
    }
    const buf = Buffer.from(image, 'base64');
    if (buf.length < 100) {
      return res.status(400).json({ error: 'Imagen muy pequeña' });
    }
    const ex = await Exercise.findOneAndUpdate(
      { externalId: req.params.id },
      { $set: { localImage: buf, localImageMime: mime || 'image/jpeg' } },
      { new: true }
    );
    if (!ex) return res.status(404).json({ error: 'Ejercicio no encontrado' });
    res.json({ success: true, size: buf.length });
  } catch (error) {
    res.status(500).json({ error: 'Error al guardar imagen' });
  }
});

router.get('/exercises/:id', auth, async (req, res) => {
  try {
    const id = req.params.id;

    if (id.startsWith('exercisedb_')) {
      const ex = await Exercise.findOne({ externalId: id });
      if (!ex) return res.status(404).json({ error: 'Ejercicio no encontrado' });
      return res.json({ exercise: exerciseToResponse(ex) });
    }

    if (id.startsWith('wger_')) {
      const wgerId = id.replace('wger_', '');
      const data = await fetchJson(`${WGER_BASE}/exerciseinfo/${wgerId}/`);
      const exercise = transformWgerExercise(data);
      if (!exercise.name) return res.status(404).json({ error: 'Ejercicio no encontrado' });
      return res.json({ exercise });
    }

    const ex = await Exercise.findOne({ externalId: id });
    if (ex) return res.json({ exercise: exerciseToResponse(ex) });

    const data = await fetchJson(`${WGER_BASE}/exerciseinfo/${id}/`);
    const exercise = transformWgerExercise(data);
    if (!exercise.name) return res.status(404).json({ error: 'Ejercicio no encontrado' });
    res.json({ exercise });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener ejercicio' });
  }
});

router.post('/routines', auth, async (req, res) => {
  try {
    const { name, exercises, isWarmup } = req.body;

    if (!name || !exercises || exercises.length === 0) {
      return res.status(400).json({ error: 'Nombre y ejercicios requeridos' });
    }
    if (typeof name !== 'string' || name.trim().length < 1 || name.trim().length > 60) {
      return res.status(400).json({ error: 'El nombre de la rutina debe tener entre 1 y 60 caracteres' });
    }
    if (exercises.length > 50) {
      return res.status(400).json({ error: 'Máximo 50 ejercicios por rutina' });
    }

    const existing = await Routine.findOne({ user: req.user._id, name: name.trim() });
    if (existing) {
      return res.status(409).json({ error: 'Ya tienes una rutina con ese nombre' });
    }

    const mapped = mapRoutineExercises(exercises);
    if (mapped.error) return res.status(400).json({ error: mapped.error });

    const routine = new Routine({
      user: req.user._id,
      name: name.trim(),
      exercises: mapped.value,
      isWarmup: isWarmup || false
    });

    await routine.save();
    res.status(201).json({ routine });
  } catch (error) {
    res.status(500).json({ error: 'Error al crear rutina' });
  }
});

router.get('/routines', auth, async (req, res) => {
  try {
    const { isWarmup } = req.query;
    const filter = { user: req.user._id };
    if (isWarmup !== undefined) filter.isWarmup = isWarmup === 'true';

    const routines = await Routine.find(filter).sort({ createdAt: -1 });

    res.json({ routines });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener rutinas' });
  }
});

router.get('/routines/:id', auth, async (req, res) => {
  try {
    const routine = await Routine.findOne({
      _id: req.params.id,
      user: req.user._id
    });

    if (!routine) return res.status(404).json({ error: 'Rutina no encontrada' });

    res.json({ routine });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener rutina' });
  }
});

router.put('/routines/:id', auth, async (req, res) => {
  try {
    const { name, exercises, isWarmup } = req.body;
    const routine = await Routine.findOne({ _id: req.params.id, user: req.user._id });

    if (!routine) return res.status(404).json({ error: 'Rutina no encontrada' });

    if (name && name !== routine.name) {
      const duplicate = await Routine.findOne({ user: req.user._id, name, _id: { $ne: req.params.id } });
      if (duplicate) {
        return res.status(409).json({ error: 'Ya tienes una rutina con ese nombre' });
      }
      routine.name = name;
    }
    if (exercises) {
      if (exercises.length > 50) {
        return res.status(400).json({ error: 'Máximo 50 ejercicios por rutina' });
      }
      const mapped = mapRoutineExercises(exercises);
      if (mapped.error) return res.status(400).json({ error: mapped.error });
      routine.exercises = mapped.value;
    }
    if (isWarmup !== undefined) routine.isWarmup = isWarmup;

    await routine.save();
    res.json({ routine });
  } catch (error) {
    res.status(500).json({ error: 'Error al actualizar rutina' });
  }
});

router.delete('/routines/:id', auth, async (req, res) => {
  try {
    const routine = await Routine.findOneAndDelete({
      _id: req.params.id,
      user: req.user._id
    });

    if (!routine) return res.status(404).json({ error: 'Rutina no encontrada' });

    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Error al eliminar rutina' });
  }
});

router.post('/workouts', auth, async (req, res) => {
  try {
    const { routineId, routineName, duration, exercises } = req.body;

    if (duration !== undefined && (typeof duration !== 'number' || duration < 0 || duration > 86400)) {
      return res.status(400).json({ error: 'Duración inválida' });
    }
    if (exercises && exercises.length > 50) {
      return res.status(400).json({ error: 'Máximo 50 ejercicios por entrenamiento' });
    }

    const validRoutineId = routineId && mongoose.Types.ObjectId.isValid(routineId) ? routineId : null;

    const mappedExercises = (exercises || []).map(e => {
      const setLogs = parseSetLogs(e.setLogs);
      if (setLogs.length > 0) {
        // Con detalle por serie, el resumen se calcula en el servidor.
        return {
          exercise: e.exerciseId,
          exerciseName: (e.exerciseName || '').toString().slice(0, 200),
          setsCompleted: setLogs.length,
          repsCompleted: setLogs.map(s => (s.seconds > 0 && s.reps === 0 ? `${s.seconds}s` : String(s.reps))).join(',').slice(0, 50),
          weightKg: Math.max(...setLogs.map(s => s.weightKg)),
          setLogs
        };
      }
      return {
        exercise: e.exerciseId,
        exerciseName: (e.exerciseName || '').toString().slice(0, 200),
        setsCompleted: Math.max(0, parseInt(e.setsCompleted) || 0),
        repsCompleted: (e.repsCompleted || '').toString().slice(0, 50),
        weightKg: Math.min(500, Math.max(0, parseFloat(e.weightKg) || 0))
      };
    });

    const workout = new Workout({
      user: req.user._id,
      routine: validRoutineId,
      routineName: routineName || '',
      date: new Date(),
      duration: duration || 0,
      exercises: mappedExercises
    });

    await workout.save();

    // Progresión de carga: un fallo del motor nunca impide guardar el workout.
    let progression = [];
    try {
      const forEngine = mappedExercises.map((mapped, i) => {
        // Prescripción enviada por la app (la usada hoy); validada igual que una rutina.
        const raw = exercises[i] && exercises[i].prescription;
        const prescription = raw && typeof raw === 'object'
          ? mapRoutineExercise({ ...raw, exerciseId: mapped.exercise }, 0).value
          : undefined;
        const e = { ...mapped, prescription };
        if (e.setLogs) return e;
        // Versión antigua de la app: sesión aproximada solo si hay reps numéricas y peso.
        const reps = parseInt(e.repsCompleted);
        if (e.setsCompleted > 0 && e.weightKg > 0 && /^\d+$/.test(e.repsCompleted.trim()) && reps > 0) {
          return { ...e, setLogs: Array.from({ length: Math.min(20, e.setsCompleted) }, () => ({ weightKg: e.weightKg, reps })) };
        }
        return e;
      });
      progression = await updateProgression(req.user._id, validRoutineId, forEngine);
    } catch (err) {
      console.error('Error en progresión de carga:', err.message);
    }

    if (mappedExercises.length > 0) {
      for (const e of mappedExercises) {
        const w = e.weightKg || 0;
        if (w > 0 && w <= 500 && e.exercise) {
          const prev = await PersonalRecord.findOne({ user: req.user._id, exercise: e.exercise });
          if (!prev || w > prev.maxWeightKg) {
            await PersonalRecord.findOneAndUpdate(
              { user: req.user._id, exercise: e.exercise },
              { user: req.user._id, exercise: e.exercise, exerciseName: e.exerciseName || '', maxWeightKg: w },
              { upsert: true, new: true }
            );
          }
        }
      }
    }

    const exerciseXp = (exercises?.length || 0) * EXERCISE_XP;

    const weekStart = new Date();
    const day = weekStart.getDay();
    const diff = weekStart.getDate() - day + (day === 0 ? -6 : 1);
    weekStart.setDate(diff);
    weekStart.setHours(0, 0, 0, 0);

    const lastWeekStart = new Date(weekStart);
    lastWeekStart.setDate(lastWeekStart.getDate() - 7);

    const previousWorkout = await Workout.findOne({
      user: req.user._id,
      date: { $gte: lastWeekStart, $lt: weekStart }
    });

    const streakXp = previousWorkout ? STREAK_XP : 0;
    const totalXp = exerciseXp + streakXp;

    if (totalXp > 0) {
      req.user.gymXp = (req.user.gymXp || 0) + totalXp;
      const { totalXp: computedXp, level } = await getUserXpData(req.user);
      req.user.xp = computedXp;
      req.user.level = level;
      const title = bestTitleForLevel(level);
      if (title) req.user.title = title;
      await req.user.save();
    }

    res.status(201).json({ workout, xpGained: totalXp, progression });
  } catch (error) {
    res.status(500).json({ error: 'Error al registrar entrenamiento' });
  }
});

// Estado y sugerencia vigente por ejercicio, para precargar el entrenamiento.
router.get('/progress', auth, async (req, res) => {
  try {
    const filter = { user: req.user._id };
    const ids = (req.query.exerciseIds || '').toString().split(',').map(s => s.trim()).filter(Boolean).slice(0, 100);
    if (ids.length) filter.exercise = { $in: ids };
    const list = await ExerciseProgress.find(filter).sort({ updatedAt: -1 }).limit(200).lean();
    res.json({ progress: list.map(progressToResponse) });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener progresión' });
  }
});

// Ajuste manual de la base: reinicia estancamiento y puente.
router.put('/progress/:exerciseId', auth, async (req, res) => {
  try {
    const { currentWeightKg, unit, loadNote, exerciseName } = req.body;
    const set = {};
    if (currentWeightKg !== undefined) {
      const w = Number(currentWeightKg);
      if (!Number.isFinite(w) || w < 0 || w > 500) {
        return res.status(400).json({ error: 'currentWeightKg debe estar entre 0 y 500' });
      }
      Object.assign(set, {
        currentWeightKg: w,
        previousWeightKg: 0,
        status: w > 0 ? 'progressing' : 'calibrating',
        stallCount: 0,
        bridgeTargetKg: 0,
        bridgeHeavySets: 0,
        next: null
      });
    }
    if (unit !== undefined) {
      if (unit !== 'kg' && unit !== 'lb') return res.status(400).json({ error: 'unit debe ser kg o lb' });
      set.unit = unit;
    }
    if (loadNote !== undefined) set.loadNote = loadNote.toString().slice(0, 60);
    if (exerciseName !== undefined) set.exerciseName = exerciseName.toString().slice(0, 200);
    if (!Object.keys(set).length) return res.status(400).json({ error: 'Nada que actualizar' });

    const progress = await ExerciseProgress.findOneAndUpdate(
      { user: req.user._id, exercise: req.params.exerciseId.toString().slice(0, 100) },
      { $set: set },
      { upsert: true, new: true, lean: true }
    );
    res.json({ progress: progressToResponse(progress) });
  } catch (error) {
    res.status(500).json({ error: 'Error al actualizar progresión' });
  }
});

router.get('/personal-records', auth, async (req, res) => {
  try {
    const records = await PersonalRecord.find({ user: req.user._id })
      .sort({ maxWeightKg: -1 });
    res.json({ records });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener marcas personales' });
  }
});

router.post('/personal-record', auth, async (req, res) => {
  try {
    const { exerciseId, weightKg, exerciseName } = req.body;
    if (!exerciseId || !weightKg) {
      return res.status(400).json({ error: 'exerciseId y weightKg requeridos' });
    }
    const w = parseFloat(weightKg);
    if (isNaN(w) || w <= 0 || w > 500) {
      return res.status(400).json({ error: 'weightKg debe ser un número entre 0 y 500' });
    }

    const record = await PersonalRecord.findOneAndUpdate(
      { user: req.user._id, exercise: exerciseId },
      {
        user: req.user._id,
        exercise: exerciseId,
        exerciseName: (exerciseName || '').toString().slice(0, 200),
        maxWeightKg: w
      },
      { upsert: true, new: true }
    );

    res.json({ record });
  } catch (error) {
    res.status(500).json({ error: 'Error al guardar marca personal' });
  }
});

router.get('/streak', auth, async (req, res) => {
  try {
    const workouts = await Workout.find({ user: req.user._id })
      .sort({ date: -1 })
      .select('date')
      .limit(52)
      .lean();

    if (workouts.length === 0) {
      return res.json({ streak: 0, currentWeekChecked: false });
    }

    const today = new Date();
    const getWeekStart = (d) => {
      const date = new Date(d);
      const day = date.getDay();
      const diff = date.getDate() - day + (day === 0 ? -6 : 1);
      date.setDate(diff);
      date.setHours(0, 0, 0, 0);
      return date;
    };

    const currentWeekStart = getWeekStart(today);
    const currentWeekChecked = workouts.some(w => {
      const ws = getWeekStart(new Date(w.date));
      return ws.getTime() === currentWeekStart.getTime();
    });

    let streak = 0;
    let checkDate = new Date(currentWeekStart);

    while (true) {
      const hasWorkout = workouts.some(w => {
        const ws = getWeekStart(new Date(w.date));
        return ws.getTime() === checkDate.getTime();
      });

      if (hasWorkout) {
        streak++;
        checkDate.setDate(checkDate.getDate() - 7);
      } else {
        break;
      }
    }

    res.json({ streak, currentWeekChecked, weekStart: currentWeekStart });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener racha' });
  }
});

router.get('/workouts', auth, async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 20;
    const workouts = await Workout.find({ user: req.user._id })
      .sort({ date: -1 })
      .limit(limit);
    res.json({ workouts });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener entrenamientos' });
  }
});

router.get('/weight-achievements', auth, async (req, res) => {
  try {
    const milestones = [
      { key: 'pr_25', minKg: 25, title: 'Principiante', description: 'Levanta 25kg en un ejercicio' },
      { key: 'pr_50', minKg: 50, title: 'Intermedio', description: 'Levanta 50kg en un ejercicio' },
      { key: 'pr_75', minKg: 75, title: 'Avanzado', description: 'Levanta 75kg en un ejercicio' },
      { key: 'pr_100', minKg: 100, title: 'Experto', description: 'Levanta 100kg en un ejercicio' },
      { key: 'pr_150', minKg: 150, title: 'Élite', description: 'Levanta 150kg en un ejercicio' },
      { key: 'pr_200', minKg: 200, title: 'Master', description: 'Levanta 200kg en un ejercicio' },
    ];

    const topPR = await PersonalRecord.findOne({ user: req.user._id })
      .sort({ maxWeightKg: -1 })
      .select('maxWeightKg');

    const maxKg = topPR?.maxWeightKg || 0;

    const achievements = milestones.map(m => ({
      ...m,
      unlocked: maxKg >= m.minKg,
    }));

    res.json({ achievements, maxKg });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener logros de peso' });
  }
});

router.get('/quote', auth, async (req, res) => {
  try {
    const user = await User.findById(req.user._id).select('createdAt');
    if (!user) return res.json({ quote: null });

    const monthsSinceSignup = Math.floor(
      (Date.now() - new Date(user.createdAt).getTime()) / (1000 * 60 * 60 * 24 * 30)
    );
    const weeks = parseInt(req.query.weeks) || 0;

    let quote = null;

    if (weeks >= 10) {
      quote = await Quote.findOne({
        type: 'streak',
        minWeeks: { $lte: weeks },
        active: true
      }).sort({ minWeeks: -1 });
    }

    if (!quote) {
      quote = await Quote.findOne({
        type: 'anniversary',
        minMonths: { $lte: monthsSinceSignup },
        active: true
      }).sort({ minMonths: -1 });
    }

    res.json({
      quote: quote ? { text: quote.text, type: quote.type } : null,
      weeks,
      months: monthsSinceSignup
    });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener frase' });
  }
});

module.exports = router;
