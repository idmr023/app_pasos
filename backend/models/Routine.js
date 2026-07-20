const mongoose = require('mongoose');

const routineExerciseSchema = new mongoose.Schema({
  exercise: {
    type: String,
    required: true
  },
  exerciseName: {
    type: String,
    default: ''
  },
  sets: {
    type: Number,
    default: 3
  },
  reps: {
    type: String,
    default: '10'
  },
  restTime: {
    type: Number,
    default: 60
  },
  order: {
    type: Number,
    default: 0
  }
});

const routineSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  name: {
    type: String,
    required: true,
    trim: true
  },
  exercises: [routineExerciseSchema],
  isWarmup: {
    type: Boolean,
    default: false
  }
}, {
  timestamps: true
});

routineSchema.index({ user: 1, createdAt: -1 });
routineSchema.index({ user: 1, name: 1 }, { unique: true });

module.exports = mongoose.model('Routine', routineSchema);