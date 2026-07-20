const mongoose = require('mongoose');

const personalRecordSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  exercise: {
    type: String,
    required: true
  },
  exerciseName: {
    type: String,
    default: ''
  },
  maxWeightKg: {
    type: Number,
    default: 0
  }
}, {
  timestamps: true
});

personalRecordSchema.index({ user: 1, exercise: 1 }, { unique: true });

module.exports = mongoose.model('PersonalRecord', personalRecordSchema);
