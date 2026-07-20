const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const auth = require('../middleware/auth');

const router = express.Router();

router.post('/register', async (req, res) => {
  try {
    const { username, password, displayName } = req.body;

    const existingUser = await User.findOne({ username });
    if (existingUser) {
      return res.status(400).json({ error: 'El usuario ya existe' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const user = new User({
      username,
      password: hashedPassword,
      displayName: displayName || username
    });
    await user.save();

    const token = jwt.sign(
      { userId: user._id },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.status(201).json({
      token,
      user: {
        id: user._id,
        username: user.username,
        displayName: user.displayName,
        role: user.role,
        avatar: user.avatar,
        xp: user.xp,
        level: user.level,
        title: user.title,
        weight: user.weight,
        height: user.height,
        goal: user.goal
      }
    });
  } catch (error) {
    res.status(500).json({ error: 'Error al registrar usuario' });
  }
});

router.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;

    const user = await User.findOne({ username });
    if (!user) {
      return res.status(400).json({ error: 'Usuario o contraseña incorrectos' });
    }

    const validPassword = await bcrypt.compare(password, user.password);
    if (!validPassword) {
      return res.status(400).json({ error: 'Usuario o contraseña incorrectos' });
    }

    const token = jwt.sign(
      { userId: user._id },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.json({
      token,
      user: {
        id: user._id,
        username: user.username,
        displayName: user.displayName,
        role: user.role,
        avatar: user.avatar,
        xp: user.xp,
        level: user.level,
        title: user.title,
        weight: user.weight,
        height: user.height,
        goal: user.goal
      }
    });
  } catch (error) {
    res.status(500).json({ error: 'Error al iniciar sesión' });
  }
});

router.get('/profile', auth, async (req, res) => {
  try {
    res.json({
      user: {
        id: req.user._id,
        username: req.user.username,
        displayName: req.user.displayName,
        role: req.user.role,
        avatar: req.user.avatar,
        xp: req.user.xp,
        level: req.user.level,
        title: req.user.title,
        weight: req.user.weight,
        height: req.user.height,
        goal: req.user.goal
      }
    });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener perfil' });
  }
});

router.put('/profile', auth, async (req, res) => {
  try {
    const { displayName, avatar, weight, height, goal } = req.body;

    if (displayName !== undefined) {
      if (displayName.trim().length < 2 || displayName.trim().length > 30) {
        return res.status(400).json({ error: 'El nombre debe tener entre 2 y 30 caracteres' });
      }
      req.user.displayName = displayName.trim();
    }

    const validAvatars = ['runner', 'crown', 'fire', 'star', 'walker', 'marathon', 'ultra', 'legend', 'titan'];
    if (avatar !== undefined) {
      if (!validAvatars.includes(avatar)) {
        return res.status(400).json({ error: 'Avatar inválido' });
      }
      req.user.avatar = avatar;
    }

    if (weight !== undefined) {
      if (weight < 20 || weight > 500) {
        return res.status(400).json({ error: 'El peso debe estar entre 20 y 500 kg' });
      }
      req.user.weight = weight;
    }

    if (height !== undefined) {
      if (height < 50 || height > 300) {
        return res.status(400).json({ error: 'La altura debe estar entre 50 y 300 cm' });
      }
      req.user.height = height;
    }

    const validGoals = ['lose_weight', 'gain_muscle', 'maintain', 'endurance', 'general'];
    if (goal !== undefined) {
      if (!validGoals.includes(goal)) {
        return res.status(400).json({ error: 'Meta inválida' });
      }
      req.user.goal = goal;
    }

    await req.user.save();

    res.json({
      user: {
        id: req.user._id,
        username: req.user.username,
        displayName: req.user.displayName,
        role: req.user.role,
        avatar: req.user.avatar,
        xp: req.user.xp,
        level: req.user.level,
        title: req.user.title,
        weight: req.user.weight,
        height: req.user.height,
        goal: req.user.goal
      }
    });
  } catch (error) {
    res.status(500).json({ error: 'Error al actualizar perfil' });
  }
});

router.put('/security-question', auth, async (req, res) => {
  try {
    const { question, answer } = req.body;
    if (!question || !answer) {
      return res.status(400).json({ error: 'Pregunta y respuesta requeridas' });
    }
    req.user.securityQuestion = question;
    req.user.securityAnswer = await bcrypt.hash(answer.toLowerCase().trim(), 10);
    await req.user.save();
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Error al guardar pregunta de seguridad' });
  }
});

router.get('/security-question/:username', async (req, res) => {
  try {
    const user = await User.findOne({ username: req.params.username });
    if (!user || !user.securityQuestion) {
      return res.status(404).json({ error: 'Usuario no encontrado o sin pregunta de seguridad' });
    }
    res.json({ question: user.securityQuestion });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener pregunta de seguridad' });
  }
});

router.post('/verify-security', async (req, res) => {
  try {
    const { username, answer } = req.body;
    const user = await User.findOne({ username });
    if (!user || !user.securityAnswer) {
      return res.status(404).json({ error: 'Usuario no encontrado o sin pregunta de seguridad' });
    }

    const valid = await bcrypt.compare(answer.toLowerCase().trim(), user.securityAnswer);
    if (!valid) {
      return res.status(403).json({ error: 'Respuesta incorrecta' });
    }

    const resetToken = jwt.sign(
      { userId: user._id, purpose: 'reset' },
      process.env.JWT_SECRET,
      { expiresIn: '15m' }
    );

    res.json({ resetToken });
  } catch (error) {
    res.status(500).json({ error: 'Error al verificar respuesta' });
  }
});

router.post('/reset-password', async (req, res) => {
  try {
    const { resetToken, newPassword } = req.body;

    if (!resetToken || !newPassword) {
      return res.status(400).json({ error: 'Token y nueva contraseña requeridos' });
    }

    const decoded = jwt.verify(resetToken, process.env.JWT_SECRET);
    if (decoded.purpose !== 'reset') {
      return res.status(403).json({ error: 'Token inválido' });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ error: 'La contraseña debe tener al menos 6 caracteres' });
    }

    const user = await User.findById(decoded.userId);
    if (!user) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }

    user.password = await bcrypt.hash(newPassword, 10);
    await user.save();

    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Error al restablecer contraseña' });
  }
});

module.exports = router;
