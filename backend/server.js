const express = require('express');
const http = require('http');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const dns = require('dns');
require('dotenv').config();

const { Server } = require('socket.io');

const authRoutes = require('./routes/auth');
const challengeRoutes = require('./routes/challenges');
const stepRoutes = require('./routes/steps');
const xpRoutes = require('./routes/xp');
const gymRoutes = require('./routes/gym');
const chatRoutes = require('./routes/chat');
const routeRoutes = require('./routes/routes');
const trackingRoutes = require('./routes/tracking');
const gameRoutes = require('./routes/game');
const walletRoutes = require('./routes/wallet');
const leagueRoutes = require('./routes/leagues');
const trainingRoutes = require('./routes/training');

// Modelos para el manejo de sockets
const jwt = require('jsonwebtoken');
const User = require('./models/User');
const TrackingSession = require('./models/TrackingSession');
const TrackingLocation = require('./models/TrackingLocation');
const LiveMessage = require('./models/LiveMessage');
const { finalizeSession } = require('./utils/finalizeTracking');
const { normalizeLocationPoint, samplePoints } = require('./utils/plannedRoute');
const {
  getSessionIdForRoom,
  clearRoomSession,
  setSessionIdForRoom,
} = require('./utils/roomSessions');

dns.setServers(['8.8.8.8', '1.1.1.1']);

const app = express();
app.set('trust proxy', 1);

const allowedOrigins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map(o => o.trim())
  .filter(Boolean);

app.use(helmet({
  crossOriginResourcePolicy: { policy: 'cross-origin' },
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'", 'https://unpkg.com', 'https://cdn.socket.io'],
      styleSrc: ["'self'", "'unsafe-inline'", 'https://unpkg.com'],
      imgSrc: [
        "'self'",
        'data:',
        'https://*.tile.openstreetmap.org',
        'https://basemaps.cartocdn.com',
        'https://server.arcgisonline.com',
        'https://unpkg.com',
      ],
      connectSrc: ["'self'", 'https:', 'wss:', 'ws:'],
      fontSrc: ["'self'", 'https://unpkg.com', 'data:'],
    },
  },
}));
app.use(cors(allowedOrigins.length > 0
  ? { origin: allowedOrigins }
  : {}
));
app.use(express.json({ limit: '2mb' }));

const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Demasiadas peticiones, intenta de nuevo en unos minutos' },
});

app.use('/api', apiLimiter);

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Demasiados intentos, intenta de nuevo en 15 minutos' },
});

app.use('/api/auth/login', authLimiter);
app.use('/api/auth/register', authLimiter);
app.use('/api/auth/verify-security', authLimiter);

const chatLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Estás enviando mensajes muy rápido' },
});

app.use('/api/chat', chatLimiter);

mongoose.connect(process.env.MONGODB_URI, {
  serverSelectionTimeoutMS: 5000,
  socketTimeoutMS: 45000,
  maxPoolSize: 50,
})
  .then(() => console.log('Conectado a MongoDB Atlas'))
  .catch(err => console.error('Error conectando a MongoDB:', err));

app.use('/api/auth', authRoutes);
app.use('/api/challenges', challengeRoutes);
app.use('/api/steps', stepRoutes);
app.use('/api/xp', xpRoutes);
app.use('/api/gym', gymRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/routes', routeRoutes);
app.use('/api/tracking', trackingRoutes);
app.use('/api/game', gameRoutes);
app.use('/api/wallet', walletRoutes);
app.use('/api/leagues', leagueRoutes);
app.use('/api/training', trainingRoutes);

// Visor público de seguimiento en vivo (enlace compartible)
const path = require('path');
app.get('/track/:code', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'track.html'));
});

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', message: 'App Pasos API funcionando' });
});

app.use((req, res) => {
  res.status(404).json({ error: 'Ruta no encontrada' });
});

app.use((err, req, res, next) => {
  console.error('Error global:', err.message);
  if (err.type === 'entity.too.large') {
    return res.status(413).json({ error: 'El payload es demasiado grande' });
  }
  res.status(err.status || 500).json({ error: 'Error interno del servidor' });
});

// --- Configuración de Socket.IO ---
const powerUps = require('./utils/powerUps');
const runnerTimers = {};
// Carreras largas con mala señal (arena, cerros): 20 min de gracia antes de
// cerrar la sala; si el corredor vuelve después, se reabre (autoClosed).
const runnerDisconnectGraceMs = Number(process.env.RUNNER_GRACE_MS) || 20 * 60 * 1000;
const MAX_BATCH_POINTS = 500;

const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: allowedOrigins.length > 0 ? allowedOrigins : '*',
    methods: ['GET', 'POST'],
  },
  pingTimeout: 60000,
  pingInterval: 25000,
});

