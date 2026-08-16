const mongoose = require('mongoose');

const trackingLocationSchema = new mongoose.Schema({
  roomCode: {
    type: String,
    required: true,
    uppercase: true,
    trim: true,
    index: true,
  },
  session: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'TrackingSession',
    index: true,
  },
  runner: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  latitude: {
    type: Number,
    required: true,
  },
  longitude: {
    type: Number,
    required: true,
  },
  speed: {
    type: Number,
    default: 0, // km/h or m/s
  },
  pace: {
    type: Number,
    default: 0, // min/km
  },
  heading: {
    type: Number,
    default: 0,
  },
  accuracy: {
    type: Number,
    default: 0,
  },
  altitude: {
    type: Number,
    default: 0,
  },
  timestamp: {
    type: Date,
    default: Date.now,
  },
}, {
  timestamps: true,
});

trackingLocationSchema.index({ roomCode: 1, timestamp: 1 });
trackingLocationSchema.index({ session: 1, timestamp: 1 });

module.exports = mongoose.model('TrackingLocation', trackingLocationSchema);
