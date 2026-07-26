const mongoose = require('mongoose');
const https = require('https');
const dns = require('dns');
const Exercise = require('../models/Exercise');
require('dotenv').config();

dns.setServers(['8.8.8.8', '1.1.1.1']);

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/app-pasos';
const FREE_DB_JSON_URL = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json';
const FREE_DB_IMAGE_BASE = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/';
const WGER_BASE = 'https://wger.de/api/v2';
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;

function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { 'User-Agent': 'AppPasos/1.0', 'Accept': 'application/json' }, timeout: 20000 }, (res) => {
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
    https.get(url, { headers: { 'User-Agent': 'AppPasos/1.0' }, timeout: 15000 }, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        res.destroy();
        return resolve(fetchBuffer(new URL(res.headers.location, url).href));
      }
      if (res.statusCode !== 200) { res.destroy(); return reject(new Error(`HTTP ${res.statusCode}`)); }
      const chunks = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => resolve(Buffer.concat(chunks)));
    }).on('error', reject).setTimeout(15000, function () { this.destroy(); reject(new Error('Timeout')); });
  });
}

function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }

async function translateToEnglish(text) {
  if (!text) return '';
  try {
    const url = `https://api.mymemory.translated.net/get?q=${encodeURIComponent(text)}&langpair=es|en`;
    const data = await fetchJson(url);
    if (data?.responseStatus === 200 && data?.responseData?.translatedText) {
      return data.responseData.translatedText;
    }
  } catch (_) {}
  return '';
}

