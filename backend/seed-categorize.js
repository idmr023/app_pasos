const mongoose = require('mongoose');
const dns = require('dns');
const Exercise = require('./models/Exercise');
require('dotenv').config();

dns.setServers(['8.8.8.8', '1.1.1.1']);

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/app-pasos';

const WARMUP_PATTERNS = [
  [/neck rotation|rotación de cuello/i, 'Rotación de Cuello'],
  [/arm circles|círculos de brazos/i, 'Círculos de Brazos'],
  [/torso twist|torsión de torso/i, 'Torsión de Torso'],
  [/dynamic lunge|estocadas dinámicas/i, 'Estocadas Dinámicas'],
  [/jumping jack|saltos de tijera/i, 'Saltos de Tijera'],
  [/high knee|rodillas al pecho/i, 'High Knees / Rodillas al Pecho'],
  [/mountain climber|montañista/i, 'Montañista'],
  [/jump squat|saltos de sentadilla/i, 'Saltos de Sentadilla'],
  [/jump rope|saltos de cuerda/i, 'Saltos de Cuerda'],
  [/hamstring stretch|estiramiento de isquiotibiales/i, 'Estiramiento Isquiotibiales'],
  [/quad stretch|estiramiento de cuádriceps/i, 'Estiramiento Cuádriceps'],
  [/shoulder stretch|estiramiento de hombros/i, 'Estiramiento Hombros'],
  [/chest stretch|estiramiento de pecho/i, 'Estiramiento Pecho'],
  [/torso bend|flexión de torso/i, 'Flexión de Torso'],
  [/back stretch|estiramiento de espalda/i, 'Estiramiento Espalda'],
  [/butterfly stretch|mariposa/i, 'Mariposa'],
  [/hip circle|círculos de cadera/i, 'Círculos de Cadera'],
  [/ankle circle|rotación de tobillos/i, 'Rotación Tobillos'],
  [/chest opener|apertura de pecho/i, 'Apertura de Pecho'],
  [/90.90 hamstring|estiramiento de cadera en 90/i, 'Cadera 90/90'],
  [/psoas stretch|estiramiento de psoas/i, 'Estiramiento Psoas'],
  [/calf stretch|estiramiento de gemelos/i, 'Estiramiento Gemelos'],
  [/side bend|flexión lateral de torso/i, 'Flexión Lateral'],
  [/adductor stretch|estiramiento de abductores/i, 'Estiramiento Abductores'],
  [/glute stretch|estiramiento de glúteos/i, 'Estiramiento Glúteos'],
  [/spine rotation|rotación de columna supina/i, 'Rotación Columna'],
  [/box jump|saltos de caja/i, 'Saltos de Caja'],
  [/butt kick|saltos de talón a glúteo/i, 'Talón a Glúteo'],
  [/sprint/i, 'Sprints'],
  [/cross climber|escalador cruzado/i, 'Escalador Cruzado'],
  [/paused squat|sentadilla profunda con pausa/i, 'Sentadilla Pausa'],
];

async function seed() {
  console.log('Conectando a MongoDB...');
  await mongoose.connect(MONGODB_URI);
  console.log('Conectado.\n');

  // First: recategorize flexibility exercises to warmup
  const flex = await Exercise.updateMany(
    { category: 'flexibility' },
    { $set: { category: 'warmup' } }
  );
  console.log(`Flexibility → warmup: ${flex.modifiedCount}`);

  let actualizados = 0;
  for (const [regex, label] of WARMUP_PATTERNS) {
    const r = await Exercise.updateMany(
      { $or: [{ name: regex }, { nameSpanish: regex }] },
      { $set: { category: 'warmup' } }
    );
    if (r.modifiedCount > 0) {
      console.log(`  '${label}' → warmup (${r.modifiedCount})`);
      actualizados += r.modifiedCount;
    }
  }

  console.log(`\nTotal actualizados a warmup: ${actualizados}`);

  const totales = await Exercise.aggregate([
    { $group: { _id: '$category', count: { $sum: 1 } } },
    { $sort: { _id: 1 } },
  ]);
  console.log('\nCategorías:');
  for (const t of totales) {
    console.log(`  ${t._id || '(sin categoría)'}: ${t.count}`);
  }

  await mongoose.disconnect();
  console.log('\nDesconectado.');
}

seed().catch(err => {
  console.error('Error fatal:', err);
  process.exit(1);
});
