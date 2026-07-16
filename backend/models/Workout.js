const mongoose = require('mongoose');

const workoutExerciseSchema = new mongoose.Schema({
  exercise: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Exercise',
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

module.exports = mongoose.model('Workout', workoutSchema);