const mongoose = require('mongoose');
const https = require('https');
const dns = require('dns');
const Exercise = require('./models/Exercise');
require('dotenv').config();

dns.setServers(['8.8.8.8', '1.1.1.1']);

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/app-pasos';

const MANUAL_IMAGES = {
  'Press de Banca': 'https://fitcron.com/wp-content/uploads/2021/03/12581301-Barbell-Wide-Reverse-Grip-Bench-Press_Chest_720.gif',
  'Peso Muerto': 'https://fitcron.com/wp-content/uploads/2021/04/00851301-Barbell-Romanian-Deadlift_Hips_720.gif',
  'Dominadas': 'https://media.tenor.com/bOA5VPeUz5QAAAAM/noequipmentexercisesmen-pullups.gif',
  'Burpees': 'https://fitcron.com/wp-content/uploads/2021/03/11601301-Burpee_Cardio_720.gif',
  'Zancadas': 'https://fitcron.com/wp-content/uploads/2021/04/03361301-Dumbbell-Lunge_Hips_720.gif',
  'Press Militar': 'https://fitcron.com/wp-content/uploads/2021/04/14541103-Lever-Seated-Shoulder-Press_Shoulders_720.gif',
  'Fondos de Tríceps': 'https://fitcron.com/wp-content/uploads/2021/03/14511301-Lever-Seated-Dip_Upper-Arms_720.gif',
  'Remo con Mancuerna': 'https://fitcron.com/wp-content/uploads/2021/04/02931301-Dumbbell-Bent-Over-Row_Back-FIX_720.gif',
  'Curl de Bíceps con Mancuerna': 'https://fitcron.com/wp-content/uploads/2021/04/10321301-Lever-Alternate-Biceps-Curl_Upper-Arms_720.gif',
  'Elevaciones Laterales': 'https://fitcron.com/wp-content/uploads/2021/04/03341301-Dumbbell-Lateral-Raise_shoulder-AFIX_720.gif',
  'Elevaciones Frontales': 'https://fitcron.com/wp-content/uploads/2021/04/03101301-Dumbbell-Front-Raise_Shoulders_720.gif',
  'Curl de Martillo': 'https://fitcron.com/wp-content/uploads/2021/04/16571301-Dumbbell-Cross-Body-Hammer-Curl-Version-2_Upper-Arms_720.gif',
  'Puente de Glúteos': 'https://fitcron.com/wp-content/uploads/2021/04/33351301-Dumbbell-Glute-Bridge_Hip_720.gif',
  'Curl Femoral': 'https://fitcron.com/wp-content/uploads/2021/04/05861301-Lever-Lying-Leg-Curl_Thighs_720.gif',
  'Extensiones de Cuádriceps': 'https://fitcron.com/wp-content/uploads/2021/04/05851301-Lever-Leg-Extension_Thighs_720.gif',
  'Peso Muerto a Una Pierna': 'https://fitcron.com/wp-content/uploads/2021/04/17571301-Dumbbell-Single-Leg-Deadlift_Hips_720.gif',
  'Saltos de Caja': 'https://fitcron.com/wp-content/uploads/2021/03/37001301-Tuck-Jump-VERSION-2_Cardio_720.gif',
  'Estocadas Dinámicas': 'https://fitcron.com/wp-content/uploads/2021/04/15541301-Dumbbell-Split-Jump_Plyometric_720.gif',
  'High Knees': 'https://fitcron.com/wp-content/uploads/2021/03/36551301-Walking-High-Knees-Lunge_Cardio_720.gif',
  'Saltos de Cuerda': 'https://fitcron.com/wp-content/uploads/2021/03/36781301-High-Jump-Rope-male_Cardio_720.gif',
  'Saltos de Talón a Glúteo': 'https://fitcron.com/wp-content/uploads/2021/03/30371301-Butt-Kicks-male_Cardio_720.gif',
  'Sprints en el Lugar': 'https://fitcron.com/wp-content/uploads/2021/03/35891301-Quickly-Trot-in-place_Cardio_720.gif',
  'Escalador Cruzado': 'https://fitcron.com/wp-content/uploads/2021/03/06301301-Mountain-Climber_Cardio_720.gif',
  'Sentadilla Profunda con Pausa': 'https://fitcron.com/wp-content/uploads/2021/04/00431301-Barbell-Full-Squat_Thighs_720.gif',
  'Leñadores con cable': 'https://fitcron.com/wp-content/uploads/2021/04/38801301-Cable-Leaning-Lateral-Raise_Shoulders_720.gif',
  'Apertura de Pecho': 'https://fitcron.com/wp-content/uploads/2021/03/05961301-Lever-Seated-Fly_Chest_720.gif',
  'Mariposa': 'https://fitcron.com/wp-content/uploads/2021/03/05961301-Lever-Seated-Fly_Chest_720.gif',
};

function fetchBuffer(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { 'User-Agent': 'Mozilla/5.0' }, timeout: 20000 }, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        res.destroy();
        return resolve(fetchBuffer(new URL(res.headers.location, url).href));
      }
      if (res.statusCode !== 200) { res.destroy(); return reject(new Error(`HTTP ${res.statusCode}`)); }
      const chunks = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => resolve(Buffer.concat(chunks)));
    }).on('error', reject).setTimeout(20000, function () { this.destroy(); reject(new Error('Timeout')); });
  });
}

function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }

async function seed() {
  console.log('Conectando a MongoDB...');
  await mongoose.connect(MONGODB_URI);
  console.log('Conectado.\n');

  let ok = 0;
  let fail = 0;

  for (const [name, url] of Object.entries(MANUAL_IMAGES)) {
    process.stdout.write(`[${ok + fail + 1}/${Object.keys(MANUAL_IMAGES).length}] ${name}... `);

    const ex = await Exercise.findOne({
      $or: [
        { nameSpanish: { $regex: `^${name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, $options: 'i' } },
        { name: { $regex: `^${name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, $options: 'i' } },
      ],
    });

    if (!ex) {
      console.log('✗ no encontrado en BD');
      fail++;
      continue;
    }

    try {
      const buf = await fetchBuffer(url);
      if (!buf || buf.length < 100) {
        console.log('✗ descarga vacía');
        fail++;
        continue;
      }

      const mime = url.endsWith('.gif') ? 'image/gif' : 'image/jpeg';
      const imgId = ex.externalId || String(ex._id);

      await Exercise.updateOne(
        { _id: ex._id },
        {
          $set: {
            localImage: buf,
            localImageMime: mime,
            imageUrl: `/api/gym/exercise-image/${imgId}`,
          },
        }
      );
      ok++;
      console.log(`✓ ${(buf.length / 1024).toFixed(0)} KB (${mime})`);
    } catch (err) {
      console.log(`✗ ${err.message.slice(0, 40)}`);
      fail++;
    }

    await sleep(300);
  }

  console.log(`\n=== RESULTADO ===`);
  console.log(`Actualizados: ${ok}`);
  console.log(`Fallidos: ${fail}`);

  const svgs = await Exercise.countDocuments({ localImageMime: 'image/svg+xml' });
  console.log(`SVG restantes: ${svgs}`);

  await mongoose.disconnect();
  console.log('Desconectado.');
}

seed().catch(err => {
  console.error('Error fatal:', err);
  process.exit(1);
});
