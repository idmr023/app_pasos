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
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const DEEPL_API_KEY = process.env.DEEPL_API_KEY;

function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { 'User-Agent': 'AppPasos/1.0 (seed-enhance)', 'Accept': 'application/json' }, timeout: 20000 }, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          res.destroy();
          return resolve(fetchJson(new URL(res.headers.location, url).href));
        }
        if (res.statusCode === 200) return resolve(JSON.parse(data));
        reject(new Error(`HTTP ${res.statusCode}`));
      });
    }).on('error', reject).setTimeout(20000, function () { this.destroy(); reject(new Error('Timeout')); });
  });
}

function fetchBuffer(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { 'User-Agent': 'AppPasos/1.0 (seed-enhance)' }, timeout: 15000 }, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        res.destroy();
        return resolve(fetchBuffer(new URL(res.headers.location, url).href));
      }
      if (res.statusCode === 429) {
        res.destroy();
        return reject(new Error('HTTP 429'));
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

const IMAGE_HOST_ALLOWLIST = [
  'raw.githubusercontent.com/yuhonas/free-exercise-db',
  'wger.de',
  'commons.wikimedia.org',
  'musclewiki.com',
  'fitnessprogramer.com',
  'gymvisual.com',
  'workoutlabs.com',
  'verywellfit.com',
  'healthline.com',
  'fitlife.video',
  'istockphoto.com',
  'shutterstock.com',
  'gettyimages.com',
  'dreamstime.com',
  'depositphotos.com',
  '123rf.com',
  'freepik.com',
  'vecteezy.com',
  'publicdomainvectors.org',
  'openclipart.org',
  'svgrepo.com',
];

function isAllowedHost(url) {
  try {
    const u = new URL(url);
    return IMAGE_HOST_ALLOWLIST.some(h => u.hostname === h || u.hostname.endsWith('.' + h));
  } catch (_) { return false; }
}

async function geminiGenerate(prompt, temperature = 0.1, maxTokens = 200) {
  if (!GEMINI_API_KEY) return null;
  return new Promise((resolve) => {
    const body = JSON.stringify({
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: { temperature, maxOutputTokens: maxTokens },
    });
    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY}`;
    const req = https.request(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) },
      timeout: 20000,
    }, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        if (res.statusCode !== 200) return resolve(null);
        try {
          const json = JSON.parse(data);
          const text = json.candidates?.[0]?.content?.parts?.[0]?.text;
          resolve(text ? text.trim() : null);
        } catch (_) { resolve(null); }
      });
    });
    req.on('error', () => resolve(null));
    req.setTimeout(20000, function () { this.destroy(); resolve(null); });
    req.write(body);
    req.end();
  });
}

function svgPlaceholder(name, nameSpanish) {
  const label = nameSpanish || name || 'Ejercicio';
  const safe = label.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="400" height="300" viewBox="0 0 400 300">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#1a1a2e"/>
      <stop offset="100%" style="stop-color:#16213e"/>
    </linearGradient>
  </defs>
  <rect width="400" height="300" fill="url(#bg)" rx="16"/>
  <circle cx="200" cy="100" r="40" fill="none" stroke="#e94560" stroke-width="3" opacity="0.5"/>
  <path d="M180 90 L200 110 M200 90 L180 110" stroke="#e94560" stroke-width="3" opacity="0.5"/>
  <text x="200" y="180" text-anchor="middle" fill="#e94560" font-family="Arial,sans-serif" font-size="22" font-weight="bold">${safe}</text>
  <text x="200" y="210" text-anchor="middle" fill="#666" font-family="Arial,sans-serif" font-size="14">Ejercicio de entrenamiento</text>
</svg>`;
  return Buffer.from(svg, 'utf8');
}

async function findImageWithGemini(ex) {
  if (!GEMINI_API_KEY) return null;
  const queries = [
    `Give me a public URL (jpg or png) of a photo for the exercise "${ex.name}" workout gym. Return ONLY the direct image URL, nothing else.`,
    ex.nameSpanish ? `Give me a public URL of a photo for "${ex.nameSpanish}" ejercicio. Return ONLY the URL.` : null,
  ].filter(Boolean);

  for (const q of queries) {
    const text = await geminiGenerate(q, 0.1, 200);
    if (text) {
      let url = text.replace(/```\w*\n?/g, '').replace(/```/g, '').trim();
      if (url.startsWith('http') && isAllowedHost(url)) {
        return url;
      }
    }
    await sleep(300);
  }
  return null;
}

async function findImageFromWikimedia(ex) {
  const names = [ex.name, ex.nameSpanish].filter(Boolean);
  for (const name of names) {
    if (!name) continue;
    try {
      const query = encodeURIComponent(`${name} exercise`);
      const data = await fetchJson(
        `https://commons.wikimedia.org/w/api.php?action=query&list=search&srsearch=${query}&format=json&srlimit=5&srnamespace=6`
      );
      const results = data?.query?.search || [];
      for (const r of results) {
        const title = r.title;
        const ext = title.split('.').pop()?.toLowerCase();
        if (['webm', 'svg', 'ogg', 'ogv'].includes(ext)) continue;
        const info = await fetchJson(
          `https://commons.wikimedia.org/w/api.php?action=query&titles=${encodeURIComponent(title)}&prop=imageinfo&iiprop=url&format=json`
        );
        const pages = info?.query?.pages || {};
        const page = Object.values(pages)[0];
        if (page?.imageinfo?.[0]?.url) {
          return page.imageinfo[0].url;
        }
      }
    } catch (_) {}
    await sleep(300);
  }
  return null;
}

function detectMime(url) {
  const u = url.toLowerCase();
  if (u.endsWith('.png')) return 'image/png';
  if (u.endsWith('.gif') || u.endsWith('.gifv')) return 'image/gif';
  if (u.endsWith('.webp')) return 'image/webp';
  if (u.endsWith('.svg')) return 'image/svg+xml';
  return 'image/jpeg';
}

async function translateWithDeepL(text) {
  if (!DEEPL_API_KEY || !text) return '';
  return new Promise((resolve) => {
    const safeText = String(text).slice(0, 500);
    const body = JSON.stringify({ text: [safeText], source_lang: 'EN', target_lang: 'ES' });
    const req = https.request('https://api-free.deepl.com/v2/translate', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
        'Authorization': `DeepL-Auth-Key ${DEEPL_API_KEY}`,
      },
      timeout: 15000,
    }, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        if (res.statusCode !== 200) return resolve('');
        try {
          const j = JSON.parse(data);
          resolve(j.translations?.[0]?.text || '');
        } catch (_) { resolve(''); }
      });
    });
    req.on('error', () => resolve(''));
    req.setTimeout(15000, function () { this.destroy(); resolve(''); });
    req.write(body);
    req.end();
  });
}

