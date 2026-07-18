const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const dns = require('dns');
require('dotenv').config();

dns.setServers(['8.8.8.8', '1.1.1.1']);

const User = require('./models/User');
const Exercise = require('./models/Exercise');
const Workout = require('./models/Workout');

const users = [
  {
    username: 'admin',
    password: 'admin123',
    displayName: 'Admin',
    role: 'admin',
    avatar: 'crown'
  },
  {
    username: 'test',
    password: 'test123',
    displayName: 'Usuario de Prueba',
    role: 'user',
    avatar: 'runner'
  },
  {
    username: 'carlos',
    password: 'carlos123',
    displayName: 'Carlos',
    role: 'user',
    avatar: 'fire'
  },
  {
    username: 'maria',
    password: 'maria123',
    displayName: 'María',
    role: 'user',
    avatar: 'star'
  },
  {
    username: 'ivan',
    password: 'ivan123',
    displayName: 'Ivan Manrique',
    role: 'user',
    avatar: 'crown',
    xp: 0,
    level: 0,
    title: ''
  }
];

const exercises = [
  // Warmup
  { name: 'Rotación de Cuello', category: 'warmup', defaultSets: 1, defaultReps: '10', restTime: 15, imageUrl: '', description: 'Rotar el cuello suavemente en ambas direcciones' },
  { name: 'Círculos de Brazos', category: 'warmup', defaultSets: 1, defaultReps: '10', restTime: 15, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Arm_Circles/0.jpg', description: 'Círculos amplios con los brazos extendidos' },
  { name: 'Torsión de Torso', category: 'warmup', defaultSets: 1, defaultReps: '10', restTime: 15, imageUrl: '', description: 'Girar el torso de lado a lado' },
  { name: 'Estocadas Dinámicas', category: 'warmup', defaultSets: 1, defaultReps: '8', restTime: 20, imageUrl: '', description: 'Estocadas alternando piernas' },
  { name: 'Saltos de Tijera', category: 'warmup', defaultSets: 1, defaultReps: '20', restTime: 20, imageUrl: '', description: 'Saltos abriendo y cerrando brazos y piernas' },
  { name: 'Rodillas al Pecho', category: 'warmup', defaultSets: 1, defaultReps: '10', restTime: 15, imageUrl: '', description: 'Llevar rodillas al pecho alternando' },

  // Strength
  { name: 'Flexiones de Brazos', category: 'strength', defaultSets: 3, defaultReps: '12', restTime: 60, imageUrl: '', description: 'Flexiones tradicionales con cuerpo recto' },
  { name: 'Sentadillas', category: 'strength', defaultSets: 3, defaultReps: '15', restTime: 60, imageUrl: '', description: 'Sentadillas con peso corporal' },
  { name: 'Plancha', category: 'strength', defaultSets: 3, defaultReps: '30s', restTime: 45, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Plank/0.jpg', description: 'Mantener posición de plancha' },
  { name: 'Dominadas', category: 'strength', defaultSets: 3, defaultReps: '8', restTime: 90, imageUrl: '', description: 'Dominadas en barra' },
  { name: 'Fondos de Tríceps', category: 'strength', defaultSets: 3, defaultReps: '12', restTime: 60, imageUrl: '', description: 'Fondos en banco para tríceps' },
  { name: 'Peso Muerto', category: 'strength', defaultSets: 4, defaultReps: '10', restTime: 90, imageUrl: '', description: 'Peso muerto con barra o mancuernas' },
  { name: 'Press de Banca', category: 'strength', defaultSets: 4, defaultReps: '10', restTime: 90, imageUrl: '', description: 'Press de banca con barra' },
  { name: 'Remo con Mancuerna', category: 'strength', defaultSets: 3, defaultReps: '12', restTime: 60, imageUrl: '', description: 'Remo unilateral con mancuerna' },
  { name: 'Press Militar', category: 'strength', defaultSets: 3, defaultReps: '10', restTime: 60, imageUrl: '', description: 'Press de hombros con barra o mancuernas' },
  { name: 'Zancadas', category: 'strength', defaultSets: 3, defaultReps: '12', restTime: 60, imageUrl: '', description: 'Zancadas alternando piernas' },

  // Cardio
  { name: 'Burpees', category: 'cardio', defaultSets: 3, defaultReps: '10', restTime: 45, imageUrl: '', description: 'Burpees completos' },
  { name: 'Saltos de Cuerda', category: 'cardio', defaultSets: 3, defaultReps: '60s', restTime: 30, imageUrl: '', description: 'Saltar la cuerda' },
  { name: 'High Knees', category: 'cardio', defaultSets: 3, defaultReps: '30s', restTime: 30, imageUrl: '', description: 'Rodillas arriba en el lugar' },
  { name: 'Montañista', category: 'cardio', defaultSets: 3, defaultReps: '30s', restTime: 30, imageUrl: '', description: 'Escalada en posición de plancha' },
  { name: 'Saltos de Sentadilla', category: 'cardio', defaultSets: 3, defaultReps: '12', restTime: 45, imageUrl: '', description: 'Sentadilla con salto explosivo' },

  // Flexibility
  { name: 'Estiramiento de Isquiotibiales', category: 'flexibility', defaultSets: 2, defaultReps: '30s', restTime: 15, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Hamstring_Stretch/0.jpg', description: 'Estirar la parte posterior del muslo' },
  { name: 'Estiramiento de Cuádriceps', category: 'flexibility', defaultSets: 2, defaultReps: '30s', restTime: 15, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Quad_Stretch/0.jpg', description: 'Estirar el cuádriceps de pie' },
  { name: 'Estiramiento de Hombros', category: 'flexibility', defaultSets: 2, defaultReps: '30s', restTime: 15, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Shoulder_Stretch/0.jpg', description: 'Estirar hombros cruzando el brazo' },
  { name: 'Estiramiento de Pecho', category: 'flexibility', defaultSets: 2, defaultReps: '30s', restTime: 15, imageUrl: '', description: 'Estirar pectorales en marco de puerta' },
  { name: 'Flexión de Torso', category: 'flexibility', defaultSets: 2, defaultReps: '30s', restTime: 15, imageUrl: '', description: 'Tocar puntas de los pies' },
  { name: 'Estiramiento de Espalda', category: 'flexibility', defaultSets: 2, defaultReps: '30s', restTime: 15, imageUrl: '', description: 'Estiramiento gato-vaca' },
  { name: 'Mariposa', category: 'flexibility', defaultSets: 2, defaultReps: '30s', restTime: 15, imageUrl: '', description: 'Estiramiento de cadera en mariposa' },
  { name: 'Plancha Asimétrica', category: 'strength', defaultSets: 3, defaultReps: '30s', restTime: 45, imageUrl: '', description: 'Plancha lateral alternando brazos' },
  { name: 'Plancha Normal', category: 'strength', defaultSets: 3, defaultReps: '45s', restTime: 45, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Plank/0.jpg', description: 'Plancha tradicional con cuerpo recto' },
  { name: 'Farmer Walk', category: 'strength', defaultSets: 3, defaultReps: '30s', restTime: 60, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Farmers_Walk/0.jpg', description: 'Caminar con peso en cada mano' },

  // === NEW ADDITIONAL EXERCISES ===

  // Warmup
  { name: 'Círculos de Cadera', category: 'warmup', defaultSets: 1, defaultReps: '10', restTime: 15, imageUrl: '', description: 'Círculos con la cadera para movilidad' },
  { name: 'Rotación de Tobillos', category: 'warmup', defaultSets: 1, defaultReps: '10', restTime: 10, imageUrl: '', description: 'Rotar los tobillos en ambas direcciones' },
  { name: 'Apertura de Pecho', category: 'warmup', defaultSets: 1, defaultReps: '10', restTime: 15, imageUrl: '', description: 'Abrir el pecho llevando brazos hacia atrás' },
  { name: 'Sentadilla Profunda con Pausa', category: 'warmup', defaultSets: 1, defaultReps: '8', restTime: 20, imageUrl: '', description: 'Mantener sentadilla profunda 5 segundos' },
  { name: 'Rotación de Muñecas', category: 'warmup', defaultSets: 1, defaultReps: '10', restTime: 10, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Wrist_Circles/0.jpg', description: 'Rotar las muñecas en ambas direcciones' },

  // Strength
  { name: 'Curl de Bíceps con Mancuerna', category: 'strength', defaultSets: 3, defaultReps: '12', restTime: 60, imageUrl: '', description: 'Curl de bíceps con mancuernas' },
  { name: 'Extensiones de Tríceps', category: 'strength', defaultSets: 3, defaultReps: '12', restTime: 60, imageUrl: '', description: 'Extensiones de tríceps por encima de la cabeza' },
  { name: 'Elevaciones Laterales', category: 'strength', defaultSets: 3, defaultReps: '12', restTime: 45, imageUrl: '', description: 'Elevaciones laterales con mancuernas' },
  { name: 'Elevaciones Frontales', category: 'strength', defaultSets: 3, defaultReps: '12', restTime: 45, imageUrl: '', description: 'Elevaciones frontales con mancuernas' },
  { name: 'Peso Muerto Rumano', category: 'strength', defaultSets: 4, defaultReps: '10', restTime: 90, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Romanian_Deadlift/0.jpg', description: 'Peso muerto con piernas semi-extendidas' },
  { name: 'Remo en Barra', category: 'strength', defaultSets: 4, defaultReps: '10', restTime: 90, imageUrl: '', description: 'Remo con barra inclinado' },
  { name: 'Press Inclinado con Mancuerna', category: 'strength', defaultSets: 4, defaultReps: '10', restTime: 90, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Incline_Dumbbell_Press/0.jpg', description: 'Press de pecho inclinado con mancuernas' },
  { name: 'Face Pull', category: 'strength', defaultSets: 3, defaultReps: '15', restTime: 45, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Face_Pull/0.jpg', description: 'Face pull con polea o banda' },
  { name: 'Curl de Martillo', category: 'strength', defaultSets: 3, defaultReps: '12', restTime: 60, imageUrl: '', description: 'Curl martillo con mancuernas' },
  { name: 'Fondos en Paralelas', category: 'strength', defaultSets: 3, defaultReps: '10', restTime: 60, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Parallel_Bar_Dip/0.jpg', description: 'Fondos en barras paralelas' },
  { name: 'Prensa de Piernas', category: 'strength', defaultSets: 4, defaultReps: '12', restTime: 90, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Leg_Press/0.jpg', description: 'Prensa de piernas en máquina' },
  { name: 'Extensiones de Cuádriceps', category: 'strength', defaultSets: 3, defaultReps: '12', restTime: 60, imageUrl: '', description: 'Extensiones de cuádriceps en máquina' },
  { name: 'Curl Femoral', category: 'strength', defaultSets: 3, defaultReps: '12', restTime: 60, imageUrl: '', description: 'Curl femoral acostado en máquina' },
  { name: 'Puente de Glúteos', category: 'strength', defaultSets: 3, defaultReps: '15', restTime: 45, imageUrl: '', description: 'Puente de glúteos en el suelo' },
  { name: 'Peso Muerto a Una Pierna', category: 'strength', defaultSets: 3, defaultReps: '10', restTime: 60, imageUrl: '', description: 'Peso muerto unilateral con mancuerna' },
  { name: 'Remo Invertido', category: 'strength', defaultSets: 3, defaultReps: '10', restTime: 60, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Inverted_Row/0.jpg', description: 'Remo suspendido en barra baja' },

  // Cardio
  { name: 'Sprints en el Lugar', category: 'cardio', defaultSets: 3, defaultReps: '20s', restTime: 20, imageUrl: '', description: 'Correr en el lugar lo más rápido posible' },
  { name: 'Saltos de Estrella', category: 'cardio', defaultSets: 3, defaultReps: '10', restTime: 30, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Star_Jump/0.jpg', description: 'Saltos abriendo brazos y piernas en estrella' },
  { name: 'Escalador Cruzado', category: 'cardio', defaultSets: 3, defaultReps: '30s', restTime: 30, imageUrl: '', description: 'Montañista llevando rodilla al codo contrario' },
  { name: 'Saltos de Caja', category: 'cardio', defaultSets: 3, defaultReps: '10', restTime: 45, imageUrl: '', description: 'Saltos sobre una caja o plataforma' },
  { name: 'Bicicleta en el Aire', category: 'cardio', defaultSets: 3, defaultReps: '30s', restTime: 20, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Air_Bike/0.jpg', description: 'Pedalear en el aire acostado boca arriba' },
  { name: 'Saltos de Talón a Glúteo', category: 'cardio', defaultSets: 3, defaultReps: '30s', restTime: 20, imageUrl: '', description: 'Llevar talones a los glúteos saltando' },

  // Flexibility
  { name: 'Estiramiento de Cadera en 90/90', category: 'flexibility', defaultSets: 2, defaultReps: '30s', restTime: 15, imageUrl: '', description: 'Estiramiento de cadera en posición 90/90' },
  { name: 'Estiramiento de Psoas', category: 'flexibility', defaultSets: 2, defaultReps: '30s', restTime: 15, imageUrl: '', description: 'Estiramiento del psoas en media luna' },
  { name: 'Estiramiento de Gemelos', category: 'flexibility', defaultSets: 2, defaultReps: '30s', restTime: 15, imageUrl: '', description: 'Estiramiento de gemelos contra la pared' },
  { name: 'Postura del Niño', category: 'flexibility', defaultSets: 2, defaultReps: '45s', restTime: 15, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Childs_Pose/0.jpg', description: "Postura de yoga Child's Pose para relajar espalda" },
  { name: 'Estiramiento de Tríceps', category: 'flexibility', defaultSets: 2, defaultReps: '30s', restTime: 15, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Triceps_Stretch/0.jpg', description: 'Estirar tríceps por encima de la cabeza' },
  { name: 'Flexión Lateral de Torso', category: 'flexibility', defaultSets: 2, defaultReps: '30s', restTime: 15, imageUrl: '', description: 'Inclinación lateral del torso' },
  { name: 'Estiramiento de Abductores', category: 'flexibility', defaultSets: 2, defaultReps: '30s', restTime: 15, imageUrl: '', description: 'Estiramiento de abductores sentado' },
  { name: 'Estiramiento de Glúteos', category: 'flexibility', defaultSets: 2, defaultReps: '30s', restTime: 15, imageUrl: '', description: 'Estiramiento de glúteos en postura de paloma' },
  { name: 'Rotación de Columna Supina', category: 'flexibility', defaultSets: 2, defaultReps: '30s', restTime: 15, imageUrl: '', description: 'Rotación de columna acostado' },
];

async function seed() {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Conectado a MongoDB Atlas');

    for (const userData of users) {
      const existing = await User.findOne({ username: userData.username });
      if (existing) {
        console.log(`Usuario '${userData.username}' ya existe, saltando...`);
        continue;
      }

      const hashedPassword = await bcrypt.hash(userData.password, 10);
      const user = new User({
        ...userData,
        password: hashedPassword
      });
      await user.save();
      console.log(`Usuario '${userData.username}' creado`);
    }

    for (const ex of exercises) {
      const existing = await Exercise.findOne({ name: ex.name });
      if (existing) {
        console.log(`Ejercicio '${ex.name}' ya existe, saltando...`);
        continue;
      }
      await Exercise.create(ex);
      console.log(`Ejercicio '${ex.name}' creado`);
    }

    const ivanUser = await User.findOne({ username: 'ivan' });
    if (ivanUser) {
      const existingWorkouts = await Workout.countDocuments({ user: ivanUser._id });
      if (existingWorkouts === 0) {
        const now = new Date();
        for (let w = 0; w < 16; w++) {
          const weekDate = new Date(now);
          weekDate.setDate(weekDate.getDate() - (w * 7));
          await Workout.create({
            user: ivanUser._id,
            routineName: 'Rutina Semanal',
            date: weekDate,
            duration: 1800,
            exercises: [
              { exerciseName: 'Flexiones', setsCompleted: 3, repsCompleted: '15' },
              { exerciseName: 'Sentadillas', setsCompleted: 3, repsCompleted: '20' },
            ]
          });
        }
        console.log('16 semanas de entrenamiento creadas para Ivan');
      }
    }

    console.log('\nSeed completado!');
    console.log('Usuarios disponibles:');
    console.log('  admin / admin123');
    console.log('  test  / test123');
    console.log('  carlos / carlos123');
    console.log('  maria  / maria123');
    console.log('  ivan / ivan123 (16 semanas de racha)');

    await mongoose.disconnect();
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

seed();
