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

// Modelos para el manejo de sockets
const jwt = require('jsonwebtoken');
const User = require('./models/User');
const TrackingSession = require('./models/TrackingSession');
const TrackingLocation = require('./models/TrackingLocation');
const LiveMessage = require('./models/LiveMessage');

dns.setServers(['8.8.8.8', '1.1.1.1']);

const app = express();
app.set('trust proxy', 1);

const allowedOrigins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map(o => o.trim())
  .filter(Boolean);

app.use(helmet({
  crossOriginResourcePolicy: { policy: 'cross-origin' },
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
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: allowedOrigins.length > 0 ? allowedOrigins : '*',
    methods: ['GET', 'POST'],
  },
  pingTimeout: 60000,
  pingInterval: 25000,
});

// Middleware de autenticación para sockets
io.use(async (socket, next) => {
  const token = socket.handshake.auth?.token;
  const roomCode = socket.handshake.query?.roomCode;

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

    next();
  } catch (err) {
    next(new Error('Authentication error: Invalid token'));
  }
});

io.on('connection', (socket) => {
  console.log(`User ${socket.user.name} connected (ID: ${socket.userId}) to room ${socket.roomCode}`);

  // Validar sala
  if (!socket.roomCode) {
    socket.emit('error', { message: 'Missing room code' });
    socket.disconnect(true);
    return;
  }

  // Unir a la sala
  socket.join(socket.roomCode);

  // Confirmar conexión
  socket.emit('connected', {
    roomCode: socket.roomCode,
    isRunner: socket.handshake.query?.isRunner === 'true',
    message: 'Conectado a la sala en vivo',
  });

  // Notificar a la sala
  socket.to(socket.roomCode).emit('userJoined', {
    userId: socket.userId,
    name: socket.user.name,
    message: `${socket.user.name} se unió a la sala`,
  });

  // Evento: Actualización de ubicación (corredor)
  socket.on('locationUpdate', async (data) => {
    if (!socket.handshake.query?.isRunner === true) {
      return; // Solo el corredor puede enviar ubicaciones
    }

    try {
      // Guardar ubicación en MongoDB
      const location = await TrackingLocation.create({
        roomCode: socket.roomCode,
        runner: socket.userId,
        latitude: data.latitude,
        longitude: data.longitude,
        speed: data.speed,
        pace: data.pace,
        heading: data.heading,
        accuracy: data.accuracy,
        altitude: data.altitude,
        timestamp: new Date(data.timestamp || Date.now()),
      });

      // Retransmitir a todos los espectadores
      socket.to(socket.roomCode).emit('locationUpdate', {
        latitude: data.latitude,
        longitude: data.longitude,
        speed: data.speed,
        pace: data.pace,
        heading: data.heading,
        accuracy: data.accuracy,
        altitude: data.altitude,
        timestamp: data.timestamp || Date.now(),
      });
    } catch (err) {
      console.error('Error saving location:', err);
      socket.emit('error', { message: 'Error guardando ubicación' });
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
      // Determinar tipo de remitente
      const isRunnerQuery = socket.handshake.query?.isRunner === 'true';

      // Guardar mensaje en MongoDB
      const chatMsg = await LiveMessage.create({
        roomCode: socket.roomCode,
        sender: socket.userId,
        senderType: isRunnerQuery ? 'runner' : 'spectator',
        message: message.trim(),
        timestamp: new Date(),
      });

      // Poblar información del remitente
      await chatMsg.populate('sender', 'name avatar').execPopulate();

      // Retransmitir a todos en la sala
      io.to(socket.roomCode).emit('chatMessage', {
        message: message.trim(),
        senderId: socket.userId,
        senderName: socket.user.name,
        senderAvatar: socket.user.avatar,
        timestamp: chatMsg.timestamp.toISOString(),
        senderType: isRunnerQuery ? 'runner' : 'spectator',
      });
    } catch (err) {
      console.error('Error saving chat message:', err);
      socket.emit('error', { message: 'Error enviando mensaje' });
    }
  });

  // Evento: Detener tracking (corredor)
  socket.on('stopTracking', async () => {
    const isRunnerQuery = socket.handshake.query?.isRunner === 'true';
    
    if (!isRunnerQuery) {
      return socket.emit('error', { message: 'Only runner can stop tracking' });
    }

    try {
      const session = await TrackingSession.findOne({ roomCode: socket.roomCode });
      if (session) {
        session.status = 'completed';
        session.endedAt = new Date();
        await session.save();
      }

      // Notificar a todos
      io.to(socket.roomCode).emit('trackingStopped', {
        message: 'El corredor ha detenido el tracking',
      });
    } catch (err) {
      console.error('Error stopping tracking:', err);
      socket.emit('error', { message: 'Error deteniendo tracking' });
    }
  });

  // Evento: Disconnect
  socket.on('disconnect', () => {
    console.log(`User ${socket.user.name} disconnected from room ${socket.roomCode}`);
    socket.to(socket.roomCode).emit('userLeft', {
      userId: socket.userId,
      name: socket.user.name,
      message: `${socket.user.name} ha dejado la sala`,
    });
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Servidor corriendo en puerto ${PORT}`);
});
