const mongoose = require('mongoose');

// Parámetros fisiológicos y objetivo del atleta para el módulo Entrenamiento.
const trainingProfileSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, unique: true },
  maxHeartRate: { type: Number, default: null },     // null → se estima con la FC máx observada
  restingHeartRate: { type: Number, default: null },
  weeklySessions: { type: Number, min: 2, max: 7, default: 4 }, // días que puede entrenar
  goal: {
    name: { type: String, default: '' },
    distanceKm: { type: Number, default: null },
    targetTimeSec: { type: Number, default: null },
    date: { type: Date, default: null }
  }
}, { timestamps: true });

module.exports = mongoose.model('TrainingProfile', trainingProfileSchema);
