const mongoose = require('mongoose');
require('dotenv').config();
const Quote = require('./models/Quote');

const MONGO_URI = process.env.MONGODB_URI || process.env.MONGO_URI || 'mongodb://localhost:27017/app-pasos';

const quotes = [
  { text: '¡Llevas 10 semanas seguidas entrenando! Eres imparable 💪', type: 'streak', minWeeks: 10 },
  { text: '12 semanas de racha. La disciplina vence a la motivación', type: 'streak', minWeeks: 12 },
  { text: 'Cada semana cuenta. Ya son 14 semanas seguidas 🔥', type: 'streak', minWeeks: 14 },
  { text: '16 semanas. Esto ya es un estilo de vida', type: 'streak', minWeeks: 16 },
  { text: '18 semanas y sigues imparable. ¡Sigue así!', type: 'streak', minWeeks: 18 },
  { text: '20 semanas consecutivas. ¡Eres un ejemplo a seguir!', type: 'streak', minWeeks: 20 },
  { text: '22 semanas de pura disciplina. Increíble', type: 'streak', minWeeks: 22 },
  { text: '24 semanas. Medio año sin fallar. ¡Eres una máquina!', type: 'streak', minWeeks: 24 },
  { text: '26 semanas. La consistencia es tu superpoder 🏆', type: 'streak', minWeeks: 26 },
  { text: '30 semanas de entrenamiento ininterrumpido', type: 'streak', minWeeks: 30 },
  { text: '34 semanas. Ya no es racha, es tu nueva vida', type: 'streak', minWeeks: 34 },
  { text: '38 semanas y cuentas. ¡Imparable!', type: 'streak', minWeeks: 38 },
  { text: '42 semanas. La dedicación te define', type: 'streak', minWeeks: 42 },
  { text: '46 semanas. Casi un año completo 💯', type: 'streak', minWeeks: 46 },
  { text: '¡50 semanas! El hábito ya es parte de ti', type: 'streak', minWeeks: 50 },
  { text: '¡52 SEMANAS! Un año completo entrenando. Eres una leyenda 🏆', type: 'streak', minWeeks: 52 },
  { text: '6 meses desde que empezaste esta aventura. Gracias por confiar en nosotros ❤️', type: 'anniversary', minMonths: 6 },
  { text: '12 meses. ¡Un año! Gracias por ser parte de App Pasos 🎉', type: 'anniversary', minMonths: 12 },
  { text: '18 meses y sigues aquí. Nos motivas a seguir mejorando', type: 'anniversary', minMonths: 18 },
  { text: '2 años. Qué honor tenerte con nosotros. ¡Sigue brillando! ⭐', type: 'anniversary', minMonths: 24 },
  { text: '30 meses. Tu constancia es inspiradora', type: 'anniversary', minMonths: 30 },
  { text: '3 años. Eres parte de la familia App Pasos. ¡Gracias totales! 🙌', type: 'anniversary', minMonths: 36 },
];

async function seed() {
  await mongoose.connect(MONGO_URI);

  for (const q of quotes) {
    const existing = await Quote.findOne({ type: q.type, minWeeks: q.minWeeks, minMonths: q.minMonths });
    if (existing) {
      console.log(`Quote ya existe: "${q.text.substring(0, 40)}..."`);
      continue;
    }
    await Quote.create(q);
    console.log(`Quote creada: "${q.text.substring(0, 40)}..."`);
  }

  console.log('Seed de quotes completo');
  await mongoose.disconnect();
}

seed().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
