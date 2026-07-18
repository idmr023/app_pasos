const express = require('express');
const auth = require('../middleware/auth');
const ChatConversation = require('../models/ChatConversation');
const { getCoachResponse } = require('../services/chatService');

const router = express.Router();

const MAX_MESSAGES = 50;

router.post('/', auth, async (req, res) => {
  try {
    const { message } = req.body;
    if (!message || message.trim().length === 0) {
      return res.status(400).json({ error: 'El mensaje no puede estar vacío' });
    }

    let conversation = await ChatConversation.findOne({ user: req.user._id });
    if (!conversation) {
      conversation = new ChatConversation({
        user: req.user._id,
        messages: [],
      });
    }

    conversation.messages.push({
      role: 'user',
      content: message.trim(),
      timestamp: new Date(),
    });

    const messagesForApi = conversation.messages.map(m => ({
      role: m.role,
      content: m.content,
    }));

    const reply = await getCoachResponse(req.user, messagesForApi);

    conversation.messages.push({
      role: 'assistant',
      content: reply,
      timestamp: new Date(),
    });

    if (conversation.messages.length > MAX_MESSAGES) {
      conversation.messages = conversation.messages.slice(-MAX_MESSAGES);
    }

    await conversation.save();

    res.json({
      reply,
      messageCount: conversation.messages.length,
    });
  } catch (error) {
    console.error('Chat error:', error.message);
    res.status(500).json({ error: 'Error al procesar el mensaje' });
  }
});

router.get('/history', auth, async (req, res) => {
  try {
    const conversation = await ChatConversation.findOne({ user: req.user._id });
    if (!conversation) {
      return res.json({ messages: [] });
    }
    res.json({ messages: conversation.messages });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener historial' });
  }
});

router.delete('/history', auth, async (req, res) => {
  try {
    await ChatConversation.findOneAndDelete({ user: req.user._id });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Error al borrar historial' });
  }
});

module.exports = router;
