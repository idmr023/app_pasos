const express = require('express');
const mongoose = require('mongoose');
const auth = require('../middleware/auth');
const TrainingSession = require('../models/TrainingSession');
const TrainingProfile = require('../models/TrainingProfile');
const { getStravaAccessToken, stravaGet, StravaError, hasStrava } = require('../services/stravaClient');
const analysis = require('../services/trainingAnalysisService');

// Módulo Entrenamiento: sesiones de resistencia (importadas de Strava a elección
// del usuario o manuales), análisis por sesión y resumen de progresión.
// Ver docs/TRAINING.md.

const router = express.Router();

const SESSION_TYPES = ['auto', 'recovery', 'easy', 'long', 'tempo', 'intervals', 'race', 'other'];
const SPORTS = ['run', 'trail', 'ride', 'walk', 'hike', 'swim', 'other'];
const MAX_IMPORT = 15;
const SUMMARY_DAYS = 180;

function mapStravaSport(act) {
  const t = act.sport_type || act.type || '';
  if (t === 'TrailRun') return 'trail';
  if (['Run', 'VirtualRun'].includes(t)) return 'run';
  if (/Ride$/.test(t) || t === 'Velomobile' || t === 'Handcycle') return 'ride';
  if (t === 'Walk') return 'walk';
  if (t === 'Hike') return 'hike';
  if (t === 'Swim') return 'swim';
  return 'other';
}

function toSessionFromStrava(userId, act) {
  const sport = mapStravaSport(act);
  const isRunSport = sport === 'run' || sport === 'trail';
  const num = (v) => (Number.isFinite(v) ? v : 0);
  const rpe = Number.isFinite(act.perceived_exertion) ? Math.round(act.perceived_exertion) : null;
  return {
    user: userId,
    source: 'strava',
    stravaActivityId: act.id,
    title: (act.name || 'Actividad Strava').slice(0, 120),
    sport,
    startDate: act.start_date ? new Date(act.start_date) : new Date(),
    distance: Math.round(num(act.distance)),
    movingTime: Math.round(num(act.moving_time)),
    elapsedTime: Math.round(num(act.elapsed_time)),
    elevationGain: Math.round(num(act.total_elevation_gain)),
    averageSpeed: num(act.average_speed),
    maxSpeed: num(act.max_speed),
    averageHeartRate: Math.round(num(act.average_heartrate)),
    maxHeartRate: Math.round(num(act.max_heartrate)),
    // Strava reporta la cadencia de carrera por pierna → se duplica a pasos/min.
    averageCadence: Math.round(num(act.average_cadence) * (isRunSport ? 2 : 1)),
    calories: Math.round(num(act.calories)),
    stravaWorkoutType: Number.isFinite(act.workout_type) ? act.workout_type : null,
    splits: (act.splits_metric || []).map((s, i) => ({
      index: s.split || i + 1,
      distance: num(s.distance),
      movingTime: num(s.moving_time),
      elevationDiff: num(s.elevation_difference),
      averageHeartRate: Math.round(num(s.average_heartrate)),
      averageSpeed: num(s.average_speed)
    })),
    laps: (act.laps || []).slice(0, 100).map((l, i) => ({
      index: l.lap_index || i + 1,
      name: l.name || `Vuelta ${i + 1}`,
      distance: num(l.distance),
      movingTime: num(l.moving_time),
      averageSpeed: num(l.average_speed),
      averageHeartRate: Math.round(num(l.average_heartrate)),
      maxHeartRate: Math.round(num(l.max_heartrate))
    })),
    bestEfforts: (act.best_efforts || []).map((e) => ({
      name: e.name,
      distance: num(e.distance),
      elapsedTime: num(e.elapsed_time)
    })),
    ...(rpe && rpe >= 1 && rpe <= 10 ? { rpe } : {})
  };
}

async function loadProfile(userId) {
  return TrainingProfile.findOne({ user: userId }).lean();
}

function publicSession(s, a) {
  const { splits, laps, bestEfforts, __v, ...rest } = s;
  return { ...rest, analysis: { type: a.type, load: a.load, loadSource: a.loadSource, pace: a.pace, hrPercentMax: a.hrPercentMax } };
}

