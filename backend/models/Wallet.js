const mongoose = require('mongoose');

// Monedero de pasos (uno por usuario).
//
// saldo = earned + net
//   - earned: pasos ganados = suma de DailyStepCredit (nunca baja).
//   - net:    suma de todos los movimientos (gastos negativos, premios/reembolsos positivos).
//
// Cada movimiento se aplica con UNA sola operación atómica sobre este documento
// que a la vez: comprueba saldo suficiente, comprueba que la clave no se aplicó
// antes (`ops.k`), incrementa `net` y añade la operación al diario `ops`.
// Así no hay saldo negativo ni doble cobro/pago con peticiones concurrentes,
// sin necesitar transacciones de MongoDB (replica set).
// `ops` es el diario de escritura; WalletTransaction es su copia consultable.
const walletSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true
  },
  earned: {
    type: Number,
    default: 0
  },
  net: {
    type: Number,
    default: 0
  },
  ops: [{
    _id: false,
    k: String,   // clave de idempotencia
    a: Number,   // importe con signo
    t: String,   // tipo
    r: String,   // ref (artículo o reto)
    at: Date
  }],
  equipped: {
    skin: { type: String, default: null },
    trail: { type: String, default: null }
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('Wallet', walletSchema);