// Exponer io a las rutas Express (p.ej. /tracking/:roomCode/close) para
// poder notificar a los espectadores en tiempo real al cerrar una sesión.
app.set('io', io);

// Middleware de autenticación para sockets
io.use(async (socket, next) => {
  const token = socket.handshake.auth?.token;
  const roomCode = socket.handshake.query?.roomCode;
  const isRunner = socket.handshake.query?.isRunner === 'true';

  // Espectador invitado (sin cuenta): permitido solo como espectador.
  if (!token && !isRunner) {
    const guestName = (socket.handshake.query?.guestName || 'Invitado').toString().trim().slice(0, 30) || 'Invitado';
    socket.user = { displayName: guestName, avatar: null, isGuest: true };
    socket.userId = null;
    socket.roomCode = roomCode?.toUpperCase();
    socket.isRunner = false;
    return next();
  }

  if (!token) {
    return next(new Error('Authentication error: Missing token'));
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const user = await User.findById(decoded.userId).select('-password');
    if (!user) {
      return next(new Error('Authentication error: User not found'));
    }

    socket.user = user;
    socket.userId = user._id;
    socket.roomCode = roomCode?.toUpperCase();
    socket.isRunner = isRunner;

    if (socket.isRunner) {
      const timerKey = `${socket.roomCode}:${socket.userId}`;
      if (runnerTimers[timerKey]) {
        clearTimeout(runnerTimers[timerKey]);
        delete runnerTimers[timerKey];
      }
    }

    next();
  } catch (err) {
    next(new Error('Authentication error: Invalid token'));
  }
});