function sendStravaError(res, err, fallback) {
  if (err instanceof StravaError) return res.status(err.status).json({ error: err.message });
  const status = err.response?.status;
  if (status === 429) return res.status(429).json({ error: 'Strava limitó las peticiones. Espera 15 minutos e intenta de nuevo.' });
  if (status === 401) return res.status(401).json({ error: 'La conexión con Strava expiró, vuelve a conectar' });
  return res.status(500).json({ error: fallback });
}

// --- Perfil ---------------------------------------------------------------

router.get('/profile', auth, async (req, res) => {
  try {
    const profile = await loadProfile(req.user._id);
    res.json({ profile: profile || { maxHeartRate: null, restingHeartRate: null, weeklySessions: 4, goal: null } });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener perfil de entrenamiento' });
  }
});

router.put('/profile', auth, async (req, res) => {
  try {
    const { maxHeartRate, restingHeartRate, weeklySessions, goal } = req.body;
    const update = {};
    const intIn = (v, lo, hi) => v === null || (Number.isInteger(v) && v >= lo && v <= hi);

    if (maxHeartRate !== undefined) {
      if (!intIn(maxHeartRate, 120, 230)) return res.status(400).json({ error: 'FC máxima debe estar entre 120 y 230' });
      update.maxHeartRate = maxHeartRate;
    }
    if (restingHeartRate !== undefined) {
      if (!intIn(restingHeartRate, 30, 100)) return res.status(400).json({ error: 'FC en reposo debe estar entre 30 y 100' });
      update.restingHeartRate = restingHeartRate;
    }
    if (weeklySessions !== undefined) {
      if (!intIn(weeklySessions, 2, 7) || weeklySessions === null) return res.status(400).json({ error: 'Sesiones por semana: entre 2 y 7' });
      update.weeklySessions = weeklySessions;
    }
    if (goal !== undefined) {
      if (goal === null) {
        update.goal = { name: '', distanceKm: null, targetTimeSec: null, date: null };
      } else {
        const distanceKm = Number(goal.distanceKm);
        if (!Number.isFinite(distanceKm) || distanceKm < 1 || distanceKm > 250) {
          return res.status(400).json({ error: 'Distancia del objetivo inválida' });
        }
        const targetTimeSec = goal.targetTimeSec == null ? null : Number(goal.targetTimeSec);
        if (targetTimeSec !== null && (!Number.isFinite(targetTimeSec) || targetTimeSec < 300)) {
          return res.status(400).json({ error: 'Tiempo objetivo inválido' });
        }
        const date = goal.date ? new Date(goal.date) : null;
        if (date && isNaN(date.getTime())) return res.status(400).json({ error: 'Fecha del objetivo inválida' });
        update.goal = {
          name: typeof goal.name === 'string' ? goal.name.trim().slice(0, 60) : '',
          distanceKm,
          targetTimeSec: targetTimeSec ? Math.round(targetTimeSec) : null,
          date
        };
      }
    }

    const profile = await TrainingProfile.findOneAndUpdate(
      { user: req.user._id },
      { $set: update },
      { new: true, upsert: true, setDefaultsOnInsert: true }
    ).lean();
    res.json({ profile });
  } catch (error) {
    res.status(500).json({ error: 'Error al guardar perfil de entrenamiento' });
  }
});

// --- Resumen --------------------------------------------------------------

router.get('/summary', auth, async (req, res) => {
  try {
    const since = new Date(Date.now() - SUMMARY_DAYS * 24 * 60 * 60 * 1000);
    const [sessions, profile] = await Promise.all([
      TrainingSession.find({ user: req.user._id, startDate: { $gte: since } }).select('-laps').lean(),
      loadProfile(req.user._id)
    ]);
    const summary = analysis.buildTrainingSummary(sessions, profile, new Date());
    res.json({ summary, profile: profile || null, hasStrava: hasStrava(req.user) });
  } catch (error) {
    console.error('[Training] summary error:', error.message);
    res.status(500).json({ error: 'Error al calcular el resumen de entrenamiento' });
  }
});

// --- Sesiones -------------------------------------------------------------

