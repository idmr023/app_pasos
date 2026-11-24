const express = require('express');
const auth = require('../middleware/auth');
const Challenge = require('../models/Challenge');
const StepEntry = require('../models/StepEntry');
const User = require('../models/User');
const wallet = require('../services/walletService');

const router = express.Router();

// Preserva el saldo ganado antes de borrar StepEntry (ver docs/WALLET.md).
async function syncParticipants(challenge) {
  for (const u of [challenge.creator, challenge.opponent].filter(Boolean)) {
    await wallet.syncEarned(u._id || u).catch(() => {});
  }
}

async function settleIfNeeded(c) {
  if (!c.wager || c.wager <= 0 || c.wagerSettledAt || c.status !== 'finished') return;
  try {
    await wallet.settleChallenge(c);
    const fresh = await Challenge.findById(c._id, 'wagerState wagerWinner wagerSettledAt').lean();
    if (fresh) Object.assign(c, fresh);
  } catch (e) {
    console.error('Liquidar apuesta:', e.message);
  }
}

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
    let wager;
    try {
      wager = wallet.validateWager(req.body.wager);
    } catch (e) {
      return res.status(e.status || 400).json({ error: e.message });
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
      endDate,
      wager,
      wagerState: wager > 0 ? 'open' : 'none'
    });
    await challenge.save();

    let balance;
    if (wager > 0) {
      try {
        balance = (await wallet.stake(req.userId, challenge._id, wager, `stake:${challenge._id}:creator`)).balance;
      } catch (e) {
        await Challenge.findByIdAndDelete(challenge._id);
        if (e instanceof wallet.WalletError) {
          return res.status(e.status).json({ error: e.message, ...e.extra });
        }
        throw e;
      }
    }

    res.status(201).json({
      id: challenge._id,
      code: challenge.code,
      duration: challenge.duration,
      status: challenge.status,
      startDate: challenge.startDate,
      endDate: challenge.endDate,
      wager: challenge.wager,
      wagerState: challenge.wagerState,
      ...(balance !== undefined ? { balance } : {})
    });
  } catch (error) {
    res.status(500).json({ error: 'Error al crear reto' });
  }
});

router.post('/join', auth, async (req, res) => {
  try {
    const { code } = req.body;
    if (!code || typeof code !== 'string') {
      return res.status(400).json({ error: 'Código requerido' });
    }
    const challenge = await Challenge.findOneAndUpdate(
      { code: code.toUpperCase(), opponent: null, status: { $ne: 'finished' } },
      { $set: { opponent: req.userId, status: 'active' }, $inc: { joinCount: 1 } },
      { new: true }
    );

    if (!challenge) {
      return res.status(404).json({ error: 'Código inválido o reto ya tiene oponente' });
    }

    const revertJoin = () => Challenge.findOneAndUpdate(
      { _id: challenge._id, opponent: req.userId },
      { $set: { opponent: null, status: 'waiting' } }
    );

    if (challenge.creator.toString() === req.userId.toString()) {
      // Revertir el update atómico
      await revertJoin();
      return res.status(400).json({ error: 'No puedes unirte a tu propio reto' });
    }

    let balance;
    if (challenge.wager > 0) {
      if (challenge.wagerState !== 'open') {
        await revertJoin();
        return res.status(400).json({ error: 'Este reto ya no admite apuestas' });
      }
      try {
        const stakeKey = `stake:${challenge._id}:${req.userId}:${challenge.joinCount}`;
        balance = (await wallet.stake(req.userId, challenge._id, challenge.wager, stakeKey)).balance;
      } catch (e) {
        await revertJoin();
        if (e instanceof wallet.WalletError) {
          return res.status(e.status).json({
            error: `Este reto tiene una apuesta de ${wallet.formatSteps(challenge.wager)} pasos. ${e.message}`,
            wager: challenge.wager,
            ...e.extra
          });
        }
        throw e;
      }
    }

    const creator = await User.findById(challenge.creator);

    res.json({
      id: challenge._id,
      code: challenge.code,
      status: challenge.status,
      startDate: challenge.startDate,
      wager: challenge.wager,
      wagerState: challenge.wagerState,
      ...(balance !== undefined ? { balance } : {}),
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

    // Auto-finish expired challenges
    const now = new Date();
    for (const c of challenges) {
      if (c.status === 'active' && c.endDate && now > c.endDate) {
        c.status = 'finished';
        await c.save();
      }
      await settleIfNeeded(c);
    }

    const finishedIds = challenges
      .filter(c => c.status === 'finished')
      .map(c => c._id);

    const winnerMap = {};
    if (finishedIds.length > 0) {
      const winnerData = await StepEntry.aggregate([
        { $match: { challenge: { $in: finishedIds } } },
        { $group: { _id: { challenge: '$challenge', user: '$user' }, total: { $sum: '$steps' } } },
        { $sort: { total: -1 } },
        { $group: { _id: '$_id.challenge', winner: { $first: '$_id.user' } } }
      ]);
      for (const w of winnerData) {
        winnerMap[w._id.toString()] = w.winner.toString();
      }
    }

    const enriched = challenges.map(c => {
      const item = c.toObject();
      if (c.status === 'finished') {
        item.winner = winnerMap[c._id.toString()] || null;
      }
      return item;
    });

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
    await settleIfNeeded(challenge);

    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0);

    const allEntries = await StepEntry.find({
      challenge: challenge._id
    }).populate('user', 'username displayName avatar');

    const monthEntries = allEntries.filter(e => {
      const d = new Date(e.date);
      return d >= startOfMonth && d <= endOfMonth;
    });

    let winner = null;
    if (challenge.status === 'finished') {
      const totals = {};
      for (const e of allEntries) {
        totals[e.user._id.toString()] = (totals[e.user._id.toString()] || 0) + e.steps;
      }
      if (Object.keys(totals).length > 0) {
        winner = Object.entries(totals).sort((a, b) => b[1] - a[1])[0][0];
      }
    }

    res.json({ challenge: challenge.toObject(), entries: allEntries, monthEntries, winner });
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

    await syncParticipants(challenge);

    if (isCreator) {
      // Apuesta: reto sin terminar → reembolso a ambos; terminado → se paga al ganador.
      await wallet.refundChallenge(challenge);
      await StepEntry.deleteMany({ challenge: challenge._id });
      await Challenge.findByIdAndDelete(challenge._id);
      return res.json({ message: 'Reto eliminado' });
    }

    if (challenge.wager > 0) {
      if (wallet.isChallengeOver(challenge)) {
        // Terminado: primero se liquida (el que sale no pierde un premio ganado).
        await wallet.settleChallenge(challenge);
      } else if (challenge.wagerState === 'open') {
        // Rival abandona un reto en curso: recupera su apuesta, la del creador sigue en juego.
        await wallet.refundUserStakes(req.userId, challenge._id);
      }
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

    await syncParticipants(challenge);
    await wallet.refundChallenge(challenge);
    await StepEntry.deleteMany({ challenge: challenge._id });
    await Challenge.findByIdAndDelete(challenge._id);

    res.json({ message: 'Reto eliminado' });
  } catch (error) {
    res.status(500).json({ error: 'Error al eliminar reto' });
  }
});

module.exports = router;
