const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  username: {
    type: String,
    required: true,
    unique: true,
    trim: true,
    minlength: 3
  },
  password: {
    type: String,
    required: true,
    minlength: 6
  },
  displayName: {
    type: String,
    default: ''
  },
  role: {
    type: String,
    enum: ['user', 'admin'],
    default: 'user'
  },
  avatar: {
    type: String,
    default: 'runner'
  },
  xp: {
    type: Number,
    default: 0
  },
  level: {
    type: Number,
    default: 0
  },
  title: {
    type: String,
    default: ''
  },
  securityQuestion: {
    type: String,
    default: ''
  },
  securityAnswer: {
    type: String,
    default: ''
  },
  weight: {
    type: Number,
    default: 0
  },
  height: {
    type: Number,
    default: 0
  },
  goal: {
    type: String,
    enum: ['lose_weight', 'gain_muscle', 'maintain', 'endurance', 'general'],
    default: 'general'
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('User', userSchema);