router.get('/sessions', auth, async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit) || 30, 100);
    const filter = { user: req.user._id };
    if (req.query.before) {
      const before = new Date(req.query.before);
      if (!isNaN(before.getTime())) filter.startDate = { $lt: before };
    }
    const [sessions, profile] = await Promise.all([
      TrainingSession.find(filter).sort({ startDate: -1 }).limit(limit).lean(),
      loadProfile(req.user._id)
    ]);
    const hr = analysis.heartRateContext(profile, sessions);
    res.json({ sessions: sessions.map((s) => publicSession(s, analysis.analyzeSession(s, hr))) });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener sesiones' });
  }
});

router.get('/sessions/:id', auth, async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(404).json({ error: 'Sesión no encontrada' });
    const session = await TrainingSession.findOne({ _id: req.params.id, user: req.user._id }).lean();
    if (!session) return res.status(404).json({ error: 'Sesión no encontrada' });

    const [history, profile] = await Promise.all([
      TrainingSession.find({ user: req.user._id, sport: session.sport, startDate: { $lt: session.startDate } })
        .sort({ startDate: -1 }).limit(40).lean(),
      loadProfile(req.user._id)
    ]);
    const hr = analysis.heartRateContext(profile, [session, ...history]);
    for (const h of history) h._classifiedType = analysis.analyzeSession(h, hr).type;

    res.json({ session: { ...session, analysis: analysis.analyzeSession(session, hr, history) }, heartRate: hr });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener sesión' });
  }
});

function validateAnnotations(body, out) {
  const { sessionType, rpe, feeling, notes, title } = body;
  if (sessionType !== undefined) {
    if (!SESSION_TYPES.includes(sessionType)) return 'Tipo de sesión inválido';
    out.sessionType = sessionType;
  }
  if (rpe !== undefined) {
    if (rpe !== null && !(Number.isInteger(rpe) && rpe >= 1 && rpe <= 10)) return 'RPE debe ser 1–10';
    out.rpe = rpe;
  }
  if (feeling !== undefined) {
    if (feeling !== null && !(Number.isInteger(feeling) && feeling >= 1 && feeling <= 5)) return 'Sensación debe ser 1–5';
    out.feeling = feeling;
  }
  if (notes !== undefined) {
    if (typeof notes !== 'string' || notes.length > 1000) return 'Notas: máximo 1000 caracteres';
    out.notes = notes;
  }
  if (title !== undefined) {
    if (typeof title !== 'string' || !title.trim() || title.length > 120) return 'Título inválido';
    out.title = title.trim();
  }
  return null;
}

router.post('/sessions', auth, async (req, res) => {
  try {
    const b = req.body;
    const doc = { user: req.user._id, source: 'manual' };
    const error = validateAnnotations(b, doc);
    if (error) return res.status(400).json({ error });

    const sport = b.sport || 'run';
    if (!SPORTS.includes(sport)) return res.status(400).json({ error: 'Deporte inválido' });
    const startDate = b.startDate ? new Date(b.startDate) : new Date();
    if (isNaN(startDate.getTime())) return res.status(400).json({ error: 'Fecha inválida' });
    const distance = Number(b.distance) || 0;
    const movingTime = Number(b.movingTime) || 0;
    if (movingTime <= 0 || movingTime > 24 * 3600) return res.status(400).json({ error: 'Duración inválida' });
    if (distance < 0 || distance > 400000) return res.status(400).json({ error: 'Distancia inválida' });
    const hrVal = (v) => {
      const n = parseInt(v);
      return Number.isFinite(n) && n >= 30 && n <= 240 ? n : 0;
    };

    Object.assign(doc, {
      sport,
      startDate,
      title: doc.title || 'Entrenamiento manual',
      distance: Math.round(distance),
      movingTime: Math.round(movingTime),
      elapsedTime: Math.round(movingTime),
      averageSpeed: distance > 0 ? distance / movingTime : 0,
      elevationGain: Math.max(0, Math.round(Number(b.elevationGain) || 0)),
      averageHeartRate: hrVal(b.averageHeartRate),
      maxHeartRate: hrVal(b.maxHeartRate),
      averageCadence: Math.max(0, Math.round(Number(b.averageCadence) || 0))
    });

    const session = await TrainingSession.create(doc);
    res.status(201).json({ session: session.toObject() });
  } catch (error) {
    res.status(500).json({ error: 'Error al registrar sesión' });
  }
});

