const mongoose = require('mongoose');

const challengeSchema = new mongoose.Schema({
  code: {
    type: String,
    required: true,
    unique: true,
    uppercase: true
  },
  creator: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  opponent: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  },
  duration: {
    type: Number,
    default: 30,
    min: 1,
    max: 365
  },
  status: {
    type: String,
    enum: ['waiting', 'active', 'finished'],
    default: 'waiting'
  },
  startDate: {
    type: Date,
    default: Date.now
  },
  endDate: {
    type: Date
  },
  // Reto con apuesta (economía de pasos, ver docs/WALLET.md)
  wager: {
    type: Number,
    default: 0,
    min: 0
  },
  // none: sin apuesta | open: apuestas en juego | paid: bote pagado al ganador
  // | refunded: apuestas devueltas (empate o reto borrado)
  wagerState: {
    type: String,
    enum: ['none', 'open', 'paid', 'refunded'],
    default: 'none'
  },
  wagerWinner: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  },
  wagerSettledAt: {
    type: Date,
    default: null
  },
  // Contador de uniones: cada apuesta del rival lleva una clave distinta
  joinCount: {
    type: Number,
    default: 0
  }
}, {
  timestamps: true
});

challengeSchema.index({ creator: 1, status: 1 });
challengeSchema.index({ opponent: 1, status: 1 });

module.exports = mongoose.model('Challenge', challengeSchema);
