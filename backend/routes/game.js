const express = require('express');
const auth = require('../middleware/auth');
const GameScore = require('../models/GameScore');
const StepEntry = require('../models/StepEntry');
const { refreshUserLevel } = require('../services/xpService');
const { getTodayStepsDeduped, SHIELD_STEPS } = require('../services/walletService');

const router = express.Router();

const STEPS_PER_ATTEMPT = 2000;
const MAX_ATTEMPTS_PER_DAY = 5;
const MULTIPLIER_LEVEL = 5;
const MULTIPLIER_BONUS = 0.5;

// Límites de cordura para evitar puntuaciones imposibles enviadas a mano.
const MAX_SCORE = 1000000;
const MAX_LEVEL = 200;
const MAX_XP_PER_GAME = 500;

function getTodayRange() {
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const end = new Date(start);
  end.setDate(end.getDate() + 1);
  return { start, end };
}

async function getTodaySteps(userId, range) {
  const todaySteps = await StepEntry.aggregate([
    { $match: { user: userId, date: { $gte: range.start, $lt: range.end } } },
    { $group: { _id: null, total: { $sum: '$steps' } } }
  ]);
  return todaySteps[0]?.total || 0;
}

function maxAttemptsForSteps(steps) {
  return Math.min(Math.floor(steps / STEPS_PER_ATTEMPT), MAX_ATTEMPTS_PER_DAY);
}

// Entero >= 0 o null si no es un número válido.
function toCount(value) {
  const n = Number(value);
  if (value === null || value === undefined || value === '' || !Number.isFinite(n) || n < 0) return null;
  return Math.floor(n);
}

async function getBestScore(userId) {
  const best = await GameScore.findOne({ user: userId }).sort({ score: -1 }).select('score');
  return best?.score || 0;
}

// GET /api/game/fuel
router.get('/fuel', auth, async (req, res) => {
  try {
    const range = getTodayRange();
    const steps = await getTodaySteps(req.user._id, range);
    const maxAttempts = maxAttemptsForSteps(steps);

    const gamesToday = await GameScore.countDocuments({
      user: req.user._id,
      createdAt: { $gte: range.start, $lt: range.end }
    });

    const attempts = Math.max(0, maxAttempts - gamesToday);
    const stepsUntilNext = steps >= MAX_ATTEMPTS_PER_DAY * STEPS_PER_ATTEMPT
      ? 0
      : STEPS_PER_ATTEMPT - (steps % STEPS_PER_ATTEMPT);

    const bestGameToday = await GameScore.findOne({
      user: req.user._id,
      createdAt: { $gte: range.start, $lt: range.end }
    }).sort({ level: -1 });

    const hasMultiplier = bestGameToday ? bestGameToday.level >= MULTIPLIER_LEVEL : false;
    const bestScore = await getBestScore(req.user._id);
    // Boost de pasos reales (economía de pasos): escudo en carreras oficiales.
    const dedupedSteps = await getTodayStepsDeduped(req.user._id);

    res.json({
      attempts,
      usedToday: gamesToday,
      maxAttempts,
      stepsUntilNext,
      stepsToday: steps,
      hasMultiplier,
      bestLevelToday: bestGameToday?.level || 0,
      // Campos añadidos para el Sprint (aditivos)
      bestScore,
      stepsPerAttempt: STEPS_PER_ATTEMPT,
      maxAttemptsPerDay: MAX_ATTEMPTS_PER_DAY,
      multiplierLevel: MULTIPLIER_LEVEL,
      multiplierValue: 1 + MULTIPLIER_BONUS,
      shield: {
        active: dedupedSteps >= SHIELD_STEPS,
        stepsRequired: SHIELD_STEPS,
        stepsToday: dedupedSteps
      }
    });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener combustible' });
  }
});

