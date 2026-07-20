const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const dns = require('dns');
require('dotenv').config();

dns.setServers(['8.8.8.8', '1.1.1.1']);

const User = require('./models/User');
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
            exercises: [],
          });
        }
        console.log('16 semanas de entrenamiento creadas para Ivan (sin ejercicios especificos)');
      }
    }

    console.log('\nSeed completado!');
    console.log('Usuarios creados (los que no existian):');
    console.log('  admin, test, carlos, maria, ivan');

    await mongoose.disconnect();
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

seed();
