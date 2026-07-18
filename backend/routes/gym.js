const express = require('express');
const auth = require('../middleware/auth');
const Exercise = require('../models/Exercise');
const Routine = require('../models/Routine');
const Workout = require('../models/Workout');
const PersonalRecord = require('../models/PersonalRecord');
const User = require('../models/User');

const EXERCISE_XP = 5;
const STREAK_XP = 500;

const router = express.Router();

router.get('/exercises', auth, async (req, res) => {
  try {
    const { category, search } = req.query;
    const filter = {};
    if (category) filter.category = category;
    if (search) filter.name = { $regex: search, $options: 'i' };
    const exercises = await Exercise.find(filter).sort({ category: 1, name: 1 });
    res.json({ exercises });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener ejercicios' });
  }
});

router.get('/exercises/:id', auth, async (req, res) => {
  try {
    const exercise = await Exercise.findById(req.params.id);
    if (!exercise) return res.status(404).json({ error: 'Ejercicio no encontrado' });
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

    const routine = new Routine({
      user: req.user._id,
      name,
      exercises: exercises.map((e, i) => ({
        exercise: e.exerciseId,
        sets: e.sets || 3,
        reps: e.reps || '10',
        restTime: e.restTime || 60,
        order: i
      })),
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

    const routines = await Routine.find(filter)
      .populate('exercises.exercise', 'name nameSpanish category imageUrl defaultSets defaultReps videoUrl')
      .sort({ createdAt: -1 });

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
    }).populate('exercises.exercise', 'name category imageUrl defaultSets defaultReps description videoUrl');

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

    if (name) routine.name = name;
    if (exercises) {
      routine.exercises = exercises.map((e, i) => ({
        exercise: e.exerciseId,
        sets: e.sets || 3,
        reps: e.reps || '10',
        restTime: e.restTime || 60,
        order: i
      }));
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

    const workout = new Workout({
      user: req.user._id,
      routine: routineId || null,
      routineName: routineName || '',
      date: new Date(),
      duration: duration || 0,
      exercises: (exercises || []).map(e => ({
        exercise: e.exerciseId,
        exerciseName: e.exerciseName || '',
        setsCompleted: e.setsCompleted || 0,
        repsCompleted: e.repsCompleted || '',
        weightKg: e.weightKg || 0
      }))
    });

    await workout.save();

    if (exercises && exercises.length > 0) {
      for (const e of exercises) {
        const w = parseFloat(e.weightKg) || 0;
        if (w > 0 && e.exerciseId) {
          const prev = await PersonalRecord.findOne({ user: req.user._id, exercise: e.exerciseId });
          if (!prev || w > prev.maxWeightKg) {
            await PersonalRecord.findOneAndUpdate(
              { user: req.user._id, exercise: e.exerciseId },
              { user: req.user._id, exercise: e.exerciseId, exerciseName: e.exerciseName || '', maxWeightKg: w },
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
      req.user.xp = (req.user.xp || 0) + totalXp;
      const REWARDS = {
        10: 'Caminante', 20: 'Maratonista', 30: 'Ultramaratonista',
        40: 'Leyenda', 50: 'Titán'
      };
      let l = 0;
      while (1000 * (l + 1) * (l + 2) / 2 <= req.user.xp) l++;
      req.user.level = l;
      const bestTitle = Object.entries(REWARDS)
        .filter(([level]) => l >= parseInt(level))
        .sort(([a], [b]) => parseInt(b) - parseInt(a))[0];
      if (bestTitle) req.user.title = bestTitle[1];
      await req.user.save();
    }

    res.status(201).json({ workout, xpGained: totalXp });
  } catch (error) {
    res.status(500).json({ error: 'Error al registrar entrenamiento' });
  }
});

router.get('/personal-records', auth, async (req, res) => {
  try {
    const records = await PersonalRecord.find({ user: req.user._id })
      .populate('exercise', 'name category')
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

    const record = await PersonalRecord.findOneAndUpdate(
      { user: req.user._id, exercise: exerciseId },
      {
        user: req.user._id,
        exercise: exerciseId,
        exerciseName: exerciseName || '',
        maxWeightKg: weightKg
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

module.exports = router;
