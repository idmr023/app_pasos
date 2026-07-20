const mongoose = require('mongoose');

const workoutExerciseSchema = new mongoose.Schema({
  exercise: {
    type: String,
    required: true
  },
  exerciseName: String,
  setsCompleted: {
    type: Number,
    default: 0
  },
  repsCompleted: {
    type: String,
    default: ''
  },
  weightKg: {
    type: Number,
    default: 0
  }
});

const workoutSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  routine: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Routine',
    default: null
  },
  routineName: {
    type: String,
    default: ''
  },
  date: {
    type: Date,
    required: true
  },
  duration: {
    type: Number,
    default: 0
  },
  exercises: [workoutExerciseSchema]
}, {
  timestamps: true
});

workoutSchema.index({ user: 1, date: -1 });

module.exports = mongoose.model('Workout', workoutSchema);