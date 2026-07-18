const express = require('express');
const auth = require('../middleware/auth');
const User = require('../models/User');
const UserReward = require('../models/UserReward');
const StepEntry = require('../models/StepEntry');

const router = express.Router();

const PersonalRecord = require('../models/PersonalRecord');

const REWARDS = {
  reward_10: { level: 10, title: 'Caminante', avatar: 'walker' },
  reward_20: { level: 20, title: 'Maratonista', avatar: 'marathon' },
  reward_30: { level: 30, title: 'Ultramaratonista', avatar: 'ultra' },
  reward_40: { level: 40, title: 'Leyenda', avatar: 'legend' },
  reward_50: { level: 50, title: 'Titán', avatar: 'titan' },
};

const WEIGHT_REWARDS = {
  pr_25: { key: 'pr_25', minKg: 25, title: 'Principiante', icon: 'fitness_center', description: 'Levanta 25kg en un ejercicio' },
  pr_50: { key: 'pr_50', minKg: 50, title: 'Intermedio', icon: 'fitness_center', description: 'Levanta 50kg en un ejercicio' },
  pr_75: { key: 'pr_75', minKg: 75, title: 'Avanzado', icon: 'fitness_center', description: 'Levanta 75kg en un ejercicio' },
  pr_100: { key: 'pr_100', minKg: 100, title: 'Experto', icon: 'fitness_center', description: 'Levanta 100kg en un ejercicio' },
  pr_150: { key: 'pr_150', minKg: 150, title: 'Élite', icon: 'fitness_center', description: 'Levanta 150kg en un ejercicio' },
  pr_200: { key: 'pr_200', minKg: 200, title: 'Master', icon: 'fitness_center', description: 'Levanta 200kg en un ejercicio' },
};

function xpForLevel(level) {
  return 1000 * level * (level + 1) / 2;
}

function levelFromXp(totalXp) {
  let l = 0;
  while (xpForLevel(l + 1) <= totalXp) l++;
  return l;
}

function progressToNext(totalXp, currentLevel) {
  const currentLevelXp = xpForLevel(currentLevel);
  const nextLevelXp = xpForLevel(currentLevel + 1);
  const needed = nextLevelXp - currentLevelXp;
  const earned = totalXp - currentLevelXp;
  return { earned, needed, progress: needed > 0 ? (earned / needed) * 100 : 100 };
}

async function recalculateXp(userId) {
  const entries = await StepEntry.find({ user: userId });
  const totalSteps = entries.reduce((sum, e) => sum + e.steps, 0);
  const totalXp = Math.floor(totalSteps / 5);
  const newLevel = levelFromXp(totalXp);

  const user = await User.findById(userId);
  if (!user) return;

  user.xp = totalXp;
  user.level = newLevel;

  const bestReward = Object.values(REWARDS)
    .filter(r => newLevel >= r.level)
    .sort((a, b) => b.level - a.level)[0];

  if (bestReward && user.title !== bestReward.title) {
    user.title = bestReward.title;
  }

  await user.save();
  return { xp: totalXp, level: newLevel, title: user.title };
}

router.get('/', auth, async (req, res) => {
  try {
    const totalSteps = await StepEntry.aggregate([
      { $match: { user: req.user._id } },
      { $group: { _id: null, total: { $sum: '$steps' } } }
    ]);

    const totalXp = Math.floor((totalSteps[0]?.total || 0) / 10);
    const level = levelFromXp(totalXp);
    const progress = progressToNext(totalXp, level);
    const rewards = Object.values(REWARDS);
    const claimed = await UserReward.find({ user: req.user._id });

    const claimedRewards = claimed.map(c => c.reward);

    const availableRewards = rewards.map(r => ({
      ...r,
      unlocked: level >= r.level,
      claimed: claimedRewards.includes(`reward_${r.level}`),
    }));

    res.json({
      xp: totalXp,
      level,
      title: req.user.title || '',
      progress: {
        earned: progress.earned,
        needed: progress.needed,
        percent: Math.round(progress.progress),
      },
      rewards: availableRewards,
    });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener XP' });
  }
});

