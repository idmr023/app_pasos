const mongoose = require('mongoose');

const exerciseSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  nameSpanish: {
    type: String,
    default: ''
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
  },
  videoUrl: {
    type: String,
    default: ''
  },
  muscle: {
    type: String,
    default: ''
  },
  equipment: {
    type: String,
    default: ''
  },
  difficulty: {
    type: String,
    default: ''
  }
}, {
  timestamps: true
});

exerciseSchema.index({ category: 1, name: 1 });
exerciseSchema.index({ name: 'text', nameSpanish: 'text' });

module.exports = mongoose.model('Exercise', exerciseSchema);