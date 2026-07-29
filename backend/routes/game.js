const express = require('express');
const auth = require('../middleware/auth');
const GameScore = require('../models/GameScore');
const StepEntry = require('../models/StepEntry');
const User = require('../models/User');

const router = express.Router();

const STEPS_PER_ATTEMPT = 2000;
const MAX_ATTEMPTS_PER_DAY = 5;
const MULTIPLIER_LEVEL = 5;
const MULTIPLIER_BONUS = 0.5;

function getTodayRange() {
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const end = new Date(start);
  end.setDate(end.getDate() + 1);
  return { start, end };
}

function xpForLevel(level) {
  return 1000 * level * (level + 1) / 2;
}

function levelFromXp(totalXp) {
  let l = 0;
  while (xpForLevel(l + 1) <= totalXp) l++;
  return l;
}

// GET /api/game/fuel
router.get('/fuel', auth, async (req, res) => {
  try {
    const { start, end } = getTodayRange();

    const todaySteps = await StepEntry.aggregate([
      {
        $match: {
          user: req.user._id,
          date: { $gte: start, $lt: end }
        }
      },
      { $group: { _id: null, total: { $sum: '$steps' } } }
    ]);

    const steps = todaySteps[0]?.total || 0;
    const maxAttempts = Math.min(Math.floor(steps / STEPS_PER_ATTEMPT), MAX_ATTEMPTS_PER_DAY);

    const gamesToday = await GameScore.countDocuments({
      user: req.user._id,
      createdAt: { $gte: start, $lt: end }
    });

    const attempts = Math.max(0, maxAttempts - gamesToday);
    const stepsUntilNext = steps >= MAX_ATTEMPTS_PER_DAY * STEPS_PER_ATTEMPT
      ? 0
      : STEPS_PER_ATTEMPT - (steps % STEPS_PER_ATTEMPT);

    const bestGameToday = await GameScore.findOne({
      user: req.user._id,
      createdAt: { $gte: start, $lt: end }
    }).sort({ level: -1 });

    const hasMultiplier = bestGameToday ? bestGameToday.level >= MULTIPLIER_LEVEL : false;

    res.json({
      attempts,
      usedToday: gamesToday,
      maxAttempts,
      stepsUntilNext,
      stepsToday: steps,
      hasMultiplier,
      bestLevelToday: bestGameToday?.level || 0
    });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener combustible' });
  }
});

// POST /api/game/play
router.post('/play', auth, async (req, res) => {
  try {
    const { level, asteroidsDodged, score } = req.body;

    if (level == null || asteroidsDodged == null || score == null) {
      return res.status(400).json({ error: 'Faltan campos: level, asteroidsDodged, score' });
    }

    const { start, end } = getTodayRange();

    const todaySteps = await StepEntry.aggregate([
      {
        $match: {
          user: req.user._id,
          date: { $gte: start, $lt: end }
        }
      },
      { $group: { _id: null, total: { $sum: '$steps' } } }
    ]);

    const steps = todaySteps[0]?.total || 0;
    const maxAttempts = Math.min(Math.floor(steps / STEPS_PER_ATTEMPT), MAX_ATTEMPTS_PER_DAY);

    const gamesToday = await GameScore.countDocuments({
      user: req.user._id,
      createdAt: { $gte: start, $lt: end }
    });

    if (gamesToday >= maxAttempts) {
      return res.status(403).json({ error: 'No tienes intentos disponibles. ¡Camina más para ganar intentos!' });
    }

    const gameScore = await GameScore.create({
      user: req.user._id,
      level,
      asteroidsDodged,
      score
    });

    let xpAwarded = 0;
    if (level >= MULTIPLIER_LEVEL) {
      xpAwarded = Math.floor(score / 10);
      const bonusXp = Math.floor(xpAwarded * MULTIPLIER_BONUS);
      xpAwarded += bonusXp;

      const totalXp = Math.floor(steps / 10) + xpAwarded;
      const newLevel = levelFromXp(totalXp);

      const user = await User.findById(req.user._id);
      if (user) {
        user.xp += xpAwarded;
        user.level = newLevel;
        await user.save();
      }
    }

    const newGamesToday = gamesToday + 1;
    const newMaxAttempts = Math.min(Math.floor(steps / STEPS_PER_ATTEMPT), MAX_ATTEMPTS_PER_DAY);
    const newAttempts = Math.max(0, newMaxAttempts - newGamesToday);

    res.json({
      success: true,
      gameScore: {
        id: gameScore._id,
        level,
        asteroidsDodged,
        score,
        createdAt: gameScore.createdAt
      },
      xpAwarded,
      hasMultiplier: level >= MULTIPLIER_LEVEL,
      fuel: {
        attempts: newAttempts,
        usedToday: newGamesToday,
        maxAttempts: newMaxAttempts
      }
    });
  } catch (error) {
    res.status(500).json({ error: 'Error al registrar partida' });
  }
});

// GET /api/game/leaderboard
router.get('/leaderboard', auth, async (req, res) => {
  try {
    const topScores = await GameScore.find()
      .sort({ score: -1 })
      .limit(20)
      .populate('user', 'username displayName avatar');

    const leaderboard = topScores.map((entry, index) => ({
      rank: index + 1,
      username: entry.user?.displayName || entry.user?.username || 'Anon',
      avatar: entry.user?.avatar || 'runner',
      score: entry.score,
      level: entry.level,
      asteroidsDodged: entry.asteroidsDodged,
      createdAt: entry.createdAt
    }));

    res.json({ leaderboard });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener leaderboard' });
  }
});

// GET /api/game/multiplier-status
router.get('/multiplier-status', auth, async (req, res) => {
  try {
    const { start, end } = getTodayRange();

    const bestGameToday = await GameScore.findOne({
      user: req.user._id,
      createdAt: { $gte: start, $lt: end }
    }).sort({ level: -1 });

    const hasMultiplier = bestGameToday ? bestGameToday.level >= MULTIPLIER_LEVEL : false;

    res.json({
      hasMultiplier,
      bestLevelToday: bestGameToday?.level || 0,
      multiplierValue: hasMultiplier ? 1 + MULTIPLIER_BONUS : 1
    });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener estado de multiplier' });
  }
});

module.exports = router;