router.get('/rewards', auth, async (req, res) => {
  try {
    const totalSteps = await StepEntry.aggregate([
      { $match: { user: req.user._id } },
      { $group: { _id: null, total: { $sum: '$steps' } } }
    ]);

    const totalXp = Math.floor((totalSteps[0]?.total || 0) / 10);
    const level = levelFromXp(totalXp);
    const claimed = await UserReward.find({ user: req.user._id });
    const claimedRewards = claimed.map(c => c.reward);

    const rewards = Object.values(REWARDS).map(r => ({
      ...r,
      unlocked: level >= r.level,
      claimed: claimedRewards.includes(`reward_${r.level}`),
    }));

    res.json({ rewards, level, xp: totalXp });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener recompensas' });
  }
});

router.post('/claim/:rewardKey', auth, async (req, res) => {
  try {
    const { rewardKey } = req.params;

    if (!REWARDS[rewardKey]) {
      return res.status(400).json({ error: 'Recompensa no válida' });
    }

    const totalSteps = await StepEntry.aggregate([
      { $match: { user: req.user._id } },
      { $group: { _id: null, total: { $sum: '$steps' } } }
    ]);

    const totalXp = Math.floor((totalSteps[0]?.total || 0) / 10);
    const level = levelFromXp(totalXp);
    const reward = REWARDS[rewardKey];

    if (level < reward.level) {
      return res.status(403).json({ error: 'No has alcanzado el nivel requerido' });
    }

    const existing = await UserReward.findOne({ user: req.user._id, reward: rewardKey });
    if (existing) {
      return res.status(400).json({ error: 'Recompensa ya reclamada' });
    }

    await UserReward.create({ user: req.user._id, reward: rewardKey });

    if (reward.title) req.user.title = reward.title;
    if (reward.avatar) req.user.avatar = reward.avatar;
    await req.user.save();

    res.json({
      success: true,
      reward,
      user: {
        id: req.user._id,
        username: req.user.username,
        displayName: req.user.displayName,
        role: req.user.role,
        avatar: req.user.avatar,
        xp: totalXp,
        level,
        title: req.user.title,
      },
    });
  } catch (error) {
    res.status(500).json({ error: 'Error al reclamar recompensa' });
  }
});

router.post('/add', auth, async (req, res) => {
  try {
    const { amount, reason } = req.body;
    const stepXp = Math.floor((await StepEntry.aggregate([
      { $match: { user: req.user._id } },
      { $group: { _id: null, total: { $sum: '$steps' } } }
    ]))[0]?.total || 0) / 5;

    req.user.xp += amount || 0;
    req.user.level = levelFromXp(req.user.xp);

    const bestReward = Object.values(REWARDS)
      .filter(r => req.user.level >= r.level)
      .sort((a, b) => b.level - a.level)[0];
    if (bestReward && req.user.title !== bestReward.title) {
      req.user.title = bestReward.title;
    }

    await req.user.save();

    res.json({ xp: req.user.xp, level: req.user.level, title: req.user.title });
  } catch (error) {
    res.status(500).json({ error: 'Error al añadir XP' });
  }
});

// GET /weight-rewards — weight achievement progress
router.get('/weight-rewards', auth, async (req, res) => {
  try {
    const topPR = await PersonalRecord.findOne({ user: req.user._id })
      .sort({ maxWeightKg: -1 })
      .select('maxWeightKg');
    const maxKg = topPR?.maxWeightKg || 0;

    const rewards = Object.values(WEIGHT_REWARDS).map(r => ({
      ...r,
      unlocked: maxKg >= r.minKg,
    }));

    res.json({ rewards, maxKg });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener logros de peso' });
  }
});

module.exports = router;