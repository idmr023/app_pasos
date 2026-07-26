const mongoose = require('mongoose');
const https = require('https');
const dns = require('dns');
const Exercise = require('./models/Exercise');
require('dotenv').config();

dns.setServers(['8.8.8.8', '1.1.1.1']);

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/app-pasos';
const FREE_DB_JSON_URL = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json';
const FREE_DB_IMAGE_BASE = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/';
const WGER_BASE = 'https://wger.de/api/v2';

const FAMOUS_EXERCISES = [
  { nameEs: 'Press de banca', nameEn: 'Bench Press', category: 'strength', muscle: 'Pecho' },
  { nameEs: 'Sentadilla', nameEn: 'Squat', category: 'strength', muscle: 'Piernas' },
  { nameEs: 'Peso muerto', nameEn: 'Deadlift', category: 'strength', muscle: 'Espalda baja' },
  { nameEs: 'Press militar', nameEn: 'Military Press', category: 'strength', muscle: 'Hombros' },
  { nameEs: 'Dominadas', nameEn: 'Pull-up', category: 'strength', muscle: 'Espalda' },
  { nameEs: 'Remo con barra', nameEn: 'Barbell Row', category: 'strength', muscle: 'Espalda' },
  { nameEs: 'Zancadas', nameEn: 'Lunge', category: 'strength', muscle: 'Piernas' },
  { nameEs: 'Prensa de pierna', nameEn: 'Leg Press', category: 'strength', muscle: 'Piernas' },
  { nameEs: 'Peso muerto rumano', nameEn: 'Romanian Deadlift', category: 'strength', muscle: 'Glúteos' },
  { nameEs: 'Elevación de pantorrillas', nameEn: 'Calf Raise', category: 'strength', muscle: 'Pantorrillas' },
  { nameEs: 'Flexiones', nameEn: 'Push-up', category: 'strength', muscle: 'Pecho' },
  { nameEs: 'Plancha abdominal', nameEn: 'Plank', category: 'strength', muscle: 'Abdomen' },
  { nameEs: 'Abdominales', nameEn: 'Crunch', category: 'strength', muscle: 'Abdomen' },
  { nameEs: 'Elevación de piernas colgado', nameEn: 'Hanging Leg Raise', category: 'strength', muscle: 'Abdomen' },
  { nameEs: 'Giros rusos', nameEn: 'Russian Twist', category: 'strength', muscle: 'Oblicuos' },
  { nameEs: 'Leñadores con cable', nameEn: 'Cable Woodchop', category: 'strength', muscle: 'Oblicuos' },
  { nameEs: 'Burpees', nameEn: 'Burpee', category: 'cardio', muscle: 'Cuerpo completo' },
  { nameEs: 'Correr en cinta', nameEn: 'Treadmill Running', category: 'cardio', muscle: 'Cardio' },
  { nameEs: 'Máquina elíptica', nameEn: 'Elliptical', category: 'cardio', muscle: 'Cardio' },
  { nameEs: 'Máquina de remo', nameEn: 'Rowing Machine', category: 'cardio', muscle: 'Cuerpo completo' },
  { nameEs: 'Escaladora', nameEn: 'Stair Climber', category: 'cardio', muscle: 'Piernas' },
  { nameEs: 'Bicicleta estática', nameEn: 'Stationary Bike', category: 'cardio', muscle: 'Cardio' },
  { nameEs: 'Sentadilla búlgara', nameEn: 'Bulgarian Split Squat', category: 'strength', muscle: 'Piernas' },
  { nameEs: 'Curl de bíceps', nameEn: 'Bicep Curl', category: 'strength', muscle: 'Brazos' },
  { nameEs: 'Fondos en paralelas', nameEn: 'Dip', category: 'strength', muscle: 'Pecho' },
  { nameEs: 'Aperturas con mancuernas', nameEn: 'Dumbbell Fly', category: 'strength', muscle: 'Pecho' },
  { nameEs: 'Jalón al pecho', nameEn: 'Lat Pulldown', category: 'strength', muscle: 'Espalda' },
  { nameEs: 'Press de hombros con mancuernas', nameEn: 'Dumbbell Shoulder Press', category: 'strength', muscle: 'Hombros' },
  { nameEs: 'Peso muerto sumo', nameEn: 'Sumo Deadlift', category: 'strength', muscle: 'Piernas' },
  { nameEs: 'Caminata del granjero', nameEn: 'Farmer Walk', category: 'strength', muscle: 'Cuerpo completo' },
];

function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { 'Accept': 'application/json' } }, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          return resolve(fetchJson(new URL(res.headers.location, url).href));
        }
        if (res.statusCode === 200) return resolve(JSON.parse(data));
        reject(new Error(`HTTP ${res.statusCode}: ${data.slice(0, 200)}`));
      });
    }).on('error', reject).setTimeout(30000, function () { this.destroy(); reject(new Error('Timeout')); });
  });
}

function cleanHtml(html) {
  if (!html) return '';
  return html.replace(/<[^>]*>/g, '').replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').trim();
}

async function searchFreeDb(exercises, nameEn) {
  const nameLower = nameEn.toLowerCase();
  let best = null;
  let bestScore = 0;
  for (const ex of exercises) {
    const exName = (ex.name || '').toLowerCase();
    if (exName === nameLower) { best = ex; bestScore = 100; break; }
    if (exName.includes(nameLower) || nameLower.includes(exName)) {
      const score = Math.max(exName.length, nameLower.length);
      if (score > bestScore) { best = ex; bestScore = score; }
    }
  }
  return best;
}

