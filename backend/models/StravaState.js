const mongoose = require('mongoose');

const stravaStateSchema = new mongoose.Schema({
  state: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  connected: {
    type: Boolean,
    default: false
  },
  expiresAt: {
    type: Date,
    default: () => new Date(Date.now() + 10 * 60 * 1000) // 10 minutes
  }
});

stravaStateSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

module.exports = mongoose.model('StravaState', stravaStateSchema);
