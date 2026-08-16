const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const TrackingSession = require('../models/TrackingSession');
const LiveMessage = require('../models/LiveMessage');

// Generar código de sala único (6 caracteres)
function generateRoomCode() {
  return Math.random().toString(36).substring(2, 8).toUpperCase();
}

// Crear nueva sesión de tracking en vivo
router.post('/create', auth, async (req, res) => {
  try {
    const { title, isPublic } = req.body;
    const code = generateRoomCode();

    // Validar que el código no exista
    let existing = await TrackingSession.findOne({ code }).lean();
    while (existing) {
      code = generateRoomCode();
      existing = await TrackingSession.findOne({ code }).lean();
    }

    const session = await TrackingSession.create({
      code,
      runner: req.user._id,
      title: title || 'Carrera en Vivo',
      isPublic: isPublic !== false,
      status: 'active',
      startedAt: new Date(),
    });

    res.status(201).json({
      success: true,
      roomCode: session.code,
      sessionId: session._id,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Unirse a una sala como espectador
router.post('/join', auth, async (req, res) => {
  try {
    const { roomCode } = req.body;

    if (!roomCode || roomCode.length !== 6) {
      return res.status(400).json({ error: 'Código de sala inválido' });
    }

    const session = await TrackingSession.findOne({ code: roomCode.toUpperCase() });

    if (!session) {
      return res.status(404).json({ error: 'Sala no encontrada' });
    }

    if (session.status !== 'active') {
      return res.status(400).json({ error: 'La sesión no está activa' });
    }

    if (!session.isPublic && session.runner.toString() !== req.user._id.toString()) {
      return res.status(403).json({ error: 'Esta sesión es privada' });
    }

    res.json({
      success: true,
      roomCode: session.code,
      isPublic: session.isPublic,
      runnerId: session.runner._id,
      startTime: session.startedAt,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Obtener información de la sesión actual
router.get('/:roomCode', auth, async (req, res) => {
  try {
    const { roomCode } = req.params;

    const session = await TrackingSession.findOne({ code: roomCode.toUpperCase() }).select(
      '-runner -__v'
    );

    if (!session) {
      return res.status(404).json({ error: 'Sala no encontrada' });
    }

    const runnersInfo = await User.findById(session.runner).select('name avatar');

    res.json({
      success: true,
      session: {
        code: session.code,
        title: session.title,
        status: session.status,
        startedAt: session.startedAt,
        runner: runnersInfo,
        isPublic: session.isPublic,
        totalDistance: session.totalDistance,
        avgSpeed: session.avgSpeed,
        maxSpeed: session.maxSpeed,
      },
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Terminar sesión
router.post('/:roomCode/close', auth, async (req, res) => {
  try {
    const { roomCode } = req.params;

    const session = await TrackingSession.findOne({ code: roomCode.toUpperCase() });

    if (!session) {
      return res.status(404).json({ error: 'Sala no encontrada' });
    }

    if (session.runner.toString() !== req.user._id.toString()) {
      return res.status(403).json({ error: 'No tienes permiso para cerrar esta sesión' });
    }

    session.status = 'completed';
    session.endedAt = new Date();
    await session.save();

    res.json({
      success: true,
      message: 'Sesión finalizada',
      session: {
        code: session.code,
        totalDistance: session.totalDistance,
        totalTime: (session.endedAt - session.startedAt) / 1000,
      },
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Obtener historial de ubicaciones
router.get('/:roomCode/history', auth, async (req, res) => {
  try {
    const { roomCode } = req.params;
    const { limit = 500 } = req.query;

    const locations = await TrackingLocation.find({ roomCode: roomCode.toUpperCase() })
      .sort({ timestamp: 1 })
      .limit(parseInt(limit))
      .lean();

    res.json({
      success: true,
      locations,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Obtener historial de mensajes
router.get('/:roomCode/messages', auth, async (req, res) => {
  try {
    const { roomCode } = req.params;
    const { limit = 100 } = req.query;

    const messages = await LiveMessage.find({ roomCode: roomCode.toUpperCase() })
      .sort({ timestamp: -1 })
      .limit(parseInt(limit))
      .populate('sender', 'name avatar')
      .lean();

    res.json({
      success: true,
      messages: messages.reverse(),
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;