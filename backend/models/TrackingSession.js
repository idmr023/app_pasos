const mongoose = require('mongoose');

const trackingSessionSchema = new mongoose.Schema({
  code: {
    type: String,
    required: true,
    unique: true,
    uppercase: true,
    trim: true,
    index: true,
  },
  runner: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  title: {
    type: String,
    default: 'Carrera en Vivo',
    trim: true,
    maxlength: 100,
  },
  status: {
    type: String,
    enum: ['active', 'completed', 'cancelled'],
    default: 'active',
    index: true,
  },
  startedAt: {
    type: Date,
    default: Date.now,
  },
  endedAt: {
    type: Date,
  },
  totalDistance: {
    type: Number,
    default: 0, // meters
  },
  avgSpeed: {
    type: Number,
    default: 0, // km/h
  },
  maxSpeed: {
    type: Number,
    default: 0, // km/h
  },
  avgPace: {
    type: Number,
    default: 0, // min/km
  },
  pointCount: {
    type: Number,
    default: 0,
  },
  isPublic: {
    type: Boolean,
    default: true,
  },
}, {
  timestamps: true,
});

trackingSessionSchema.index({ runner: 1, status: 1 });
trackingSessionSchema.index({ createdAt: -1 });

module.exports = mongoose.model('TrackingSession', trackingSessionSchema);
