const mongoose = require('mongoose');
const https = require('https');
const dns = require('dns');
const Exercise = require('./models/Exercise');
require('dotenv').config();

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/app-pasos';
const FREE_DB_JSON_URL = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json';
const FREE_DB_IMAGE_BASE = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/';
const TRANSLATE_DELAY_MS = 250;
const BATCH_SIZE = 25;

dns.setServers(['8.8.8.8', '1.1.1.1']);

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
    })
      .on('error', reject)
      .setTimeout(60000, function () { this.destroy(); reject(new Error('Timeout')); });
  });
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

const CATEGORY_MAP = {
  strength: 'strength',
  stretching: 'strength',
  plyometrics: 'strength',
  strongman: 'strength',
  powerlifting: 'strength',
  'olympic weightlifting': 'strength',
  cardio: 'cardio',
};

function categoryFor(cat) {
  return CATEGORY_MAP[(cat || '').toLowerCase()] || 'strength';
}

async function translateWithMyMemory(text) {
  if (!text) return '';
  const safeText = String(text).slice(0, 500);
  const url = `https://api.mymemory.translated.net/get?q=${encodeURIComponent(safeText)}&langpair=en|es`;
  try {
    const data = await fetchJson(url);
    if (data?.responseStatus === 200 && data?.responseData?.translatedText) {
      return data.responseData.translatedText;
    }
    return '';
  } catch (_) {
    return '';
  }
}

async function translateBatch(texts) {
  const out = [];
  for (let i = 0; i < texts.length; i++) {
    out.push(await translateWithMyMemory(texts[i]));
    if (i < texts.length - 1) await sleep(TRANSLATE_DELAY_MS);
  }
  return out;
}

function externalIdFor(id) {
  return `freedb_${String(id).replace(/\s+/g, '_')}`;
}

async function seed() {
  console.log('Conectando a MongoDB...');
  await mongoose.connect(MONGODB_URI);
  console.log('Conectado.\n');

  console.log(`Descargando dataset de ${FREE_DB_JSON_URL}...`);
  const dataset = await fetchJson(FREE_DB_JSON_URL);
  console.log(`Dataset recibido: ${dataset.length} ejercicios\n`);

  let totalSaved = 0;
  let totalSkipped = 0;
  let totalFailed = 0;
  const failedNames = [];

  for (let i = 0; i < dataset.length; i++) {
    const ex = dataset[i];
    const externalId = externalIdFor(ex.id);

    const existing = await Exercise.findOne({ externalId });
    if (existing) {
      totalSkipped++;
      continue;
    }

    const normalizedName = (ex.name || '').toLowerCase().trim();
    const existingByName = await Exercise.findOne({
      name: { $regex: `^${normalizedName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, $options: 'i' }
    });
    if (existingByName) {
      totalSkipped++;
      continue;
    }

    try {
      const nameSpanish = await translateWithMyMemory(ex.name);
      await sleep(TRANSLATE_DELAY_MS);

      const instructions = Array.isArray(ex.instructions) ? ex.instructions : [];
      const instructionsSpanish = instructions.length > 0
        ? await translateBatch(instructions)
        : [];

      const mainImage = Array.isArray(ex.images) && ex.images.length > 0
        ? ex.images[0]
        : null;
      const imageUrl = mainImage ? `${FREE_DB_IMAGE_BASE}${mainImage}` : '';

      const primaryMuscle = Array.isArray(ex.primaryMuscles) && ex.primaryMuscles.length > 0
        ? ex.primaryMuscles.join(', ')
        : '';
      const secondaryMuscle = Array.isArray(ex.secondaryMuscles) && ex.secondaryMuscles.length > 0
        ? ex.secondaryMuscles.join(', ')
        : '';

      await Exercise.create({
        externalId,
        source: 'exercisedb',
        name: ex.name,
        nameSpanish,
        category: categoryFor(ex.category),
        bodyPart: primaryMuscle,
        target: secondaryMuscle,
        equipment: ex.equipment || '',
        gifUrl: '',
        imageUrl,
        instructions,
        instructionsSpanish,
        description: instructions.join(' '),
        descriptionSpanish: instructionsSpanish.join(' '),
        defaultSets: 3,
        defaultReps: '10',
        restTime: 60,
      });

      totalSaved++;
      if (totalSaved % BATCH_SIZE === 0) {
        console.log(`  Progreso: ${totalSaved} ejercicios guardados (${i + 1}/${dataset.length})`);
      }
    } catch (err) {
      totalFailed++;
      failedNames.push(ex.name);
      console.error(`  ❌ Error guardando "${ex.name}": ${err.message}`);
    }
  }

  console.log('\n=== Resumen ===');
  console.log(`Total en dataset: ${dataset.length}`);
  console.log(`Guardados: ${totalSaved}`);
  console.log(`Saltados (ya existían): ${totalSkipped}`);
  console.log(`Fallidos: ${totalFailed}`);
  if (failedNames.length > 0) {
    console.log(`Primeros fallos: ${failedNames.slice(0, 5).join(', ')}`);
  }

  await mongoose.disconnect();
  console.log('\nDesconectado de MongoDB.');
}

seed().catch(err => {
  console.error('Error fatal:', err);
  process.exit(1);
});
