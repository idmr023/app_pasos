const mongoose = require('mongoose');

// Grupo semanal de una liga (hasta MAX_GROUP_SIZE usuarios de la misma división).
// Ver docs/LEAGUES.md.
const leagueGroupSchema = new mongoose.Schema({
  week: {
    type: String, // clave ISO de semana en America/Lima, p. ej. "2026-W47"
    required: true,
  },
  division: {
    type: Number, // 0 = Bronce … 5 = Leyenda
    required: true,
    min: 0,
  },
  // Número de grupo dentro de (week, division). Único: serializa la creación de grupos
  // cuando varias peticiones concurrentes encuentran todos los grupos llenos.
  seq: {
    type: Number,
    required: true,
  },
  members: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
  }],
  finalized: {
    type: Boolean,
    default: false,
  },
  finalizedAt: {
    type: Date,
    default: null,
  },
}, {
  timestamps: true,
});

// Buscar un grupo con cupo en la semana/división al unirse (ordenado por seq).
leagueGroupSchema.index({ week: 1, division: 1, seq: 1 }, { unique: true });

module.exports = mongoose.model('LeagueGroup', leagueGroupSchema);
