const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const auth = require('../middleware/auth');
const TrackingSession = require('../models/TrackingSession');
const LiveMessage = require('../models/LiveMessage');
const User = require('../models/User');
const TrackingLocation = require('../models/TrackingLocation');
const { finalizeSession } = require('../utils/finalizeTracking');
const { clearRoomSession, setSessionIdForRoom } = require('../utils/roomSessions');

// Generar código de sala único (6 caracteres)
function generateRoomCode() {
  return Math.random().toString(36).substring(2, 8).toUpperCase();
}

// Crear nueva sesión de tracking en vivo
router.post('/create', auth, async (req, res) => {
  try {
    const { title, isPublic } = req.body;
    let code = generateRoomCode();

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
    setSessionIdForRoom(session.code, session._id);

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
router.post('/join', async (req, res) => {
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

    const authHeader = req.headers.authorization;
    if (authHeader) {
      try {
        const token = authHeader.replace('Bearer ', '');
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        if (!session.isPublic && session.runner.toString() !== decoded.userId.toString()) {
          return res.status(403).json({ error: 'Esta sesión es privada' });
        }
      } catch (e) {
        return res.status(401).json({ error: 'Token inválido' });
      }
    } else if (!session.isPublic) {
      return res.status(403).json({ error: 'Esta sesión es privada' });
    }

    res.json({
      success: true,
      roomCode: session.code,
      isPublic: session.isPublic,
      runnerId: session.runner,
      startTime: session.startedAt,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Listar sesiones del usuario autenticado (como corredor), más recientes primero.
// IMPORTANTE: debe ir ANTES de GET /:roomCode o 'sessions' se interpreta como roomCode.
router.get('/sessions', auth, async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit, 10) || 20, 50);

    const sessions = await TrackingSession.find({ runner: req.user._id })
      .sort({ startedAt: -1 })
      .limit(limit)
      .select(
        'code title status startedAt endedAt totalDistance avgSpeed maxSpeed avgPace pointCount'
      )
      .lean();

    res.json({ success: true, sessions });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Obtener información de la sesión actual
router.get('/:roomCode', async (req, res) => {
  try {
    const { roomCode } = req.params;

    const session = await TrackingSession.findOne({ code: roomCode.toUpperCase() }).select(
      '-__v'
    );

    if (!session) {
      return res.status(404).json({ error: 'Sala no encontrada' });
    }

    const authHeader = req.headers.authorization;
    if (authHeader) {
      try {
        const token = authHeader.replace('Bearer ', '');
        jwt.verify(token, process.env.JWT_SECRET);
      } catch (e) {
        return res.status(401).json({ error: 'Token inválido' });
      }
    } else if (!session.isPublic) {
      return res.status(403).json({ error: 'Esta sesión es privada' });
    }

    const runnersInfo = await User.findById(session.runner).select('displayName avatar');

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
        avgPace: session.avgPace,
        pointCount: session.pointCount,
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

    await finalizeSession(session);
    clearRoomSession(session.code);

    // Notificar a los espectadores en tiempo real que la carrera terminó.
    const io = req.app.get('io');
    if (io) {
      io.to(session.code).emit('trackingStopped', {
        message: 'El corredor ha detenido el tracking',
        totalDistance: session.totalDistance,
        avgSpeed: session.avgSpeed,
        maxSpeed: session.maxSpeed,
        avgPace: session.avgPace,
        pointCount: session.pointCount,
      });
    }

    res.json({
      success: true,
      message: 'Sesión finalizada',
      session: {
        code: session.code,
        totalDistance: session.totalDistance,
        avgSpeed: session.avgSpeed,
        maxSpeed: session.maxSpeed,
        avgPace: session.avgPace,
        pointCount: session.pointCount,
        totalTime: (session.endedAt - session.startedAt) / 1000,
        status: session.status,
      },
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Obtener historial de ubicaciones
// ?limit=N  -> tope de puntos (máx 5000)
// ?recent=true -> devuelve los N puntos MÁS RECIENTES (orden cronológico),
//                 en vez de los N primeros. Lo usa el espectador que se une
//                 tarde a una carrera larga (si no, solo vería el tramo inicial).
router.get('/:roomCode/history', async (req, res) => {
  try {
    const { roomCode } = req.params;
    const limit = Math.min(parseInt(req.query.limit, 10) || 500, 5000);
    const recent = req.query.recent === 'true';
    const code = roomCode.toUpperCase();

    const session = await TrackingSession.findOne({ code }).select('isPublic status');
    if (!session) {
      return res.status(404).json({ error: 'Sala no encontrada' });
    }
    const authHeader = req.headers.authorization;
    if (!authHeader && !session.isPublic) {
      return res.status(403).json({ error: 'Esta sesión es privada' });
    }
    if (authHeader) {
      try {
        jwt.verify(authHeader.replace('Bearer ', ''), process.env.JWT_SECRET);
      } catch (e) {
        return res.status(401).json({ error: 'Token inválido' });
      }
    }

    let locations;
    if (recent) {
      // Los más recientes primero, y luego se devuelven en orden cronológico
      const latest = await TrackingLocation.find({ roomCode: code })
        .sort({ timestamp: -1 })
        .limit(limit)
        .lean();
      locations = latest.reverse();
    } else {
      locations = await TrackingLocation.find({ roomCode: code })
        .sort({ timestamp: 1 })
        .limit(limit)
        .lean();
    }

    res.json({
      success: true,
      locations,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Obtener historial de mensajes
router.get('/:roomCode/messages', async (req, res) => {
  try {
    const { roomCode } = req.params;
    const { limit = 100 } = req.query;

    const session = await TrackingSession.findOne({ code: roomCode.toUpperCase() }).select('isPublic');
    if (!session) {
      return res.status(404).json({ error: 'Sala no encontrada' });
    }
    const authHeader = req.headers.authorization;
    if (!authHeader && !session.isPublic) {
      return res.status(403).json({ error: 'Esta sesión es privada' });
    }
    if (authHeader) {
      try {
        jwt.verify(authHeader.replace('Bearer ', ''), process.env.JWT_SECRET);
      } catch (e) {
        return res.status(401).json({ error: 'Token inválido' });
      }
    }

    const messages = await LiveMessage.find({ roomCode: roomCode.toUpperCase() })
      .sort({ timestamp: -1 })
      .limit(parseInt(limit))
      .populate('sender', 'displayName avatar')
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