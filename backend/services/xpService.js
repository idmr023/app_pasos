const StepEntry = require('../models/StepEntry');

const REWARDS = {
  reward_10: { key: 'reward_10', level: 10, title: 'Caminante', avatar: 'walker' },
  reward_20: { key: 'reward_20', level: 20, title: 'Maratonista', avatar: 'marathon' },
  reward_30: { key: 'reward_30', level: 30, title: 'Ultramaratonista', avatar: 'ultra' },
  reward_40: { key: 'reward_40', level: 40, title: 'Leyenda', avatar: 'legend' },
  reward_50: { key: 'reward_50', level: 50, title: 'Titán', avatar: 'titan' },
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
  return (1000 * level * (level + 1)) / 2;
}

function levelFromXp(totalXp) {
  let l = 0;
  while (xpForLevel(l + 1) <= totalXp) l++;
  return l;
}

function xpFromSteps(totalSteps) {
  return Math.floor(totalSteps / 10);
}

function progressToNext(totalXp, currentLevel) {
  const currentLevelXp = xpForLevel(currentLevel);
  const nextLevelXp = xpForLevel(currentLevel + 1);
  const needed = nextLevelXp - currentLevelXp;
  const earned = totalXp - currentLevelXp;
  return { earned, needed, progress: needed > 0 ? (earned / needed) * 100 : 100 };
}

function bestRewardForLevel(level) {
  return Object.values(REWARDS)
    .filter(r => level >= r.level)
    .sort((a, b) => b.level - a.level)[0] || null;
}

function bestTitleForLevel(level) {
  const reward = bestRewardForLevel(level);
  return reward ? reward.title : '';
}

async function getTotalSteps(userId) {
  const result = await StepEntry.aggregate([
    { $match: { user: userId } },
    { $group: { _id: null, total: { $sum: '$steps' } } }
  ]);
  return result[0]?.total || 0;
}

async function getUserXpData(user) {
  const totalSteps = await getTotalSteps(user._id);
  const stepsXp = xpFromSteps(totalSteps);
  const gymXp = user.gymXp || 0;
  const totalXp = stepsXp + gymXp;
  const level = levelFromXp(totalXp);
  return { totalSteps, stepsXp, gymXp, totalXp, level };
}

async function refreshUserLevel(user) {
  const { totalXp, level } = await getUserXpData(user);
  const title = bestTitleForLevel(level);
  user.xp = totalXp;
  user.level = level;
  if (title && user.title !== title) user.title = title;
  await user.save();
  return { xp: totalXp, level, title: user.title };
}

module.exports = {
  REWARDS,
  WEIGHT_REWARDS,
  xpForLevel,
  levelFromXp,
  xpFromSteps,
  progressToNext,
  bestRewardForLevel,
  bestTitleForLevel,
  getTotalSteps,
  getUserXpData,
  refreshUserLevel,
};
