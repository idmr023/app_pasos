const mongoose = require('mongoose');
const https = require('https');
const dns = require('dns');
require('dotenv').config();

dns.setServers(['8.8.8.8', '1.1.1.1']);

const Exercise = require('./models/Exercise');

const API_KEY = process.env.WORKOUTX_API_KEY;
const BASE_URL = 'https://api.workoutxapp.com/v1';

const CATEGORY_MAP = {
  strength: 'strength',
  cardio: 'cardio',
};

function mapCategory(cat) {
  return CATEGORY_MAP[cat?.toLowerCase()] || 'strength';
}

function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { 'X-WorkoutX-Key': API_KEY } }, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        if (res.statusCode === 200) return resolve(JSON.parse(data));
        reject(new Error(`HTTP ${res.statusCode}: ${data.slice(0, 200)}`));
      });
    })
    .on('error', reject)
    .setTimeout(15000, function () { this.destroy(); reject(new Error('Timeout')); });
  });
}

async function syncExercises() {
  if (!API_KEY || !API_KEY.startsWith('wx_')) {
    console.error('Error: WORKOUTX_API_KEY no válida en .env. Debe comenzar con wx_');
    process.exit(1);
  }

  await mongoose.connect(process.env.MONGODB_URI);
  console.log('Conectado a MongoDB Atlas');

  const first = await fetchJson(`${BASE_URL}/exercises?limit=1&offset=0`);
  const total = first.total;
  console.log(`Total de ejercicios en WorkoutX: ${total}`);

  const PAGE_SIZE = 10;
  const pages = Math.ceil(total / PAGE_SIZE);
  let added = 0, updated = 0, skipped = 0, errors = 0;

  for (let page = 0; page < pages; page++) {
    const offset = page * PAGE_SIZE;
    process.stdout.write(`\rProcesando página ${page + 1}/${pages}...`);

    try {
      const data = await fetchJson(`${BASE_URL}/exercises?lang=es&limit=${PAGE_SIZE}&offset=${offset}`);

      for (const ex of (data.data || [])) {
        try {
          // Buscar por gifUrl (no cambia con el idioma)
          const existing = ex.gifUrl
            ? await Exercise.findOne({ imageUrl: ex.gifUrl })
            : null;

          if (existing) {
            const updates = {};

            // nameSpanish: si WorkoutX devuelve nombre en español y es diferente al inglés
            if (!existing.nameSpanish && ex.name !== existing.name) {
              updates.nameSpanish = ex.name;
            }
            // description: siempre actualizar con la versión en español
            if (ex.instructions?.length) {
              updates.description = ex.instructions.join('\n');
            }
            // difficulty: actualizar con la versión en español
            if (ex.difficulty) updates.difficulty = ex.difficulty;
            // Rellenar campos faltantes
            if (!existing.muscle && ex.target) updates.muscle = ex.target;
            if (!existing.equipment && ex.equipment) updates.equipment = ex.equipment;
            if (ex.recommendedSets && !existing.defaultSets) updates.defaultSets = parseInt(ex.recommendedSets) || 3;
            if (ex.recommendedReps && !existing.defaultReps) updates.defaultReps = ex.recommendedReps;

            if (Object.keys(updates).length > 0) {
              await Exercise.updateOne({ _id: existing._id }, { $set: updates });
              updated++;
            } else {
              skipped++;
            }
          } else {
            // Nuevo ejercicio (no existía antes)
            await Exercise.create({
              name: ex.name,
              nameSpanish: '',
              category: mapCategory(ex.category),
              imageUrl: ex.gifUrl || '',
              description: ex.instructions?.join('\n') || '',
              videoUrl: '',
              muscle: ex.target || '',
              equipment: ex.equipment || '',
              difficulty: ex.difficulty || '',
              defaultSets: parseInt(ex.recommendedSets) || 3,
              defaultReps: ex.recommendedReps || '10',
              restTime: 60,
            });
            added++;
          }
        } catch (e) {
          errors++;
        }
      }
    } catch (e) {
      errors++;
    }
  }

  console.log(`\n\nResumen:`);
  console.log(`  Añadidos:   ${added}`);
  console.log(`  Actualizados: ${updated}`);
  console.log(`  Saltados:    ${skipped}`);
  console.log(`  Errores:     ${errors}`);
  console.log(`  Total BD:    ${await Exercise.countDocuments()}`);

  await mongoose.disconnect();
  console.log('\nSincronización completada.');
}

syncExercises().catch((err) => {
  console.error('\nError general:', err.message);
  process.exit(1);
});
