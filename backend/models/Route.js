const mongoose = require('mongoose');

const coordinateSchema = new mongoose.Schema({
  lat: { type: Number, required: true },
  lng: { type: Number, required: true },
  elevation: { type: Number, default: 0 },
  timestamp: { type: String, default: '' },
  heartRate: { type: Number, default: 0 },
}, { _id: false });

const routeDesignSchema = new mongoose.Schema({
  routeColor: { type: String, default: '#3B82F6' },
  backgroundColor: { type: String, default: '#0F172A' },
  fontFamily: { type: String, default: 'Montserrat' },
  lineWidth: { type: Number, default: 4 },
  showStats: [{ type: String }],
  statsLayout: { type: String, default: 'bottom-bar' },
  lineStyle: { type: String, default: 'solid' },
  showElevation: { type: Boolean, default: false },
}, { _id: false });

const routeSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  title: {
    type: String,
    default: ''
  },
  source: {
    type: String,
    enum: ['gpx', 'tcx', 'strava', 'manual'],
    default: 'manual'
  },
  stravaActivityId: {
    type: Number,
    default: null
  },
  coordinates: [coordinateSchema],
  distance: {
    type: Number,
    default: 0
  },
  duration: {
    type: Number,
    default: 0
  },
  elevationGain: {
    type: Number,
    default: 0
  },
  averagePace: {
    type: Number,
    default: 0
  },
  averageHeartRate: {
    type: Number,
    default: 0
  },
  maxHeartRate: {
    type: Number,
    default: 0
  },
  calories: {
    type: Number,
    default: 0
  },
  activityType: {
    type: String,
    enum: ['run', 'ride', 'walk', 'hike', 'other'],
    default: 'run'
  },
  startDate: {
    type: Date,
    default: null
  },
  design: routeDesignSchema,
}, {
  timestamps: true
});

routeSchema.index({ user: 1, createdAt: -1 });

module.exports = mongoose.model('Route', routeSchema);