async function searchWger(nameEn) {
  try {
    const url = `${WGER_BASE}/exercise/search/?limit=5&offset=0&search=${encodeURIComponent(nameEn)}`;
    const data = await fetchJson(url);
    const suggestions = data.suggestions || [];
    if (suggestions.length === 0) return null;
    const match = suggestions[0];
    const detailUrl = `${WGER_BASE}/exerciseinfo/${match.id}/`;
    const detail = await fetchJson(detailUrl);
    const en = detail.translations?.find(t => t.language === 2) || {};
    const es = detail.translations?.find(t => t.language === 4) || {};
    const img = detail.images?.find(i => i.is_main) || detail.images?.[0] || {};
    return {
      name: en.name || '',
      nameSpanish: es.name || '',
      imageUrl: img.image || '',
      description: cleanHtml(en.description),
      descriptionSpanish: cleanHtml(es.description),
      category: 'strength',
    };
  } catch (_) {
    return null;
  }
}

async function seed() {
  console.log('Conectando a MongoDB...');
  await mongoose.connect(MONGODB_URI);
  console.log('Conectado.\n');

  console.log('Descargando catálogo de free-exercise-db...');
  let freeDbExercises = [];
  try {
    freeDbExercises = await fetchJson(FREE_DB_JSON_URL);
    console.log(`  ${freeDbExercises.length} ejercicios disponibles\n`);
  } catch (e) {
    console.log(`  No se pudo descargar: ${e.message}. Continuando sin catálogo.\n`);
  }

  let updated = 0;
  let created = 0;
  let skipped = 0;
  let failed = 0;

  for (const famous of FAMOUS_EXERCISES) {
    process.stdout.write(`Procesando "${famous.nameEs}"... `);

    let existing = await Exercise.findOne({
      $or: [
        { nameSpanish: famous.nameEs },
        { name: { $regex: `^${famous.nameEn.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, $options: 'i' } },
      ],
    });

    if (!existing) {
      const normalizedName = famous.nameEn.toLowerCase().trim();
      existing = await Exercise.findOne({
        name: { $regex: `^${normalizedName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, $options: 'i' }
      });
    }

    let imageUrl = existing?.imageUrl || existing?.gifUrl || '';
    let nameSpanish = existing?.nameSpanish || '';
    let descriptionSpanish = existing?.descriptionSpanish || '';
    let instructions = existing?.instructions || [];
    let instructionsSpanish = existing?.instructionsSpanish || [];

    if (!imageUrl && freeDbExercises.length > 0) {
      const match = await searchFreeDb(freeDbExercises, famous.nameEn);
      if (match) {
        const mainImage = Array.isArray(match.images) && match.images.length > 0 ? match.images[0] : null;
        if (mainImage) {
          imageUrl = `${FREE_DB_IMAGE_BASE}${mainImage}`;
        }
        if (!nameSpanish) nameSpanish = famous.nameEs;
        if ((!instructions || instructions.length === 0) && Array.isArray(match.instructions)) {
          instructions = match.instructions;
        }
      }
    }

    if (!imageUrl) {
      const wgerData = await searchWger(famous.nameEn);
      if (wgerData && wgerData.imageUrl) {
        imageUrl = wgerData.imageUrl;
        if (!nameSpanish) nameSpanish = wgerData.nameSpanish || famous.nameEs;
        if (!descriptionSpanish) descriptionSpanish = wgerData.descriptionSpanish || '';
      }
    }

    if (existing) {
      const updateData = {};
      if (imageUrl && !existing.imageUrl && !existing.gifUrl) {
        updateData.imageUrl = imageUrl;
      }
      if (nameSpanish && !existing.nameSpanish) updateData.nameSpanish = nameSpanish;
      if (descriptionSpanish && !existing.descriptionSpanish) {
        updateData.descriptionSpanish = descriptionSpanish;
      }
      if (!existing.category || existing.category === 'strength' && famous.category === 'cardio') {
        updateData.category = famous.category;
      }

      if (Object.keys(updateData).length > 0) {
        await Exercise.updateOne({ _id: existing._id }, { $set: updateData });
        updated++;
        console.log(`actualizado${updateData.imageUrl ? ' con imagen' : ''}`);
      } else {
        skipped++;
        console.log('ok (sin cambios necesarios)');
      }
    } else {
      const externalId = `famous_${famous.nameEn.toLowerCase().replace(/[^a-z0-9]+/g, '_')}`;
      try {
        await Exercise.create({
          externalId,
          source: 'exercisedb',
          name: famous.nameEn,
          nameSpanish: nameSpanish || famous.nameEs,
          category: famous.category,
          bodyPart: famous.muscle,
          target: '',
          equipment: '',
          gifUrl: '',
          imageUrl: imageUrl || '',
          instructions: instructions,
          instructionsSpanish: instructionsSpanish,
          description: instructions.join(' '),
          descriptionSpanish: descriptionSpanish || '',
          defaultSets: 3,
          defaultReps: '10',
          restTime: 60,
        });
        created++;
        console.log(`creado${imageUrl ? ' con imagen' : ' SIN imagen'}`);
      } catch (err) {
        failed++;
        console.log(`ERROR: ${err.message}`);
      }
    }
  }

  console.log('\n=== RESUMEN ===');
  console.log(`Total ejercicios famosos: ${FAMOUS_EXERCISES.length}`);
  console.log(`Actualizados: ${updated}`);
  console.log(`Creados: ${created}`);
  console.log(`Saltados: ${skipped}`);
  console.log(`Fallidos: ${failed}`);

  await mongoose.disconnect();
  console.log('\nDesconectado de MongoDB.');
}

seed().catch(err => {
  console.error('Error fatal:', err);
  process.exit(1);
});
