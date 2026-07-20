const express = require('express');
const auth = require('../middleware/auth');
const StepEntry = require('../models/StepEntry');
const Challenge = require('../models/Challenge');
const User = require('../models/User');

const router = express.Router();

router.post('/', auth, async (req, res) => {
  try {
    const { challengeId, date, steps } = req.body;

    if (!challengeId || !date || steps === undefined || steps === null) {
      return res.status(400).json({ error: 'challengeId, date y steps son requeridos' });
    }
    if (typeof steps !== 'number' || steps < 0) {
      return res.status(400).json({ error: 'steps debe ser un número positivo' });
    }

    const challenge = await Challenge.findById(challengeId);
    if (!challenge) {
      return res.status(404).json({ error: 'Reto no encontrado' });
    }

    if (challenge.status === 'finished') {
      return res.status(400).json({ error: 'Este reto ya finalizó' });
    }

    const entryDate = new Date(date);
    if (isNaN(entryDate.getTime())) {
      return res.status(400).json({ error: 'Fecha inválida' });
    }
    entryDate.setHours(0, 0, 0, 0);

    const isParticipant = challenge.creator.toString() === req.userId.toString() ||
      (challenge.opponent && challenge.opponent.toString() === req.userId.toString());

    if (!isParticipant) {
      return res.status(403).json({ error: 'No eres participante de este reto' });
    }

    let entry = await StepEntry.findOne({
      user: req.userId,
      challenge: challengeId,
      date: entryDate
    });

    if (entry) {
      entry.steps = steps;
      await entry.save();
    } else {
      entry = new StepEntry({
        user: req.userId,
        challenge: challengeId,
        date: entryDate,
        steps
      });
      await entry.save();
    }

    const totalSteps = await StepEntry.aggregate([
      { $match: { user: req.user._id } },
      { $group: { _id: null, total: { $sum: '$steps' } } }
    ]);
    const totalXp = Math.floor((totalSteps[0]?.total || 0) / 10);
    const newLevel = (() => {
      let l = 0;
      while (1000 * (l + 1) * (l + 2) / 2 <= totalXp) l++;
      return l;
    })();
    req.user.xp = totalXp;
    req.user.level = newLevel;
    const bestReward = [10, 20, 30, 40, 50].filter(r => newLevel >= r).pop();
    const rewards = { 10: { title: 'Caminante' }, 20: { title: 'Maratonista' }, 30: { title: 'Ultramaratonista' }, 40: { title: 'Leyenda' }, 50: { title: 'Titán' } };
    if (bestReward && rewards[bestReward]?.title) {
      req.user.title = rewards[bestReward].title;
    }
    await req.user.save();

    res.json(entry);
  } catch (error) {
    res.status(500).json({ error: 'Error al guardar pasos' });
  }
});

router.get('/', auth, async (req, res) => {
  try {
    const { challengeId, date } = req.query;

    const query = { user: req.userId };
    if (challengeId) query.challenge = challengeId;
    if (date) {
      const queryDate = new Date(date);
      queryDate.setHours(0, 0, 0, 0);
      const nextDay = new Date(queryDate);
      nextDay.setDate(nextDay.getDate() + 1);
      query.date = { $gte: queryDate, $lt: nextDay };
    }

    const entries = await StepEntry.find(query).sort({ date: -1 });
    res.json({ entries });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener pasos' });
  }
});

router.get('/calendar', auth, async (req, res) => {
  try {
    const { challengeId, year, month } = req.query;

    if (!challengeId) {
      return res.status(400).json({ error: 'challengeId requerido' });
    }

    const challenge = await Challenge.findById(challengeId);
    if (!challenge) {
      return res.status(404).json({ error: 'Reto no encontrado' });
    }

    const isParticipant = challenge.creator.toString() === req.userId.toString() ||
      (challenge.opponent && challenge.opponent.toString() === req.userId.toString());
    if (!isParticipant) {
      return res.status(403).json({ error: 'No eres participante de este reto' });
    }

    const y = parseInt(year) || new Date().getFullYear();
    const m = parseInt(month) || new Date().getMonth() + 1;

    const startDate = new Date(y, m - 1, 1);
    const endDate = new Date(y, m, 0);

    const entries = await StepEntry.find({
      challenge: challengeId,
      date: { $gte: startDate, $lte: endDate }
    }).populate('user', 'username displayName avatar');

    const calendarData = [];
    for (let day = 1; day <= endDate.getDate(); day++) {
      const dayDate = new Date(y, m - 1, day);
      dayDate.setHours(0, 0, 0, 0);

      const dayEntries = entries.filter(e => {
        const eDate = new Date(e.date);
        eDate.setHours(0, 0, 0, 0);
        return eDate.getTime() === dayDate.getTime();
      });

      calendarData.push({
        date: dayDate.toISOString().split('T')[0],
        day,
        entries: dayEntries.map(e => ({
          userId: e.user._id,
          username: e.user.username,
          displayName: e.user.displayName,
          avatar: e.user.avatar,
          steps: e.steps
        }))
      });
    }

    res.json({ calendar: calendarData });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener calendario' });
  }
});

router.get('/:challengeId/analytics', auth, async (req, res) => {
  try {
    const { challengeId } = req.params;
    const { start, end } = req.query;

    const challenge = await Challenge.findById(challengeId);
    if (!challenge) {
      return res.status(404).json({ error: 'Reto no encontrado' });
    }

    const isParticipant = challenge.creator.toString() === req.userId.toString() ||
      (challenge.opponent && challenge.opponent.toString() === req.userId.toString());

    if (!isParticipant) {
      return res.status(403).json({ error: 'No eres participante de este reto' });
    }

    const startDate = start ? new Date(start) : new Date(new Date().getFullYear(), new Date().getMonth(), 1);
    const endDate = end ? new Date(end) : new Date(new Date().getFullYear(), new Date().getMonth() + 1, 0);

    const entries = await StepEntry.find({
      challenge: challengeId,
      date: { $gte: startDate, $lte: endDate }
    }).populate('user', 'username displayName avatar').sort({ date: 1 });

    res.json({ entries });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener analytics' });
  }
});

module.exports = router;
