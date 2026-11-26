const mongoose = require('mongoose');

// Estado de progresión de carga por usuario y ejercicio (ver services/progressionService.js).
const exerciseProgressSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  exercise: {
    type: String,
    required: true
  },
  exerciseName: { type: String, default: '' },
  currentWeightKg: { type: Number, default: 0 }, // 0 = sin calibrar
  previousWeightKg: { type: Number, default: 0 },
  currentSeconds: { type: Number, default: 0 },  // ejercicios por tiempo
  unit: { type: String, enum: ['kg', 'lb'], default: 'kg' }, // solo visualización
  loadNote: { type: String, default: '' },       // "por lado", "por mancuerna"...
  status: {
    type: String,
    enum: ['calibrating', 'progressing', 'bridge'],
    default: 'calibrating'
  },
  bridgeTargetKg: { type: Number, default: 0 },
  bridgeHeavySets: { type: Number, default: 0 },
  stallCount: { type: Number, default: 0 },
  lastSession: {
    date: Date,
    weightKg: Number,
    reps: [Number]
  },
  next: {
    action: String,
    weightKg: Number,
    targetReps: Number,
    heavySets: Number,
    baseWeightKg: Number,
    targetSeconds: Number,
    message: String
  }
}, {
  timestamps: true
});

exerciseProgressSchema.index({ user: 1, exercise: 1 }, { unique: true });

module.exports = mongoose.model('ExerciseProgress', exerciseProgressSchema);
