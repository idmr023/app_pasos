import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  // Cola de ánimos: varios power-ups seguidos no deben cortarse entre sí
  // (FlutterTts.speak interrumpe lo que se esté diciendo). Se limita el
  // tamaño para no leer ánimos con minutos de retraso si llegan en ráfaga.
  static const int _maxQueued = 6;
  final Queue<String> _queue = Queue<String>();
  bool _draining = false;

  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    await _flutterTts.setLanguage("es-ES");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    // speak() espera a que termine la frase: necesario para la cola.
    // Best-effort: si la plataforma no lo soporta, la cola sigue funcionando
    // (solo que una frase podría cortar a la anterior).
    try {
      await _flutterTts.awaitSpeakCompletion(true);
    } catch (e) {
      debugPrint('[TTS] awaitSpeakCompletion no soportado: $e');
    }
    _isInitialized = true;
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) await init();
    await _flutterTts.speak(text);
  }

  /// Encola [text] y lo lee cuando terminen los anteriores.
  void enqueue(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (_queue.length >= _maxQueued) _queue.removeFirst();
    _queue.add(trimmed);
    _drain();
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty) {
        final next = _queue.removeFirst();
        try {
          if (!_isInitialized) await init();
          await _flutterTts.speak(next);
        } catch (e) {
          debugPrint('[TTS] Error leyendo ánimo: $e');
        }
      }
    } finally {
      _draining = false;
    }
  }

  /// Texto hablado para los mensajes de chat con emoji (compatibilidad con
  /// clientes que aún mandan 🔥💪⚡👏 como chat en vez de power-up).
  static String supportSpeech(String senderName, String message) {
    if (message == '🔥') return '$senderName te envía fuego';
    if (message == '💪') return '$senderName dice: ¡Fuerza!';
    if (message == '⚡') return '$senderName te envía energía';
    if (message == '👏') return '$senderName te está aplaudiendo';
    return '$senderName dice: $message';
  }

  Future<void> speakSupportMessage(String senderName, String message) async {
    enqueue(supportSpeech(senderName, message));
  }

  Future<void> stop() async {
    _queue.clear();
    await _flutterTts.stop();
  }
}