const NAME_MAP = {
  'flexiones de brazos': 'push up',
  'sentadillas': 'squat',
  'plancha': 'plank',
  'montañista': 'mountain climber',
  'saltos de sentadilla': 'jump squat',
  'estiramiento de isquiotibiales': 'hamstring stretch',
  'estiramiento de cuádriceps': 'quadriceps stretch',
  'plancha asimétrica': 'plank',
  'plancha normal': 'plank',
  'farmer walk': 'farmer walk',
  'círculos de cadera': 'hip circles',
  'rotación de tobillos': 'ankle circles',
  'rotación de muñecas': 'wrist circles',
  'extensiones de tríceps': 'triceps extension',
  'peso muerto rumano': 'romanian deadlift',
  'remo en barra': 'barbell row',
  'press inclinado con mancuerna': 'incline dumbbell press',
  'fondos en paralelas': 'dip',
  'prensa de piernas': 'leg press',
  'remo invertido': 'inverted row',
  'saltos de estrella': 'star jump',
  'bicicleta en el aire': 'air bike',
  'estiramiento de cadera en 90/90': 'hip stretch',
  'estiramiento de psoas': 'psoas stretch',
  'estiramiento de gemelos': 'calf stretch',
  'postura del niño': 'childs pose',
  'estiramiento de tríceps': 'triceps stretch',
  'flexión lateral de torso': 'side bend',
  'estiramiento de abductores': 'adductor stretch',
  'estiramiento de glúteos': 'glute stretch',
  'rotación de columna supina': 'supine spinal twist',
  'dominada cerrada para bíceps': 'close grip chin up',
  'dominada para bíceps': 'chin up',
  'press de hombros alterno en polea': 'cable shoulder press',
  'extensión de tríceps alterna en polea': 'cable tricep extension',
  'jalón lateral con barra en polea': 'cable lateral raise',
  'jalón cruzado lateral en polea': 'cable crossover',
  'variación de crossover en polea': 'cable crossover',
  'aperturas declinadas en polea': 'cable fly',
  'remo declinado sentado agarre ancho en polea': 'seated cable row',
  'remo sentado en el suelo agarre ancho en polea': 'seated cable row',
  'elevación frontal en polea': 'cable front raise',
  'curl martillo en polea (con cuerda)': 'cable hammer curl',
  'remo alto de rodillas en polea': 'cable row',
  'press de banca inclinado en polea': 'cable chest press',
  'aperturas inclinadas en polea (sobre pelota de estabilidad)': 'cable fly',
  'aperturas inclinadas en polea': 'cable fly',
  'crunch de rodillas en polea': 'cable crunch',
  'extensión de tríceps de rodillas en polea': 'cable tricep extension',
  'jalón lateral en polea (con cuerda)': 'cable lateral raise',
  'pull through en polea (con cuerda)': 'cable pull through',
  'pushdown en polea (con cuerda)': 'tricep pushdown',
  'pushdown en polea': 'tricep pushdown',
  'remo para deltoides posterior en polea (estribos)': 'cable rear delt row',
  'remo para deltoides posterior en polea (con cuerda)': 'cable rear delt row',
  'tirón hacia atrás en polea': 'cable row',
  'pushdown agarre invertido en polea': 'reverse grip tricep pushdown',
  'remo alto sentado espalda recta agarre invertido (polea)': 'seated cable row',
  'curl inverso en banco scott en polea': 'cable curl',
  'crunch de inclinación lateral en polea (bosu ball)': 'cable side crunch',
  'crunch lateral en polea': 'cable side crunch',
  'curl de muñeca dorsal de pie en polea': 'cable wrist curl',
  'reverse fly cruzado alto de pie en polea': 'cable rear delt fly',
  'crunch de pie en polea': 'cable crunch',
  'aperturas de pie en polea': 'cable fly',
  'extensión de cadera de pie en polea': 'cable hip extension',
  'curl interno de pie en polea': 'cable curl',
  'elevación de pie en polea': 'cable leg raise',
  'extensión de tríceps a un brazo de pie en polea': 'single arm cable tricep extension',
  'jalón de brazos rectos en polea (con cuerda)': 'straight arm pulldown',
  'jalón de brazos rectos en polea': 'straight arm pulldown',
  'remo sentado espalda recta en polea': 'seated cable row',
  'reverse fly en supino en polea': 'cable rear delt fly',
  'giro de torso en polea (cable twist)': 'cable twist',
  'tirón con giro en polea': 'cable twist',
  'rotación interna de hombro sentado en polea': 'cable internal rotation',
  'remo sentado agarre ancho en polea': 'seated cable row',
  'encogimiento de hombros en polea (shrug)': 'cable shrug',
  'curl de bíceps alterno con barra': 'barbell curl',
  'sentadilla frontal en banco con barra': 'front squat',
  'sentadilla con barra': 'barbell squat',
  'remo con barra inclinado': 'barbell row',
  'press de banca con agarre cerrado': 'close grip bench press',
  'press de banca declinado con barra': 'decline barbell bench press',
  'pullover declinado con brazos flexionados (barra)': 'barbell pullover',
  'press francés declinado con agarre cerrado (barra)': 'skullcrusher',
  'press declinado con agarre ancho (barra)': 'decline bench press',
  'pullover declinado agarre ancho con barra': 'barbell pullover',
  'sentadilla frontal con barra': 'front squat',
  'elevación frontal con barra': 'front raise',
  'press inclinado agarre invertido con barra': 'incline bench press',
  'remo inclinado con barra': 'barbell row',
  'sentadilla jefferson con barra': 'jefferson squat',
  'press de banca jm con barra': 'jm press',
  'sentadilla con salto y barra': 'jump squat',
  'press tumbado agarre cerrado con barra': 'close grip bench press',
  'extensión de tríceps tumbado agarre cerrado con barra': 'skullcrusher',
  'extensión tumbado con barra': 'skullcrusher',
  'elevación de cadera tumbado con barra': 'glute bridge',
  'sentadilla con base estrecha y barra': 'narrow squat',
  'remo inclinado a un brazo con barra': 'one arm barbell row',
  'peso muerto lateral a un brazo con barra': 'one arm barbell row',
  'sentadilla a una pierna con barra': 'pistol squat',
  'curl en banco inclinado boca abajo con barra': 'prone incline curl',
  'zancada hacia atrás con barra': 'barbell lunge',
  'zancada hacia atrás con barra v.2': 'barbell lunge',
  'curl de muñeca inverso con barra': 'reverse wrist curl',
  'curl inverso con barra': 'reverse barbell curl',
  'curl de muñeca inverso con barra v.2': 'reverse wrist curl',
  'curl de muñeca con barra': 'wrist curl',
  'curl de muñeca con barra v.2': 'wrist curl',
  'curl inverso en banco scott con barra': 'preacher curl',
  'curl de pie agarre cerrado con barra': 'standing barbell curl',
  'elevación frontal de pie por encima de la cabeza con barra': 'front raise',
  'elevación de talones de pie con barra': 'calf raise',
  'extensión de tríceps por encima de la cabeza de pie con barra': 'overhead tricep extension',
  'curl con agarre invertido de pie con barra': 'reverse barbell curl',
  'elevación de talones de pie balanceando con barra': 'calf raise',
  'giro de pie con barra': 'barbell twist',
  'curl de pie agarre ancho con barra': 'wide grip barbell curl',
  'peso muerto con piernas rectas y barra': 'stiff leg deadlift',
  'curl de bíceps en banco scott con barra': 'preacher curl',
  'sentadilla frontal al pecho con barra': 'front squat',
  'press de hombros sentado detrás de la cabeza con barra': 'behind neck press',
  'press bradford sentado con barra': 'bradford press',
  'curl de concentración sentado con agarre cerrado y barra': 'concentration curl',
  'sentadilla split lateral con barra v.2': 'split squat',
  'sentadilla de rodillas con barra': 'kneeling squat',
  'rollout abdominal de pie con barra': 'barbell rollout',
  'curl de muñeca dorsal de pie con barra': 'wrist curl',
  'press bradford de pie con barra': 'bradford press',
  'extensión de tríceps por encima de la cabeza sentado con barra': 'overhead tricep extension',
  'giro sentado con barra': 'seated barbell twist',
  'inclinación lateral con barra v.2': 'side bend',
  'remo al mentón con barra': 'barbell upright row',
  'remo al mentón con barra v.2': 'barbell upright row',
  'remo al mentón con barra v.3': 'barbell upright row',
  'press de banca agarre ancho con barra': 'wide grip bench press',
  'remo al mentón agarre ancho con barra': 'wide grip upright row',
  'sentadilla ancha con barra': 'wide squat',
  'sentadilla zercher con barra': 'zercher squat',
  'rollout desde el banco con barra': 'barbell rollout',
  'rollout con barra': 'barbell rollout',
  'peso muerto con piernas rectas y barra': 'stiff leg deadlift',
  'giro ruso asistido con balón medicinal': 'russian twist',
  'remo inclinado agarre invertido con barra': 'barbell row',
  'press de banca con barra': 'barbell bench press',
  'good morning con piernas rígidas (barra)': 'good morning',
  'peso muerto sumo con barra': 'sumo deadlift',
  'step-up con barra': 'barbell step up',
  'extensión de tríceps tumbado con barra': 'skullcrusher',
  'press francés tumbado con barra (skull crusher)': 'skullcrusher',
  'sentadilla split lateral con barra v.2': 'split squat',
  'curl en banco scott con barra': 'preacher curl',
  'fondos en banco (rodillas flexionadas)': 'bench dip',
  'extensión de cadera en banco': 'hip extension',
  'bottoms-up': 'bottoms up',
  'pull through en polea (con cuerda)': 'cable pull through',
  'pushdown brazo recto en polea v.2': 'tricep pushdown',
  'remo alto sentado en polea (barra en v)': 'seated cable row',
  'remo sentado alterno a un brazo en polea': 'single arm cable row',
  'elevación lateral posterior sentado en polea': 'cable lateral raise',
  'fondos de tríceps asistidos (de rodillas)': 'tricep dip',
  'femoral en prono asistido': 'leg curl',
  'elevación de piernas tumbado asistida con lanzamiento': 'leg raise',
  'dominada asistida con agarre cerrado paralelo': 'assisted chin up',
  'extensión de tríceps de pie asistida (con toalla)': 'tricep extension',
  'curl de bíceps alterno con barra': 'barbell curl',
  'pullover a press con barra': 'pullover',
  'jalón en polea (barra lat pro)': 'lat pulldown',
  'aperturas medias en polea': 'cable fly',
  'remo inclinado a un brazo en polea': 'single arm cable row',
  'curl a un brazo en polea': 'single arm cable curl',
  'inclinación lateral a un brazo en polea': 'cable side bend',
  'elevación lateral a un brazo en polea': 'cable lateral raise',
  'remo alto a un brazo espalda recta de rodillas (polea)': 'single arm cable row',
  'jalón en polea': 'lat pulldown',
  'remo alto sentado en polea (barra en v)': 'seated cable row',
  'curl inverso en polea': 'cable reverse curl',
  'elevación lateral en polea': 'cable lateral raise',
  'aperturas bajas en polea': 'low cable fly',
  'remo bajo sentado en polea': 'seated cable row',
  'curl cerrado tumbado en polea': 'cable curl',
  'aperturas tumbado en polea': 'cable fly',
  'extensión de tríceps tumbado en polea v.2': 'cable tricep extension',
  'extensión de tríceps en polea (barra en v)': 'cable tricep extension',
  'crunch inverso encogido en polea': 'reverse crunch',
  'remo alto sentado espalda recta agarre invertido (polea)': 'seated cable row',
  'curl inverso en banco scott en polea': 'cable curl',
  'curl de muñeca inverso en polea': 'cable wrist curl',
  'giro ruso en polea (sobre pelota de estabilidad)': 'russian twist',
  'jalón posterior en polea': 'lat pulldown',
  'rotación externa de hombro de pie en polea': 'cable external rotation',
  'remo de pie con giro en polea (barra en v)': 'cable row',
  'jalón de pie en polea (con cuerda)': 'straight arm pulldown',
  'remo de pie para deltoides posterior en polea (con cuerda)': 'cable rear delt row',
  'remo de pie en polea (barra en v)': 'cable row',
  'extensión de tríceps por encima de la cabeza en polea (cuerda)': 'overhead cable tricep extension',
  'pull through en polea (con cuerda)': 'cable pull through',
  'inclinación lateral en polea': 'cable side bend',
  'remo para deltoides posterior en polea (estribos)': 'cable rear delt row',
  'encogimiento de hombros en polea (shrug)': 'cable shrug',
};

