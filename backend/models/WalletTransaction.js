const mongoose = require('mongoose');

// Libro mayor (ledger) de la economía de pasos. Cada movimiento del saldo
// queda registrado aquí con su importe con signo (negativo = gasto).
// `key` es la clave de idempotencia de la operación (p. ej. `purchase:skin_fuego`,
// `stake:<challengeId>:creator`, `win:<challengeId>`): es única por usuario,
// así que una misma operación nunca se registra dos veces.
// Ver docs/WALLET.md.
const walletTransactionSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  key: {
    type: String,
    required: true
  },
  amount: {
    type: Number,
    required: true
  },
  type: {
    type: String,
    enum: ['purchase', 'wager_stake', 'wager_win', 'wager_refund'],
    required: true
  },
  // Artículo comprado o id del reto de la apuesta
  ref: {
    type: String,
    default: ''
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
});

walletTransactionSchema.index({ user: 1, key: 1 }, { unique: true });
walletTransactionSchema.index({ user: 1, createdAt: -1 });

module.exports = mongoose.model('WalletTransaction', walletTransactionSchema);
