const express = require('express');
const auth = require('../middleware/auth');
const Exercise = require('../models/Exercise');
const Routine = require('../models/Routine');
const Workout = require('../models/Workout');

const router = express.Router();

router.get('/exercises', auth, async (req, res) => {
  try {
    const { category } = req.query;
    const filter = category ? { category } : {};
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
      .populate('exercises.exercise', 'name category imageUrl defaultSets defaultReps')
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
    }).populate('exercises.exercise', 'name category imageUrl defaultSets defaultReps description');

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
        repsCompleted: e.repsCompleted || ''
      }))
    });

    await workout.save();
    res.status(201).json({ workout });
  } catch (error) {
    res.status(500).json({ error: 'Error al registrar entrenamiento' });
  }
});

router.get('/streak', auth, async (req, res) => {
  try {
    const workouts = await Workout.find({ user: req.user._id })
      .sort({ date: -1 })
      .select('date');

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

module.exports = router;