// POST /api/game/play
// Body: { level, score, asteroidsDodged | obstaclesDodged, distance?, coins?, maxCombo?, durationMs?, game? }
router.post('/play', auth, async (req, res) => {
  try {
    const body = req.body || {};
    const level = toCount(body.level);
    const score = toCount(body.score);
    const dodged = toCount(body.obstaclesDodged ?? body.asteroidsDodged);

    if (level === null || dodged === null || score === null) {
      return res.status(400).json({ error: 'Faltan campos: level, obstaclesDodged (o asteroidsDodged), score' });
    }
    if (level < 1 || level > MAX_LEVEL || score > MAX_SCORE) {
      return res.status(400).json({ error: 'Puntuación no válida' });
    }

    const range = getTodayRange();
    const steps = await getTodaySteps(req.user._id, range);
    const maxAttempts = maxAttemptsForSteps(steps);

    const gamesToday = await GameScore.countDocuments({
      user: req.user._id,
      createdAt: { $gte: range.start, $lt: range.end }
    });

    if (gamesToday >= maxAttempts) {
      return res.status(403).json({ error: 'No tienes intentos disponibles. ¡Camina más para ganar intentos!' });
    }

    const previousBest = await getBestScore(req.user._id);

    let xpAwarded = 0;
    if (level >= MULTIPLIER_LEVEL) {
      xpAwarded = Math.floor(score / 10);
      xpAwarded += Math.floor(xpAwarded * MULTIPLIER_BONUS);
      xpAwarded = Math.min(xpAwarded, MAX_XP_PER_GAME);
    }

    const gameScore = await GameScore.create({
      user: req.user._id,
      game: typeof body.game === 'string' ? body.game.slice(0, 20) : 'sprint',
      level,
      asteroidsDodged: dodged,
      score,
      distance: toCount(body.distance) || 0,
      coins: toCount(body.coins) || 0,
      maxCombo: toCount(body.maxCombo) || 0,
      durationMs: toCount(body.durationMs) || 0,
      xpAwarded
    });

    // El XP del juego se guarda en user.gameXp para que no se pierda cuando
    // steps/gym recalculan user.xp (= stepsXp + gymXp + gameXp).
    let xpInfo = null;
    if (xpAwarded > 0) {
      req.user.gameXp = (req.user.gameXp || 0) + xpAwarded;
      xpInfo = await refreshUserLevel(req.user);
    }

    const newGamesToday = gamesToday + 1;
    const newAttempts = Math.max(0, maxAttempts - newGamesToday);

    res.json({
      success: true,
      gameScore: {
        id: gameScore._id,
        level,
        asteroidsDodged: dodged,
        obstaclesDodged: dodged,
        score,
        distance: gameScore.distance,
        coins: gameScore.coins,
        maxCombo: gameScore.maxCombo,
        createdAt: gameScore.createdAt
      },
      xpAwarded,
      hasMultiplier: level >= MULTIPLIER_LEVEL,
      isNewBest: score > previousBest,
      bestScore: Math.max(score, previousBest),
      user: xpInfo,
      fuel: {
        attempts: newAttempts,
        usedToday: newGamesToday,
        maxAttempts
      }
    });
  } catch (error) {
    res.status(500).json({ error: 'Error al registrar partida' });
  }
});

// GET /api/game/leaderboard
// Mejor puntuación de cada usuario (top 20) + posición del usuario actual.
router.get('/leaderboard', auth, async (req, res) => {
  try {
    const rows = await GameScore.aggregate([
      { $sort: { score: -1, createdAt: 1 } },
      {
        $group: {
          _id: '$user',
          score: { $first: '$score' },
          level: { $first: '$level' },
          asteroidsDodged: { $first: '$asteroidsDodged' },
          distance: { $first: '$distance' },
          createdAt: { $first: '$createdAt' }
        }
      },
      { $sort: { score: -1, createdAt: 1 } },
      { $limit: 20 },
      { $lookup: { from: 'users', localField: '_id', foreignField: '_id', as: 'user' } },
      { $unwind: { path: '$user', preserveNullAndEmptyArrays: true } }
    ]);

    const myId = req.user._id.toString();
    const leaderboard = rows.map((entry, index) => ({
      rank: index + 1,
      userId: entry._id?.toString(),
      username: entry.user?.displayName || entry.user?.username || 'Anon',
      avatar: entry.user?.avatar || 'runner',
      score: entry.score,
      level: entry.level,
      asteroidsDodged: entry.asteroidsDodged,
      distance: entry.distance || 0,
      createdAt: entry.createdAt,
      isMe: entry._id?.toString() === myId
    }));

    const myBest = await getBestScore(req.user._id);
    let myRank = null;
    if (myBest > 0) {
      const better = await GameScore.aggregate([
        { $group: { _id: '$user', best: { $max: '$score' } } },
        { $match: { best: { $gt: myBest } } },
        { $count: 'n' }
      ]);
      myRank = (better[0]?.n || 0) + 1;
    }

    res.json({ leaderboard, me: { bestScore: myBest, rank: myRank } });
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
      multiplierValue: hasMultiplier ? 1 + MULTIPLIER_BONUS : 1,
      multiplierLevel: MULTIPLIER_LEVEL
    });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener estado de multiplier' });
  }
});

module.exports = router;
