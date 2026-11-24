const mongoose = require('mongoose');

const liveMessageSchema = new mongoose.Schema({
  roomCode: {
    type: String,
    required: true,
    uppercase: true,
    trim: true,
    index: true,
  },
  session: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'TrackingSession',
    index: true,
  },
  sender: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: false,
    default: null,
  },
  senderName: {
    type: String,
    default: '',
  },
  senderType: {
    type: String,
    enum: ['runner', 'spectator'],
    required: true,
  },
  message: {
    type: String,
    required: true,
    trim: true,
    maxlength: 1000,
  },
  timestamp: {
    type: Date,
    default: Date.now,
  },
  // 'chat' = mensaje normal; 'powerUp' = ánimo de espectador (ver
  // utils/powerUps.js). Default 'chat': los documentos antiguos sin `kind`
  // se tratan como chat (las agregaciones filtran por kind: 'powerUp').
  kind: {
    type: String,
    enum: ['chat', 'powerUp'],
    default: 'chat',
  },
  powerUpType: {
    type: String,
    default: null,
  },
}, {
  timestamps: true,
});

liveMessageSchema.index({ roomCode: 1, timestamp: 1 });
// Estadísticas/recap de ánimos por sala.
liveMessageSchema.index({ roomCode: 1, kind: 1 });

module.exports = mongoose.model('LiveMessage', liveMessageSchema);
