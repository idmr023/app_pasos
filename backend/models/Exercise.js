const mongoose = require('mongoose');

const exerciseSchema = new mongoose.Schema({
  externalId: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  source: {
    type: String,
    enum: ['exercisedb', 'wger'],
    required: true
  },
  name: {
    type: String,
    required: true
  },
  nameSpanish: {
    type: String,
    default: ''
  },
  category: {
    type: String,
    enum: ['strength', 'cardio', 'warmup', 'flexibility'],
    default: 'strength'
  },
  bodyPart: {
    type: String,
    default: ''
  },
  target: {
    type: String,
    default: ''
  },
  equipment: {
    type: String,
    default: ''
  },
  gifUrl: {
    type: String,
    default: ''
  },
  imageUrl: {
    type: String,
    default: ''
  },
  localImage: {
    type: Buffer,
    default: null,
  },
  localImageMime: {
    type: String,
    default: '',
  },
  instructions: [{
    type: String
  }],
  instructionsSpanish: [{
    type: String
  }],
  description: {
    type: String,
    default: ''
  },
  descriptionSpanish: {
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
  }
}, {
  timestamps: true
});

exerciseSchema.index({ name: 'text', nameSpanish: 'text' });
exerciseSchema.index({ category: 1, name: 1 });
exerciseSchema.index({ source: 1, externalId: 1 });

module.exports = mongoose.model('Exercise', exerciseSchema);