async function translateText(text) {
  if (!text) return '';
  const safeText = String(text).slice(0, 500);

  // DeepL (tienes key)
  const deepl = await translateWithDeepL(safeText);
  if (deepl) return deepl;

  // Fallback: return original
  return '';
}

async function translateBatch(texts, delayMs = 400) {
  const out = [];
  for (let i = 0; i < texts.length; i++) {
    const t = await translateText(texts[i]);
    out.push(t || texts[i]); // fallback to original
    if (i < texts.length - 1) await sleep(delayMs);
  }
  return out;
}

async function findImageFromFreeDb(freeDbList, freeDbMap, ex) {
  if (freeDbList.length === 0) return null;

  const prefix = 'freedb_';

  if (ex.externalId && ex.externalId.startsWith(prefix)) {
    const fdbId = ex.externalId.slice(prefix.length);
    const match = freeDbMap[fdbId];
    if (match && Array.isArray(match.images) && match.images.length > 0) {
      return `${FREE_DB_IMAGE_BASE}${match.images[0]}`;
    }
  }

  const names = [ex.name, ex.nameSpanish].filter(Boolean);
  for (const name of names) {
    if (!name) continue;
    const lower = name.toLowerCase().trim();
    for (const fdb of freeDbList) {
      const fdbName = (fdb.name || '').toLowerCase();
      if (fdbName === lower || fdbName.includes(lower) || lower.includes(fdbName)) {
        if (Array.isArray(fdb.images) && fdb.images.length > 0) {
          return `${FREE_DB_IMAGE_BASE}${fdb.images[0]}`;
        }
      }
    }
  }

  return null;
}