async function findImageFromFreeDb(freeDbList, freeDbMap, nameEn) {
  if (!nameEn || freeDbList.length === 0) return null;
  const lower = nameEn.toLowerCase().trim();
  
  for (const fdb of freeDbList) {
    const fdbName = (fdb.name || '').toLowerCase();
    if (fdbName === lower) {
      if (Array.isArray(fdb.images) && fdb.images.length > 0) {
        return `${FREE_DB_IMAGE_BASE}${fdb.images[0]}`;
      }
    }
  }
  
  for (const fdb of freeDbList) {
    const fdbName = (fdb.name || '').toLowerCase();
    if (fdbName.includes(lower) || lower.includes(fdbName)) {
      if (Array.isArray(fdb.images) && fdb.images.length > 0) {
        return `${FREE_DB_IMAGE_BASE}${fdb.images[0]}`;
      }
    }
  }
  
  return null;
}

async function findImageFromWger(nameEn) {
  if (!nameEn || nameEn.length < 2) return null;
  try {
    const data = await fetchJson(`${WGER_BASE}/exercise/search/?limit=3&offset=0&search=${encodeURIComponent(nameEn)}`);
    const suggestions = data.suggestions || [];
    if (suggestions.length === 0) return null;
    const detail = await fetchJson(`${WGER_BASE}/exerciseinfo/${suggestions[0].id}/`);
    const img = detail.images?.find(i => i.is_main) || detail.images?.[0] || {};
    if (img.image) return img.image;
  } catch (_) {}
  return null;
}

