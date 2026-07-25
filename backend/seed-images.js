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

function fetchBuffer(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { 'User-Agent': 'Mozilla/5.0' }, timeout: 15000 }, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        res.destroy();
        return resolve(fetchBuffer(new URL(res.headers.location, url).href));
      }
      if (res.statusCode !== 200) {
        res.destroy();
        return reject(new Error(`HTTP ${res.statusCode}`));
      }
      const chunks = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => resolve(Buffer.concat(chunks)));
    }).on('error', reject).setTimeout(15000, function () { this.destroy(); reject(new Error('Timeout')); });
  });
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function searchFreeDb(freeDbExercises, ex) {
  const names = [ex.name, ex.nameSpanish].filter(Boolean);
  for (const name of names) {
    if (!name) continue;
    const lower = name.toLowerCase().trim();
    for (const fdb of freeDbExercises) {
      const fdbName = (fdb.name || '').toLowerCase();
      if (fdbName === lower) return fdb;
    }
    for (const fdb of freeDbExercises) {
      const fdbName = (fdb.name || '').toLowerCase();
      if (fdbName.includes(lower) || lower.includes(fdbName)) return fdb;
    }
  }
  return null;
}

async function searchWger(ex) {
  const names = [ex.name, ex.nameSpanish].filter(Boolean);
  for (const name of names) {
    if (!name || name.length < 2) continue;
    try {
      const url = `${WGER_BASE}/exercise/search/?limit=3&offset=0&search=${encodeURIComponent(name)}`;
      const data = await fetchJson(url);
      const suggestions = data.suggestions || [];
      if (suggestions.length === 0) continue;
      const detail = await fetchJson(`${WGER_BASE}/exerciseinfo/${suggestions[0].id}/`);
      const img = detail.images?.find(i => i.is_main) || detail.images?.[0] || {};
      if (img.image) return img.image;
    } catch (_) { }
  }
  return null;
}

async function seed() {
  console.log('Conectando a MongoDB...');
  await mongoose.connect(MONGODB_URI);
  console.log('Conectado.\n');

  const totalSinImagen = await Exercise.countDocuments({
    gifUrl: { $in: ['', null] },
    imageUrl: { $in: ['', null] },
    localImage: null,
  });

  console.log(`Ejercicios sin imagen externa ni local: ${totalSinImagen}\n`);

  if (totalSinImagen === 0) {
    console.log('Todos los ejercicios ya tienen imagen. Saliendo.');
    await mongoose.disconnect();
    return;
  }

  console.log('Descargando catálogo free-exercise-db...');
  let freeDbExercises = [];
  try {
    freeDbExercises = await fetchJson(FREE_DB_JSON_URL);
    console.log(`  ${freeDbExercises.length} ejercicios disponibles\n`);
  } catch (e) {
    console.log(`  No se pudo descargar: ${e.message}. Continuando sin catálogo.\n`);
  }

  const exercises = await Exercise.find({
    gifUrl: { $in: ['', null] },
    imageUrl: { $in: ['', null] },
    localImage: null,
  }).limit(200).lean();

  console.log(`Procesando ${exercises.length} ejercicios...\n`);

  let downloaded = 0;
  let skipped = 0;
  let failed = 0;

  for (let i = 0; i < exercises.length; i++) {
    const ex = exercises[i];
    process.stdout.write(`[${i + 1}/${exercises.length}] ${ex.nameSpanish || ex.name}... `);

    let imgUrl = null;

    if (freeDbExercises.length > 0) {
      const match = await searchFreeDb(freeDbExercises, ex);
      if (match) {
        const mainImage = Array.isArray(match.images) && match.images.length > 0 ? match.images[0] : null;
        if (mainImage) {
          imgUrl = `${FREE_DB_IMAGE_BASE}${mainImage}`;
        }
      }
    }

    if (!imgUrl) {
      imgUrl = await searchWger(ex);
    }

    if (imgUrl) {
      try {
        const buf = await fetchBuffer(imgUrl);
        if (buf && buf.length > 100) {
          const mime = imgUrl.endsWith('.png') ? 'image/png' :
            imgUrl.endsWith('.gif') || imgUrl.endsWith('.gifv') ? 'image/gif' :
            imgUrl.endsWith('.webp') ? 'image/webp' : 'image/jpeg';
          await Exercise.updateOne(
            { _id: ex._id },
            { $set: { localImage: buf, localImageMime: mime } }
          );
          downloaded++;
          console.log(`✓ (${(buf.length / 1024).toFixed(0)} KB)`);
        } else {
          skipped++;
          console.log('✗ archivo vacío');
        }
      } catch (err) {
        failed++;
        console.log(`✗ error descarga: ${err.message}`);
      }
    } else {
      skipped++;
      console.log('✗ sin fuente disponible');
    }

    if (i % 5 === 4) await sleep(500);
  }

  console.log('\n=== RESUMEN ===');
  console.log(`Procesados: ${exercises.length}`);
  console.log(`Descargados: ${downloaded}`);
  console.log(`Saltados (sin fuente): ${skipped}`);
  console.log(`Fallidos: ${failed}`);

  await mongoose.disconnect();
  console.log('\nDesconectado de MongoDB.');
}

seed().catch(err => {
  console.error('Error fatal:', err);
  process.exit(1);
});