io.on('connection', (socket) => {
  const userName = socket.user.displayName || socket.user.username;
  console.log(`User ${userName} connected (ID: ${socket.userId}) to room ${socket.roomCode}`);

  // Validar sala
  if (!socket.roomCode) {
    socket.emit('error', { message: 'Missing room code' });
    socket.disconnect(true);
    return;
  }

  // Unir a la sala
  socket.join(socket.roomCode);

  // Corredor que vuelve tras una desconexión larga: si el timer ya cerró la
  // sala, se reabre para que la carrera continúe para los espectadores.
  if (socket.isRunner && socket.userId) {
    TrackingSession.findOne({ code: socket.roomCode, runner: socket.userId })
      .then(async (session) => {
        if (session && session.status === 'completed' && session.autoClosed) {
          session.status = 'active';
          session.autoClosed = false;
          session.endedAt = undefined;
          await session.save();
          setSessionIdForRoom(session.code, session._id);
          io.to(socket.roomCode).emit('trackingResumed', {
            message: 'El corredor recuperó la conexión',
          });
        }
      })
      .catch((err) => console.error('Error reabriendo sesión:', err));
  }

  // Confirmar conexión
  socket.emit('connected', {
    roomCode: socket.roomCode,
    isRunner: socket.handshake.query?.isRunner === 'true',
    message: 'Conectado a la sala en vivo',
  });

  // Notificar a la sala
  socket.to(socket.roomCode).emit('userJoined', {
    userId: socket.userId,
    name: userName,
    message: `${userName} se unió a la sala`,
  });

  // Evento: Actualización de ubicación (corredor)
  socket.on('locationUpdate', async (data) => {
    if (socket.handshake.query?.isRunner !== 'true') {
      return; // Solo el corredor puede enviar ubicaciones
    }

    const point = normalizeLocationPoint(data);
    if (!point) return;

    try {
      const sessionId = await getSessionIdForRoom(socket.roomCode, TrackingSession);

      // Guardar ubicación en MongoDB
      await TrackingLocation.create({
        ...point,
        roomCode: socket.roomCode,
        session: sessionId,
        runner: socket.userId,
        timestamp: new Date(point.timestamp),
      });

      // Retransmitir a todos los espectadores
      socket.to(socket.roomCode).emit('locationUpdate', point);
    } catch (err) {
      console.error('Error saving location:', err);
      socket.emit('error', { message: 'Error guardando ubicación' });
    }
  });

  // Evento: lote de ubicaciones con ack (corredor). La app encola todos los
  // puntos y los envía así; sin señal se acumulan y llegan al reconectar.
  // Idempotente: un lote reenviado (ack perdido) no duplica puntos.
  socket.on('locationBatch', async (data, ack) => {
    const reply = typeof ack === 'function' ? ack : () => {};
    if (socket.handshake.query?.isRunner !== 'true') {
      return reply({ ok: false, error: 'Solo el corredor' });
    }
    const raw = data && Array.isArray(data.points) ? data.points.slice(0, MAX_BATCH_POINTS) : [];
    const points = raw.map(normalizeLocationPoint).filter(Boolean);
    if (points.length === 0) return reply({ ok: true, count: 0 });

    try {
      const sessionId = await getSessionIdForRoom(socket.roomCode, TrackingSession);
      const stamps = points.map((p) => new Date(p.timestamp));
      const existing = await TrackingLocation.find({
        roomCode: socket.roomCode,
        timestamp: { $in: stamps },
      }).select('timestamp -_id').lean();
      const seen = new Set(existing.map((e) => new Date(e.timestamp).getTime()));
      const fresh = points.filter((p) => !seen.has(p.timestamp));

      if (fresh.length > 0) {
        await TrackingLocation.insertMany(
          fresh.map((p) => ({
            ...p,
            roomCode: socket.roomCode,
            session: sessionId,
            runner: socket.userId,
            timestamp: new Date(p.timestamp),
          })),
          { ordered: false },
        );
        if (fresh.length === 1) {
          socket.to(socket.roomCode).emit('locationUpdate', fresh[0]);
        } else {
          socket.to(socket.roomCode).emit('locationBatch', { points: samplePoints(fresh, 300) });
        }
      }
      reply({ ok: true, count: fresh.length });
    } catch (err) {
      console.error('Error saving location batch:', err);
      reply({ ok: false, error: 'Error guardando ubicaciones' });
    }
  });

  // Evento: Mensaje de chat
  socket.on('chatMessage', async (data) => {
    const { message } = data;

    if (!message || message.trim().length === 0) {
      return socket.emit('error', { message: 'Mensaje vacío' });
    }

    if (message.trim().length > 1000) {
      return socket.emit('error', { message: 'Mensaje demasiado largo' });
    }

    try {
      const session = await TrackingSession.findOne({
        code: socket.roomCode,
      }).select('status');
      if (!session || session.status !== 'active') {
        return socket.emit('error', {
          message: 'El chat está cerrado porque la actividad ya finalizó',
        });
      }

      // Determinar tipo de remitente
      const isRunnerQuery = socket.handshake.query?.isRunner === 'true';
      const requestedName =
        typeof data?.senderName === 'string'
          ? data.senderName.trim().slice(0, 30)
          : '';
      const senderDisplayName =
        socket.user?.isGuest && requestedName
          ? requestedName
          : userName;

      // Guardar mensaje en MongoDB
      const chatMsg = await LiveMessage.create({
        roomCode: socket.roomCode,
        sender: socket.userId,
        senderName: senderDisplayName,
        senderType: isRunnerQuery ? 'runner' : 'spectator',
        message: message.trim(),
        timestamp: new Date(),
      });

      // Retransmitir a todos en la sala
      io.to(socket.roomCode).emit('chatMessage', {
        message: message.trim(),
        senderId: socket.userId,
        senderName: senderDisplayName,
        senderAvatar: socket.user.avatar,
        timestamp: chatMsg.timestamp.toISOString(),
        senderType: isRunnerQuery ? 'runner' : 'spectator',
      });
    } catch (err) {
      console.error('Error saving chat message:', err);
      socket.emit('error', { message: 'Error enviando mensaje' });
    }
  });

  // Evento: Power-up / ánimo en vivo (espectadores, invitados incluidos).
  // Payload: { type, text?, senderName? }. Ver docs/LIVE_CHEERS.md.
  socket.on('powerUp', async (data) => {
    if (socket.handshake.query?.isRunner === 'true') {
      return socket.emit('error', { message: 'El corredor no puede enviarse ánimos' });
    }
    const type = data?.type;
    if (!powerUps.isValidPowerUpType(type)) {
      return socket.emit('error', { message: 'Tipo de ánimo inválido', code: 'POWERUP_INVALID' });
    }
    const customText = type === 'voz' ? powerUps.sanitizeCustomText(data?.text) : '';
    if (type === 'voz' && !customText) {
      return socket.emit('error', { message: 'Escribe tu ánimo antes de enviarlo', code: 'POWERUP_INVALID' });
    }

    // Rate limit server-side por socket (antes de tocar la DB).
    const retryInMs = powerUps.consumePowerUpSlot(socket);
    if (retryInMs > 0) {
      return socket.emit('error', {
        message: `Espera ${Math.ceil(retryInMs / 1000)} s para mandar otro ánimo`,
        code: 'POWERUP_COOLDOWN',
        retryInMs,
      });
    }

    try {
      const session = await TrackingSession.findOne({ code: socket.roomCode }).select('_id status');
      if (!session || session.status !== 'active') {
        return socket.emit('error', { message: 'La actividad ya finalizó' });
      }

      const requestedName =
        typeof data?.senderName === 'string' ? data.senderName.trim().slice(0, 30) : '';
      const senderName = socket.user?.isGuest && requestedName ? requestedName : userName;

      const saved = await LiveMessage.create({
        roomCode: socket.roomCode,
        session: session._id,
        sender: socket.userId,
        senderName,
        senderType: 'spectator',
        message: powerUps.buildDisplayMessage(type, senderName, customText),
        kind: 'powerUp',
        powerUpType: type,
        timestamp: new Date(),
      });
      const stats = await powerUps.getLiveCheerStats(socket.roomCode);

      io.to(socket.roomCode).emit('powerUp', {
        type,
        emoji: powerUps.POWER_UP_TYPES[type].emoji,
        message: saved.message,
        speech: powerUps.buildSpeech(type, senderName, customText),
        text: customText || null,
        senderId: socket.userId,
        senderName,
        senderType: 'spectator',
        timestamp: saved.timestamp.toISOString(),
        stats,
      });
    } catch (err) {
      console.error('Error saving power-up:', err);
      socket.emit('error', { message: 'Error enviando ánimo' });
    }
  });

  // Evento: Detener tracking (corredor)
  socket.on('stopTracking', async () => {
    const isRunnerQuery = socket.handshake.query?.isRunner === 'true';
    
    if (!isRunnerQuery) {
      return socket.emit('error', { message: 'Only runner can stop tracking' });
    }

    try {
      const session = await TrackingSession.findOne({ code: socket.roomCode });
      await finalizeSession(session);
      clearRoomSession(socket.roomCode);

      // Notificar a todos con las estadísticas finales
      io.to(socket.roomCode).emit('trackingStopped', {
        message: 'El corredor ha detenido el tracking',
        totalDistance: session ? session.totalDistance : 0,
        avgSpeed: session ? session.avgSpeed : 0,
        maxSpeed: session ? session.maxSpeed : 0,
        avgPace: session ? session.avgPace : 0,
        pointCount: session ? session.pointCount : 0,
      });
    } catch (err) {
      console.error('Error stopping tracking:', err);
      socket.emit('error', { message: 'Error deteniendo tracking' });
    }
  });

  // Evento: Disconnect
  socket.on('disconnect', async () => {
    console.log(`User ${userName} disconnected from room ${socket.roomCode}`);
    socket.to(socket.roomCode).emit('userLeft', {
      userId: socket.userId,
      name: userName,
      message: `${userName} ha dejado la sala`,
    });

    if (socket.isRunner) {
      const timerKey = `${socket.roomCode}:${socket.userId}`;
      runnerTimers[timerKey] = setTimeout(async () => {
        delete runnerTimers[timerKey];
        try {
          // Si el 'disconnect' de un socket viejo llegó después de que el
          // corredor ya se reconectó con otro, no cerrar la sala.
          const inRoom = await io.in(socket.roomCode).fetchSockets();
          if (inRoom.some((s) => s.handshake?.query?.isRunner === 'true')) return;
          const session = await TrackingSession.findOne({ code: socket.roomCode });
          if (session && session.status === 'active') {
            await finalizeSession(session, { autoClosed: true });
            clearRoomSession(socket.roomCode);
            io.to(socket.roomCode).emit('trackingStopped', {
              message: 'El corredor perdió la conexión. Si vuelve, la carrera continúa.',
              totalDistance: session.totalDistance,
              avgSpeed: session.avgSpeed,
              maxSpeed: session.maxSpeed,
              avgPace: session.avgPace,
              pointCount: session.pointCount,
            });
          }
        } catch (err) {
          console.error('Error en runner disconnect timeout:', err);
        }
      }, runnerDisconnectGraceMs);
    }
  });
});

const BASE_PORT = Number(process.env.PORT) || 3000;
const MAX_PORT_ATTEMPTS = 10;
let currentPort = BASE_PORT;

// Si el puerto está ocupado (EADDRINUSE), prueba el siguiente (3001, 3002, …).
server.on('error', (err) => {
  if (err.code === 'EADDRINUSE' && currentPort < BASE_PORT + MAX_PORT_ATTEMPTS - 1) {
    console.warn(`Puerto ${currentPort} en uso, probando ${currentPort + 1}...`);
    currentPort += 1;
    server.listen(currentPort);
    return;
  }
  console.error('Error al iniciar el servidor:', err);
  process.exit(1);
});

server.on('listening', () => {
  console.log(`Servidor corriendo en puerto ${currentPort}`);
  if (currentPort !== BASE_PORT) {
    console.warn(`OJO: el puerto ${BASE_PORT} estaba ocupado. Usa BACKEND_URL=http://<tu-ip>:${currentPort}/api en Flutter.`);
  }
});

server.listen(currentPort);
