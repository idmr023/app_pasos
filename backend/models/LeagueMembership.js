const mongoose = require('mongoose');

// Participación de un usuario en una semana de liga. Una por (user, week).
// Ver docs/LEAGUES.md.
const leagueMembershipSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  week: {
    type: String, // "2026-W47" (America/Lima)
    required: true,
  },
  weekStart: {
    type: Date, // lunes 00:00 America/Lima (instante UTC)
    required: true,
  },
  division: {
    type: Number,
    required: true,
    min: 0,
  },
  group: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'LeagueGroup',
    default: null,
  },
  joinedAt: {
    type: Date,
    default: Date.now,
  },
  // Resultado congelado al cerrar la semana (null mientras la semana está abierta)
  finalPoints: { type: Number, default: null },
  finalRank: { type: Number, default: null },
  result: {
    type: String,
    enum: ['promoted', 'stayed', 'demoted', null],
    default: null,
  },
  nextDivision: { type: Number, default: null },
  resultSeen: { type: Boolean, default: false },
}, {
  timestamps: true,
});

leagueMembershipSchema.index({ user: 1, week: 1 }, { unique: true });
leagueMembershipSchema.index({ user: 1, weekStart: -1 });
leagueMembershipSchema.index({ group: 1 });

module.exports = mongoose.model('LeagueMembership', leagueMembershipSchema);
