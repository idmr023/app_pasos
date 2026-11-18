const mongoose = require('mongoose');

// Pasos acreditados al monedero por usuario y día.
// steps = máximo registrado ese día entre TODOS los retos del usuario (los mismos
// pasos registrados en varios retos solo cuentan una vez). Se actualiza con $max,
// así que nunca baja: borrar un reto o corregir pasos a la baja no quita saldo.
const dailyStepCreditSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  day: {
    type: Date,
    required: true
  },
  steps: {
    type: Number,
    default: 0,
    min: 0
  }
});

dailyStepCreditSchema.index({ user: 1, day: 1 }, { unique: true });

module.exports = mongoose.model('DailyStepCredit', dailyStepCreditSchema);
