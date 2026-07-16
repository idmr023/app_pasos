const mongoose = require('mongoose');

const userRewardSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  reward: {
    type: String,
    required: true
  }
}, {
  timestamps: true
});

userRewardSchema.index({ user: 1, reward: 1 }, { unique: true });

module.exports = mongoose.model('UserReward', userRewardSchema);