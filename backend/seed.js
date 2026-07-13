const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const dns = require('dns');
require('dotenv').config();

dns.setServers(['8.8.8.8', '1.1.1.1']);

const User = require('./models/User');

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
