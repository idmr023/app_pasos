const mongoose = require('mongoose');

const stepEntrySchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  challenge: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Challenge',
    required: true
  },
  date: {
    type: Date,
    required: true
  },
  steps: {
    type: Number,
    required: true,
    min: 0
  }
}, {
  timestamps: true
});

stepEntrySchema.index({ user: 1, challenge: 1, date: 1 }, { unique: true });

module.exports = mongoose.model('StepEntry', stepEntrySchema);
