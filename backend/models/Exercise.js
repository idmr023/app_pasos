const mongoose = require('mongoose');

const exerciseSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  category: {
    type: String,
    enum: ['warmup', 'strength', 'cardio', 'flexibility'],
    required: true
  },
  imageUrl: {
    type: String,
    default: ''
  },
  defaultSets: {
    type: Number,
    default: 3
  },
  defaultReps: {
    type: String,
    default: '10'
  },
  restTime: {
    type: Number,
    default: 60
  },
  description: {
    type: String,
    default: ''
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('Exercise', exerciseSchema);