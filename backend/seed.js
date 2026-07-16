const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const dns = require('dns');
require('dotenv').config();

dns.setServers(['8.8.8.8', '1.1.1.1']);

const User = require('./models/User');
const Exercise = require('./models/Exercise');

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
  }
];

const exercises = [
  // Warmup
  { name: 'Rotación de Cuello', category: 'warmup', defaultSets: 1, defaultReps: '10', restTime: 15, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Neck_Rotation.gif', description: 'Rotar el cuello suavemente en ambas direcciones' },
  { name: 'Círculos de Brazos', category: 'warmup', defaultSets: 1, defaultReps: '10', restTime: 15, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Arm_Circles.gif', description: 'Círculos amplios con los brazos extendidos' },
  { name: 'Torsión de Torso', category: 'warmup', defaultSets: 1, defaultReps: '10', restTime: 15, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Trunk_Twist.gif', description: 'Girar el torso de lado a lado' },
  { name: 'Estocadas Dinámicas', category: 'warmup', defaultSets: 1, defaultReps: '8', restTime: 20, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Lunges.gif', description: 'Estocadas alternando piernas' },
  { name: 'Saltos de Tijera', category: 'warmup', defaultSets: 1, defaultReps: '20', restTime: 20, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Jumping_Jacks.gif', description: 'Saltos abriendo y cerrando brazos y piernas' },
  { name: 'Rodillas al Pecho', category: 'warmup', defaultSets: 1, defaultReps: '10', restTime: 15, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Knee_Hugs.gif', description: 'Llevar rodillas al pecho alternando' },

  // Strength
  { name: 'Flexiones de Brazos', category: 'strength', defaultSets: 3, defaultReps: '12', restTime: 60, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Push_Up.gif', description: 'Flexiones tradicionales con cuerpo recto' },
  { name: 'Sentadillas', category: 'strength', defaultSets: 3, defaultReps: '15', restTime: 60, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Squat.gif', description: 'Sentadillas con peso corporal' },
  { name: 'Plancha', category: 'strength', defaultSets: 3, defaultReps: '30s', restTime: 45, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Plank.gif', description: 'Mantener posición de plancha' },
  { name: 'Dominadas', category: 'strength', defaultSets: 3, defaultReps: '8', restTime: 90, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Pull_Up.gif', description: 'Dominadas en barra' },
  { name: 'Fondos de Tríceps', category: 'strength', defaultSets: 3, defaultReps: '12', restTime: 60, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dips.gif', description: 'Fondos en banco para tríceps' },
  { name: 'Peso Muerto', category: 'strength', defaultSets: 4, defaultReps: '10', restTime: 90, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Deadlift.gif', description: 'Peso muerto con barra o mancuernas' },
  { name: 'Press de Banca', category: 'strength', defaultSets: 4, defaultReps: '10', restTime: 90, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Bench_Press.gif', description: 'Press de banca con barra' },
  { name: 'Remo con Mancuerna', category: 'strength', defaultSets: 3, defaultReps: '12', restTime: 60, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Row.gif', description: 'Remo unilateral con mancuerna' },
  { name: 'Press Militar', category: 'strength', defaultSets: 3, defaultReps: '10', restTime: 60, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Overhead_Press.gif', description: 'Press de hombros con barra o mancuernas' },
  { name: 'Zancadas', category: 'strength', defaultSets: 3, defaultReps: '12', restTime: 60, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Lunges.gif', description: 'Zancadas alternando piernas' },

  // Cardio
  { name: 'Burpees', category: 'cardio', defaultSets: 3, defaultReps: '10', restTime: 45, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Burpee.gif', description: 'Burpees completos' },
  { name: 'Saltos de Cuerda', category: 'cardio', defaultSets: 3, defaultReps: '60s', restTime: 30, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Jump_Rope.gif', description: 'Saltar la cuerda' },
  { name: 'High Knees', category: 'cardio', defaultSets: 3, defaultReps: '30s', restTime: 30, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/High_Knees.gif', description: 'Rodillas arriba en el lugar' },
  { name: 'Montañista', category: 'cardio', defaultSets: 3, defaultReps: '30s', restTime: 30, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Mountain_Climber.gif', description: 'Escalada en posición de plancha' },
  { name: 'Saltos de Sentadilla', category: 'cardio', defaultSets: 3, defaultReps: '12', restTime: 45, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Squat_Jumps.gif', description: 'Sentadilla con salto explosivo' },

  // Flexibility
  { name: 'Estiramiento de Isquiotibiales', category: 'flexibility', defaultSets: 2, defaultReps: '30s', restTime: 15, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Hamstring_Stretch.gif', description: 'Estirar la parte posterior del muslo' },
  { name: 'Estiramiento de Cuádriceps', category: 'flexibility', defaultSets: 2, defaultReps: '30s', restTime: 15, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Quad_Stretch.gif', description: 'Estirar el cuádriceps de pie' },
  { name: 'Estiramiento de Hombros', category: 'flexibility', defaultSets: 2, defaultReps: '30s', restTime: 15, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Shoulder_Stretch.gif', description: 'Estirar hombros cruzando el brazo' },
  { name: 'Estiramiento de Pecho', category: 'flexibility', defaultSets: 2, defaultReps: '30s', restTime: 15, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Chest_Stretch.gif', description: 'Estirar pectorales en marco de puerta' },
  { name: 'Flexión de Torso', category: 'flexibility', defaultSets: 2, defaultReps: '30s', restTime: 15, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Standing_Toe_Touch.gif', description: 'Tocar puntas de los pies' },
  { name: 'Estiramiento de Espalda', category: 'flexibility', defaultSets: 2, defaultReps: '30s', restTime: 15, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Cat_Cow.gif', description: 'Estiramiento gato-vaca' },
  { name: 'Mariposa', category: 'flexibility', defaultSets: 2, defaultReps: '30s', restTime: 15, imageUrl: 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Butterfly_Stretch.gif', description: 'Estiramiento de cadera en mariposa' },
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

    console.log('\nSeed completado!');
    console.log('Usuarios disponibles:');
    console.log('  admin / admin123');
    console.log('  test  / test123');
    console.log('  carlos / carlos123');
    console.log('  maria  / maria123');

    await mongoose.disconnect();
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

seed();
