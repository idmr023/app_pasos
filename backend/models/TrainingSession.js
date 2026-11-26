const mongoose = require('mongoose');

// Sesión de entrenamiento de resistencia (carrera, bici, caminata...), importada
// de Strava o registrada a mano. El análisis (carga, zonas, insights) se calcula
// al leer en services/trainingAnalysisService.js — no se persiste para que
// cambie si el usuario ajusta su FC máx/reposo. Ver docs/TRAINING.md.

const splitSchema = new mongoose.Schema({
  index: Number,
  distance: Number,          // m
  movingTime: Number,        // s
  elevationDiff: Number,     // m
  averageHeartRate: Number,  // ppm (0 = sin dato)
  averageSpeed: Number       // m/s
}, { _id: false });

const lapSchema = new mongoose.Schema({
  index: Number,
  name: String,
  distance: Number,
  movingTime: Number,
  averageSpeed: Number,
  averageHeartRate: Number,
  maxHeartRate: Number
}, { _id: false });

const trainingSessionSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  source: { type: String, enum: ['strava', 'manual'], default: 'manual' },
  stravaActivityId: { type: Number, default: null },
  title: { type: String, default: 'Entrenamiento', maxlength: 120 },
  sport: { type: String, enum: ['run', 'trail', 'ride', 'walk', 'hike', 'swim', 'other'], default: 'run' },
  startDate: { type: Date, required: true },

  distance: { type: Number, default: 0 },        // m
  movingTime: { type: Number, default: 0 },      // s
  elapsedTime: { type: Number, default: 0 },     // s
  elevationGain: { type: Number, default: 0 },   // m
  averageSpeed: { type: Number, default: 0 },    // m/s
  maxSpeed: { type: Number, default: 0 },        // m/s
  averageHeartRate: { type: Number, default: 0 },
  maxHeartRate: { type: Number, default: 0 },
  averageCadence: { type: Number, default: 0 },  // pasos/min (Strava da medio ciclo en carrera; se duplica al importar)
  calories: { type: Number, default: 0 },
  stravaWorkoutType: { type: Number, default: null }, // 1 carrera, 2 tirada larga, 3 entrenamiento

  splits: { type: [splitSchema], default: [] },
  laps: { type: [lapSchema], default: [] },
  // Mejores esfuerzos dentro de la actividad (Strava best_efforts: 1k, 5k, 10k...)
  bestEfforts: {
    type: [new mongoose.Schema({ name: String, distance: Number, elapsedTime: Number }, { _id: false })],
    default: []
  },

  // Datos que anota el atleta
  sessionType: {
    type: String,
    enum: ['auto', 'recovery', 'easy', 'long', 'tempo', 'intervals', 'race', 'other'],
    default: 'auto'
  },
  rpe: { type: Number, min: 1, max: 10, default: null },     // esfuerzo percibido
  feeling: { type: Number, min: 1, max: 5, default: null },  // 1 muy mal … 5 excelente
  notes: { type: String, default: '', maxlength: 1000 }
}, { timestamps: true });

trainingSessionSchema.index({ user: 1, startDate: -1 });
trainingSessionSchema.index(
  { user: 1, stravaActivityId: 1 },
  { unique: true, partialFilterExpression: { stravaActivityId: { $type: 'number' } } }
);

module.exports = mongoose.model('TrainingSession', trainingSessionSchema);