async function findImageFromWger(ex) {
  const names = [ex.name, ex.nameSpanish].filter(Boolean);
  for (const name of names) {
    if (!name || name.length < 2) continue;
    try {
      const data = await fetchJson(`${WGER_BASE}/exercise/search/?limit=3&offset=0&search=${encodeURIComponent(name)}`);
      const suggestions = data.suggestions || [];
      if (suggestions.length === 0) continue;
      const detail = await fetchJson(`${WGER_BASE}/exerciseinfo/${suggestions[0].id}/`);
      const img = detail.images?.find(i => i.is_main) || detail.images?.[0] || {};
      if (img.image) return img.image;
    } catch (_) { }
  }
  return null;
}

async function processImages() {
  console.log('\n=== PASO 1: DESCARGAR IMÁGENES FALTANTES ===\n');

  const sinImagen = await Exercise.countDocuments({
    gifUrl: { $in: ['', null] },
    $or: [
      { imageUrl: { $in: ['', null] } },
      { imageUrl: { $not: /wikimedia\.org/ } },
    ],
    $or: [
      { localImage: null },
      { localImage: { $exists: false } },
      { localImageMime: 'image/svg+xml' },
    ],
  });

  if (sinImagen === 0) {
    console.log('Todos los ejercicios ya tienen imagen real. Saltando.\n');
    return;
  }

  console.log(`Ejercicios sin imagen real: ${sinImagen}`);

  console.log('Descargando catálogo free-exercise-db...');
  let freeDbList = [];
  try {
    freeDbList = await fetchJson(FREE_DB_JSON_URL);
    console.log(`  ${freeDbList.length} ejercicios disponibles`);
  } catch (e) {
    console.log(`  No disponible: ${e.message}`);
  }

  const freeDbMap = {};
  for (const fdb of freeDbList) {
    if (fdb.id) freeDbMap[fdb.id] = fdb;
  }

  const exercises = await Exercise.find({
    gifUrl: { $in: ['', null] },
    imageUrl: { $in: ['', null] },
    $or: [
      { localImage: null },
      { localImage: { $exists: false } },
      { localImageMime: 'image/svg+xml' },
    ],
  }).limit(200).lean();

  console.log(`Procesando ${exercises.length} ejercicios...\n`);

  let downloaded = 0;
  let skipped = 0;
  let geminiUsed = 0;

  for (let i = 0; i < exercises.length; i++) {
    const ex = exercises[i];
    const name = ex.nameSpanish || ex.name;
    process.stdout.write(`[${i + 1}/${exercises.length}] ${name}... `);

    let imgUrl = null;

    imgUrl = await findImageFromFreeDb(freeDbList, freeDbMap, ex);
    if (imgUrl) { process.stdout.write('free-db → '); }

    if (!imgUrl && ex.externalId) {
      const shortId = ex.externalId.length > 40 ? ex.externalId.slice(0, 40) + '...' : ex.externalId;
      process.stdout.write(`(extId: ${shortId}) `);
    }

    if (!imgUrl) {
      imgUrl = await findImageFromWger(ex);
      if (imgUrl) { process.stdout.write('wger → '); }
    }

    if (!imgUrl) {
      await sleep(300);
      imgUrl = await findImageFromWikimedia(ex);
      if (imgUrl) { process.stdout.write('wikimedia → '); geminiUsed++; }
    }

    if (!imgUrl && GEMINI_API_KEY) {
      imgUrl = await findImageWithGemini(ex);
      if (imgUrl) { process.stdout.write('gemini → '); geminiUsed++; }
    }

    if (imgUrl) {
      if (imgUrl.includes('wikimedia.org') || imgUrl.includes('upload.wikimedia')) {
        await Exercise.updateOne(
          { _id: ex._id },
          { $set: { imageUrl: imgUrl, gifUrl: '' } }
        );
        downloaded++;
        console.log(`✓ URL directa`);
      } else {
        try {
          const buf = await fetchBuffer(imgUrl);
          if (buf && buf.length > 100) {
            const mime = detectMime(imgUrl);
            await Exercise.updateOne(
              { _id: ex._id },
              { $set: { localImage: buf, localImageMime: mime } }
            );
            downloaded++;
            console.log(`✓ ${(buf.length / 1024).toFixed(0)} KB`);
          } else {
            skipped++;
            console.log('✗ vacío');
          }
        } catch (err) {
          const svgBuf = svgPlaceholder(ex.name, ex.nameSpanish);
          const imgId = ex.externalId || String(ex._id);
          await Exercise.updateOne(
            { _id: ex._id },
            { $set: { localImage: svgBuf, localImageMime: 'image/svg+xml', imageUrl: `/api/gym/exercise-image/${imgId}` } }
          );
          downloaded++;
          console.log(`✗ ${err.message.slice(0, 30)} → SVG placeholder`);
        }
      }
    } else {
      const svgBuf = svgPlaceholder(ex.name, ex.nameSpanish);
      const imgId = ex.externalId || String(ex._id);
      await Exercise.updateOne(
        { _id: ex._id },
        { $set: { localImage: svgBuf, localImageMime: 'image/svg+xml', imageUrl: `/api/gym/exercise-image/${imgId}` } }
      );
      downloaded++;
      console.log('✓ SVG placeholder');
    }

    if (i % 5 === 4) await sleep(200);
  }

  console.log(`\nImágenes descargadas: ${downloaded}`);
  console.log(`Búsquedas Gemini usadas: ${geminiUsed}`);
  console.log(`Saltados: ${skipped}`);
}

