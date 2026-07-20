const mongoose = require('mongoose');

const quoteSchema = new mongoose.Schema({
  text: {
    type: String,
    required: true
  },
  type: {
    type: String,
    enum: ['streak', 'anniversary'],
    required: true
  },
  minWeeks: {
    type: Number,
    default: 0
  },
  minMonths: {
    type: Number,
    default: 0
  },
  active: {
    type: Boolean,
    default: true
  }
}, {
  timestamps: true
});

quoteSchema.index({ type: 1, minWeeks: -1 });
quoteSchema.index({ type: 1, minMonths: -1 });

module.exports = mongoose.model('Quote', quoteSchema);
