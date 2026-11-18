const express = require('express');
const auth = require('../middleware/auth');
const leagues = require('../services/leagueService');

const router = express.Router();

// GET /api/leagues/current — mi grupo de la semana (se une perezosamente y cierra la semana anterior)
router.get('/current', auth, async (req, res) => {
  try {
    const data = await leagues.getCurrent(req.userId, leagues.nowFromRequest(req));
    res.json(data);
  } catch (error) {
    console.error('leagues/current', error.message);
    res.status(500).json({ error: 'Error al obtener la liga' });
  }
});

// GET /api/leagues/history — últimas 12 semanas del usuario
router.get('/history', auth, async (req, res) => {
  try {
    const history = await leagues.getHistory(req.userId, leagues.nowFromRequest(req));
    res.json({ history });
  } catch (error) {
    console.error('leagues/history', error.message);
    res.status(500).json({ error: 'Error al obtener el historial de ligas' });
  }
});

// POST /api/leagues/ack-result { week? } — marca como visto el resultado ("¡Subiste a Oro!")
router.post('/ack-result', auth, async (req, res) => {
  try {
    const week = req.body && typeof req.body.week === 'string' ? req.body.week.slice(0, 10) : null;
    const acknowledged = await leagues.ackResult(req.userId, week, leagues.nowFromRequest(req));
    res.json({ acknowledged });
  } catch (error) {
    console.error('leagues/ack-result', error.message);
    res.status(500).json({ error: 'Error al confirmar el resultado' });
  }
});

module.exports = router;
