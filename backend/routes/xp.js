const express = require('express');
const auth = require('../middleware/auth');
const UserReward = require('../models/UserReward');
const PersonalRecord = require('../models/PersonalRecord');
const { REWARDS, WEIGHT_REWARDS, xpFromSteps, levelFromXp, progressToNext, getUserXpData } = require('../services/xpService');

const router = express.Router();

router.get('/', auth, async (req, res) => {
  try {
    const { totalSteps, stepsXp, gymXp, totalXp, level } = await getUserXpData(req.user);
    const progress = progressToNext(totalXp, level);
    const claimed = await UserReward.find({ user: req.user._id });
    const claimedRewards = claimed.map(c => c.reward);

    const availableRewards = Object.values(REWARDS).map(r => ({
      ...r,
      unlocked: level >= r.level,
      claimed: claimedRewards.includes(r.key),
    }));

    res.json({
      xp: totalXp,
      stepsXp,
      gymXp,
      totalSteps,
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
    const { totalSteps, totalXp, level } = await getUserXpData(req.user);
    const claimed = await UserReward.find({ user: req.user._id });
    const claimedRewards = claimed.map(c => c.reward);

    const rewards = Object.values(REWARDS).map(r => ({
      ...r,
      unlocked: level >= r.level,
      claimed: claimedRewards.includes(r.key),
    }));

    res.json({ rewards, level, xp: totalXp, totalSteps });
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

    const { totalXp, level } = await getUserXpData(req.user);
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
