const mongoose = require('mongoose');

const gameScoreSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  // Identificador del minijuego. Las partidas antiguas (Orbiter) no lo tienen.
  game: {
    type: String,
    default: 'sprint'
  },
  level: {
    type: Number,
    required: true
  },
  // Obstáculos esquivados. Se conserva el nombre original (Orbiter) por compatibilidad;
  // el cliente nuevo puede enviarlo como `obstaclesDodged`.
  asteroidsDodged: {
    type: Number,
    required: true
  },
  score: {
    type: Number,
    required: true
  },
  // Campos opcionales del Sprint
  distance: { type: Number, default: 0 },   // metros recorridos
  coins: { type: Number, default: 0 },      // monedas recogidas
  maxCombo: { type: Number, default: 0 },
  durationMs: { type: Number, default: 0 },
  xpAwarded: { type: Number, default: 0 },
  createdAt: {
    type: Date,
    default: Date.now
  }
});

gameScoreSchema.index({ score: -1 });
gameScoreSchema.index({ user: 1, createdAt: -1 });

module.exports = mongoose.model('GameScore', gameScoreSchema);