router.put('/sessions/:id', auth, async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(404).json({ error: 'Sesión no encontrada' });
    const update = {};
    const error = validateAnnotations(req.body, update);
    if (error) return res.status(400).json({ error });

    const session = await TrainingSession.findOneAndUpdate(
      { _id: req.params.id, user: req.user._id },
      { $set: update },
      { new: true }
    ).lean();
    if (!session) return res.status(404).json({ error: 'Sesión no encontrada' });
    res.json({ session });
  } catch (error) {
    res.status(500).json({ error: 'Error al actualizar sesión' });
  }
});

router.delete('/sessions/:id', auth, async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) return res.status(404).json({ error: 'Sesión no encontrada' });
    const deleted = await TrainingSession.findOneAndDelete({ _id: req.params.id, user: req.user._id });
    if (!deleted) return res.status(404).json({ error: 'Sesión no encontrada' });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Error al eliminar sesión' });
  }
});

// --- Strava: elegir qué actividades importar -------------------------------

router.get('/strava/activities', auth, async (req, res) => {
  try {
    const page = Math.max(parseInt(req.query.page) || 1, 1);
    const perPage = Math.min(parseInt(req.query.perPage) || 30, 50);
    const token = await getStravaAccessToken(req.user);
    const acts = await stravaGet(token, '/athlete/activities', { page, per_page: perPage });

    const ids = acts.map((a) => a.id);
    const imported = await TrainingSession.find({ user: req.user._id, stravaActivityId: { $in: ids } })
      .select('_id stravaActivityId').lean();
    const importedMap = new Map(imported.map((s) => [s.stravaActivityId, String(s._id)]));

    res.json({
      page,
      hasMore: acts.length === perPage,
      activities: acts.map((a) => ({
        id: a.id,
        name: a.name,
        sport: mapStravaSport(a),
        sportType: a.sport_type || a.type,
        startDate: a.start_date,
        distance: Math.round(a.distance || 0),
        movingTime: a.moving_time || 0,
        elevationGain: Math.round(a.total_elevation_gain || 0),
        averageHeartRate: a.average_heartrate ? Math.round(a.average_heartrate) : 0,
        workoutType: a.workout_type ?? null,
        imported: importedMap.has(a.id),
        sessionId: importedMap.get(a.id) || null
      }))
    });
  } catch (error) {
    sendStravaError(res, error, 'Error al obtener actividades de Strava');
  }
});

router.post('/strava/import', auth, async (req, res) => {
  try {
    const raw = Array.isArray(req.body.activityIds) ? req.body.activityIds : [];
    const ids = [...new Set(raw.map(Number).filter((n) => Number.isSafeInteger(n) && n > 0))];
    if (ids.length === 0) return res.status(400).json({ error: 'Selecciona al menos una actividad' });
    if (ids.length > MAX_IMPORT) return res.status(400).json({ error: `Máximo ${MAX_IMPORT} actividades por importación` });

    const token = await getStravaAccessToken(req.user);
    const imported = [];
    const failed = [];
    let rateLimited = false;

    // Secuencial: el detalle (splits, vueltas, mejores esfuerzos) cuesta 1 petición
    // por actividad y Strava limita a ~100 por 15 min.
    for (const id of ids) {
      if (rateLimited) {
        failed.push({ id, reason: 'rate_limited' });
        continue;
      }
      try {
        const act = await stravaGet(token, `/activities/${id}`, { include_all_efforts: false });
        const doc = toSessionFromStrava(req.user._id, act);
        const { rpe, ...stravaFields } = doc;
        // Reimportar refresca los datos de Strava sin pisar lo que anotó el atleta.
        const update = { $set: stravaFields };
        if (rpe) update.$setOnInsert = { rpe };
        const session = await TrainingSession.findOneAndUpdate(
          { user: req.user._id, stravaActivityId: id },
          update,
          { new: true, upsert: true, setDefaultsOnInsert: true }
        ).lean();
        imported.push(session._id);
      } catch (err) {
        if (err.response?.status === 429) rateLimited = true;
        failed.push({ id, reason: err.response?.status === 404 ? 'not_found' : err.response?.status === 429 ? 'rate_limited' : 'error' });
      }
    }

    res.json({ success: true, importedCount: imported.length, sessionIds: imported, failed });
  } catch (error) {
    sendStravaError(res, error, 'Error al importar desde Strava');
  }
});

module.exports = router;