async function findImageFromWikimedia(nameEn, nameEs) {
  const names = [nameEn, nameEs].filter(Boolean);
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
    await sleep(200);
  }
  return null;
}

async function findImageWithGemini(nameEn, nameEs) {
  if (!GEMINI_API_KEY) return null;
  const queries = [
    `Give me a public URL (jpg or png) of a photo for the exercise "${nameEn}" workout gym. Return ONLY the direct image URL, nothing else.`,
    nameEs ? `Give me a public URL of a photo for "${nameEs}" ejercicio. Return ONLY the URL.` : null,
  ].filter(Boolean);

  for (const q of queries) {
    try {
      const body = JSON.stringify({
        contents: [{ role: 'user', parts: [{ text: q }] }],
        generationConfig: { temperature: 0.1, maxOutputTokens: 200 },
      });
      const data = await new Promise((resolve) => {
        const req = https.request(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) },
          timeout: 20000,
        }, (res) => {
          let d = '';
          res.on('data', (chunk) => (d += chunk));
          res.on('end', () => {
            if (res.statusCode !== 200) return resolve(null);
            try {
              const json = JSON.parse(d);
              resolve(json.candidates?.[0]?.content?.parts?.[0]?.text?.trim() || null);
            } catch (_) { resolve(null); }
          });
        });
        req.on('error', () => resolve(null));
        req.setTimeout(20000, function () { this.destroy(); resolve(null); });
        req.write(body);
        req.end();
      });
      if (data) {
        let url = data.replace(/```\w*\n?/g, '').replace(/```/g, '').trim();
        if (url.startsWith('http')) return url;
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

async function main() {
  console.log('Conectando a MongoDB...');
  await mongoose.connect(MONGODB_URI);
  console.log('Conectado.\n');

  const svgExercises = await Exercise.find({ localImageMime: 'image/svg+xml' })
    .select('name nameSpanish externalId localImageMime imageUrl')
    .lean();
  
  console.log(`Ejercicios con SVG placeholder: ${svgExercises.length}\n`);

  console.log('Descargando catálogo free-exercise-db...');
  let freeDbList = [];
  try {
    freeDbList = await fetchJson(FREE_DB_JSON_URL);
    console.log(`  ${freeDbList.length} ejercicios disponibles\n`);
  } catch (e) {
    console.log(`  No disponible: ${e.message}\n`);
  }

  const freeDbMap = {};
  for (const fdb of freeDbList) {
    if (fdb.id) freeDbMap[fdb.id] = fdb;
  }

  let replaced = 0;
  let stillSvg = 0;
  const stats = { freeDb: 0, wger: 0, wikimedia: 0, gemini: 0 };

  for (let i = 0; i < svgExercises.length; i++) {
    const ex = svgExercises[i];
    const nameEs = ex.nameSpanish || ex.name;
    const nameLower = ex.name.toLowerCase().trim();

    let nameEn = NAME_MAP[nameLower] || '';
    if (!nameEn) {
      nameEn = await translateToEnglish(nameEs);
      await sleep(250);
    }

    process.stdout.write(`[${i + 1}/${svgExercises.length}] ${nameEs} → "${nameEn}"... `);

    let imgUrl = null;

    imgUrl = await findImageFromFreeDb(freeDbList, freeDbMap, nameEn);
    if (imgUrl) { stats.freeDb++; process.stdout.write('free-db → '); }

    if (!imgUrl) {
      imgUrl = await findImageFromWger(nameEn);
      if (imgUrl) { stats.wger++; process.stdout.write('wger → '); }
    }

    if (!imgUrl) {
      imgUrl = await findImageFromWikimedia(nameEn, nameEs);
      if (imgUrl) { stats.wikimedia++; process.stdout.write('wikimedia → '); }
    }

    if (!imgUrl) {
      imgUrl = await findImageWithGemini(nameEn, nameEs);
      if (imgUrl) { stats.gemini++; process.stdout.write('gemini → '); }
    }

    if (imgUrl) {
      if (imgUrl.includes('wikimedia.org') || imgUrl.includes('upload.wikimedia')) {
        await Exercise.updateOne({ _id: ex._id }, { $set: { imageUrl: imgUrl, gifUrl: '', localImageMime: '' } });
        replaced++;
        console.log('✓ URL directa');
      } else {
        try {
          const buf = await fetchBuffer(imgUrl);
          if (buf && buf.length > 100) {
            const mime = detectMime(imgUrl);
            await Exercise.updateOne({ _id: ex._id }, { $set: { localImage: buf, localImageMime: mime, imageUrl: '' } });
            replaced++;
            console.log(`✓ ${(buf.length / 1024).toFixed(0)} KB`);
          } else {
            stillSvg++;
            console.log('✗ imagen vacía');
          }
        } catch (err) {
          stillSvg++;
          console.log(`✗ ${err.message.slice(0, 30)}`);
        }
      }
    } else {
      stillSvg++;
      console.log('✗ sin resultado');
    }

    if (i % 5 === 4) await sleep(200);
  }

  console.log('\n=== RESUMEN ===');
  console.log(`SVG placeholders procesados: ${svgExercises.length}`);
  console.log(`Reemplazados con imagen real: ${replaced}`);
  console.log(`Siguen como SVG: ${stillSvg}`);
  console.log(`  free-db: ${stats.freeDb}`);
  console.log(`  wger: ${stats.wger}`);
  console.log(`  wikimedia: ${stats.wikimedia}`);
  console.log(`  gemini: ${stats.gemini}`);

  await mongoose.disconnect();
  console.log('\nDesconectado de MongoDB.');
}

main().catch(err => {
  console.error('Error fatal:', err);
  process.exit(1);
});
