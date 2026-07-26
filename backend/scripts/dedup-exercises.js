const mongoose = require('mongoose');
const dns = require('dns');
const Exercise = require('../models/Exercise');
const Routine = require('../models/Routine');
const Workout = require('../models/Workout');
require('dotenv').config();

dns.setServers(['8.8.8.8', '1.1.1.1']);

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/app-pasos';

function normalize(name) {
  return (name || '').toLowerCase().trim().replace(/\s+/g, ' ');
}

function scoreExercise(ex) {
  let score = 0;
  if (ex.gifUrl) score += 100;
  if (ex.imageUrl) score += 50;
  if (ex.nameSpanish) score += 25;
  if (ex.descriptionSpanish) score += 10;
  if (ex.instructions && ex.instructions.length > 0) score += 10;
  if (ex.description) score += 5;
  return score;
}

async function dedup() {
  console.log('Conectando a MongoDB...');
  await mongoose.connect(MONGODB_URI);
  console.log('Conectado.\n');

  const exercises = await Exercise.find().lean();
  console.log(`Total ejercicios en BD: ${exercises.length}\n`);

  const groups = {};
  for (const ex of exercises) {
    const key = normalize(ex.name);
    if (!groups[key]) groups[key] = [];
    groups[key].push(ex);
  }

  const dupGroups = Object.entries(groups).filter(([_, docs]) => docs.length > 1);
  console.log(`Grupos con duplicados: ${dupGroups.length}\n`);

  if (dupGroups.length === 0) {
    console.log('No hay duplicados. Fin.');
    await mongoose.disconnect();
    return;
  }

  let totalDeleted = 0;
  let totalRefsUpdated = 0;

  for (const [name, docs] of dupGroups) {
    const sorted = docs.sort((a, b) => scoreExercise(b) - scoreExercise(a));
    const keep = sorted[0];
    const deleteIds = sorted.slice(1).map(d => d._id);
    const deleteExternalIds = sorted.slice(1).map(d => d.externalId);

    console.log(`\n"${name}" (${docs.length} copias)`);
    console.log(`  Mantener: ${keep.externalId} (score: ${scoreExercise(keep)})`);
    console.log(`  Eliminar: ${deleteExternalIds.join(', ')}`);

    const routineResult = await Routine.updateMany(
      { 'exercises.exercise': { $in: deleteExternalIds } },
      { $set: { 'exercises.$[elem].exercise': keep.externalId } },
      { arrayFilters: [{ 'elem.exercise': { $in: deleteExternalIds } }] }
    );
    const workoutResult = await Workout.updateMany(
      { 'exercises.exercise': { $in: deleteExternalIds } },
      { $set: { 'exercises.$[elem].exercise': keep.externalId } },
      { arrayFilters: [{ 'elem.exercise': { $in: deleteExternalIds } }] }
    );
    const refsUpdated = routineResult.modifiedCount + workoutResult.modifiedCount;
    totalRefsUpdated += refsUpdated;
    if (refsUpdated > 0) {
      console.log(`  Referencias actualizadas: ${refsUpdated} documentos (routines/workouts)`);
    }

    await Exercise.deleteMany({ _id: { $in: deleteIds } });
    totalDeleted += deleteIds.length;
    console.log(`  Eliminados: ${deleteIds.length} ejercicios`);
  }

  console.log('\n=== RESUMEN ===');
  console.log(`Duplicados eliminados: ${totalDeleted}`);
  console.log(`Referencias actualizadas: ${totalRefsUpdated} documentos`);
  console.log(`Ejercicios restantes: ${exercises.length - totalDeleted}`);

  await mongoose.disconnect();
  console.log('\nDesconectado de MongoDB.');
}

dedup().catch(err => {
  console.error('Error fatal:', err);
  process.exit(1);
});
