const mongoose = require('mongoose');

const gameScoreSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  level: {
    type: Number,
    required: true
  },
  asteroidsDodged: {
    type: Number,
    required: true
  },
  score: {
    type: Number,
    required: true
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
});

gameScoreSchema.index({ score: -1 });
gameScoreSchema.index({ user: 1, createdAt: -1 });

module.exports = mongoose.model('GameScore', gameScoreSchema);
