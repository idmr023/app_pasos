const express = require('express');
const auth = require('../middleware/auth');
const Challenge = require('../models/Challenge');
const StepEntry = require('../models/StepEntry');
const User = require('../models/User');

async function getWinner(challengeId) {
  const entries = await StepEntry.find({ challenge: challengeId });
  const totals = {};
  for (const e of entries) {
    totals[e.user.toString()] = (totals[e.user.toString()] || 0) + e.steps;
  }
  if (Object.keys(totals).length === 0) return null;
  const winnerId = Object.entries(totals).sort((a, b) => b[1] - a[1])[0][0];
  return winnerId;
}

const router = express.Router();

function generateCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

router.post('/', auth, async (req, res) => {
  try {
    const duration = req.body.duration || 30;
    if (![7, 14, 30].includes(duration)) {
      return res.status(400).json({ error: 'La duración debe ser 7, 14 o 30 días' });
    }

    let code;
    let exists = true;

    while (exists) {
      code = generateCode();
      exists = await Challenge.findOne({ code });
    }

    const startDate = new Date();
    const endDate = new Date(startDate);
    endDate.setDate(endDate.getDate() + duration);

    const challenge = new Challenge({
      code,
      creator: req.userId,
      duration,
      startDate,
      endDate
    });
    await challenge.save();

    res.status(201).json({
      id: challenge._id,
      code: challenge.code,
      duration: challenge.duration,
      status: challenge.status,
      startDate: challenge.startDate,
      endDate: challenge.endDate
    });
  } catch (error) {
    res.status(500).json({ error: 'Error al crear reto' });
  }
});

router.post('/join', auth, async (req, res) => {
  try {
    const { code } = req.body;
    const challenge = await Challenge.findOne({ code: code.toUpperCase() });

    if (!challenge) {
      return res.status(404).json({ error: 'Código inválido' });
    }

    if (challenge.status === 'finished') {
      return res.status(400).json({ error: 'Este reto ya finalizó' });
    }

    if (challenge.creator.toString() === req.userId.toString()) {
      return res.status(400).json({ error: 'No puedes unirte a tu propio reto' });
    }

    if (challenge.opponent) {
      return res.status(400).json({ error: 'Este reto ya tiene 2 participantes' });
    }

    challenge.opponent = req.userId;
    challenge.status = 'active';
    await challenge.save();

    const creator = await User.findById(challenge.creator);

    res.json({
      id: challenge._id,
      code: challenge.code,
      status: challenge.status,
      startDate: challenge.startDate,
      creator: { id: creator._id, username: creator.username, displayName: creator.displayName, avatar: creator.avatar },
      opponent: { id: req.user._id, username: req.user.username, displayName: req.user.displayName, avatar: req.user.avatar }
    });
  } catch (error) {
    res.status(500).json({ error: 'Error al unirse al reto' });
  }
});

router.get('/', auth, async (req, res) => {
  try {
    const { status } = req.query;
    const filter = {
      $or: [
        { creator: req.userId },
        { opponent: req.userId }
      ]
    };
    if (status) {
      filter.status = status;
    }

    const challenges = await Challenge.find(filter)
    .populate('creator', 'username displayName avatar')
    .populate('opponent', 'username displayName avatar')
    .sort({ createdAt: -1 });

    const enriched = [];
    for (const challenge of challenges) {
      const item = challenge.toObject();
      if (challenge.status === 'finished') {
        const winnerId = await getWinner(challenge._id);
        item.winner = winnerId ? winnerId.toString() : null;
      }
      enriched.push(item);
    }

    res.json({ challenges: enriched });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener retos' });
  }
});

router.get('/:id', auth, async (req, res) => {
  try {
    const challenge = await Challenge.findById(req.params.id)
      .populate('creator', 'username displayName avatar')
      .populate('opponent', 'username displayName avatar');

    if (!challenge) {
      return res.status(404).json({ error: 'Reto no encontrado' });
    }

    const isParticipant = challenge.creator._id.toString() === req.userId.toString() ||
      (challenge.opponent && challenge.opponent._id.toString() === req.userId.toString());

    if (!isParticipant) {
      return res.status(403).json({ error: 'No eres participante de este reto' });
    }

    if (challenge.status === 'active' && challenge.endDate && new Date() > challenge.endDate) {
      challenge.status = 'finished';
      await challenge.save();
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const entries = await StepEntry.find({
      challenge: challenge._id
    }).populate('user', 'username displayName avatar');

    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0);

    const monthEntries = await StepEntry.find({
      challenge: challenge._id,
      date: { $gte: startOfMonth, $lte: endOfMonth }
    }).populate('user', 'username displayName avatar');

    const result = { challenge: challenge.toObject(), entries, monthEntries };
    if (challenge.status === 'finished') {
      result.winner = await getWinner(challenge._id);
    }

    res.json(result);
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener reto' });
  }
});

router.post('/:id/leave', auth, async (req, res) => {
  try {
    const challenge = await Challenge.findById(req.params.id);
    if (!challenge) {
      return res.status(404).json({ error: 'Reto no encontrado' });
    }

    const isCreator = challenge.creator.toString() === req.userId.toString();
    const isOpponent = challenge.opponent && challenge.opponent.toString() === req.userId.toString();

    if (!isCreator && !isOpponent) {
      return res.status(403).json({ error: 'No eres participante de este reto' });
    }

    if (isCreator) {
      await StepEntry.deleteMany({ challenge: challenge._id });
      await Challenge.findByIdAndDelete(challenge._id);
      return res.json({ message: 'Reto eliminado' });
    }

    challenge.opponent = null;
    challenge.status = 'waiting';
    await challenge.save();

    res.json({ message: 'Has salido del reto' });
  } catch (error) {
    res.status(500).json({ error: 'Error al salir del reto' });
  }
});

router.delete('/:id', auth, async (req, res) => {
  try {
    const challenge = await Challenge.findById(req.params.id);
    if (!challenge) {
      return res.status(404).json({ error: 'Reto no encontrado' });
    }

    if (challenge.creator.toString() !== req.userId.toString()) {
      return res.status(403).json({ error: 'Solo el creador puede eliminar el reto' });
    }

    await StepEntry.deleteMany({ challenge: challenge._id });
    await Challenge.findByIdAndDelete(challenge._id);

    res.json({ message: 'Reto eliminado' });
  } catch (error) {
    res.status(500).json({ error: 'Error al eliminar reto' });
  }
});

module.exports = router;