async function processDescriptions() {
  console.log('\n=== PASO 2: TRADUCIR DESCRIPCIONES AL ESPAÑOL ===\n');

  const soloIngles = await Exercise.countDocuments({
    descriptionSpanish: { $in: ['', null] },
    description: { $ne: '', $exists: true },
  });

  console.log(`Ejercicios con descripción solo en inglés: ${soloIngles}`);

  if (soloIngles === 0) {
    console.log('Todos ya tienen descripción en español. Saltando.\n');
    return;
  }

  const exercises = await Exercise.find({
    descriptionSpanish: { $in: ['', null] },
    description: { $ne: '', $exists: true },
  }).limit(200).lean();

  console.log(`Traduciendo ${exercises.length} descripciones con MyMemory...\n`);

  let translated = 0;
  let failed = 0;
  let skippedDesc = 0;

  for (let i = 0; i < exercises.length; i++) {
    const ex = exercises[i];
    const name = ex.nameSpanish || ex.name;
    const desc = ex.description || '';
    process.stdout.write(`[${i + 1}/${exercises.length}] ${name}... `);

    if (!desc || desc.length < 5) {
      skippedDesc++;
      console.log('✗ sin descripción origen');
      continue;
    }

    const translatedText = await translateText(desc);
    const instructions = ex.instructions || [];
    let instructionsSpanish = ex.instructionsSpanish || [];

    if (instructions.length > 0 && (!instructionsSpanish || instructionsSpanish.length === 0)) {
      instructionsSpanish = await translateBatch(instructions);
    }

    await Exercise.updateOne(
      { _id: ex._id },
      {
        $set: {
          descriptionSpanish: (translatedText && translatedText.length > 10) ? translatedText : desc.slice(0, 500),
          ...(instructionsSpanish.length > 0 ? { instructionsSpanish } : {}),
        },
      }
    );
    if (translatedText && translatedText.length > 10) {
      translated++; console.log('✓');
    } else {
      translated++; console.log('✓ (inglés como fallback)');
    }

    if (i % 5 === 4) await sleep(100);
  }

  console.log(`\nDescripciones traducidas: ${translated}`);
  console.log(`Fallidas: ${failed}`);
}

async function seed() {
  console.log('=== VERIFICANDO CONFIGURACIÓN ===');
  console.log(`GEMINI_API_KEY: ${GEMINI_API_KEY ? `✓ configurada (${GEMINI_API_KEY.slice(0, 8)}...)` : '✗ NO configurada'}`);
  console.log('');

  console.log('Conectando a MongoDB...');
  await mongoose.connect(MONGODB_URI);
  console.log('Conectado.\n');

  await processImages();
  await processDescriptions();

  console.log('\n=== COMPLETADO ===');

  const totalSinImagen = await Exercise.countDocuments({
    gifUrl: { $in: ['', null] },
    imageUrl: { $in: ['', null] },
    $or: [{ localImage: null }, { localImage: { $exists: false } }],
  });
  const totalSinDesc = await Exercise.countDocuments({
    $or: [{ descriptionSpanish: { $in: ['', null] } }, { descriptionSpanish: { $exists: false } }],
    description: { $ne: '', $exists: true },
  });

  console.log(`Pendientes sin imagen: ${totalSinImagen}`);
  console.log(`Pendientes sin descripción español: ${totalSinDesc}`);

  await mongoose.disconnect();
  console.log('Desconectado de MongoDB.');
}

seed().catch(err => {
  console.error('Error fatal:', err);
  process.exit(1);
});
