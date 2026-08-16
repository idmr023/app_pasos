import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    await _flutterTts.setLanguage("es-ES");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    _isInitialized = true;
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) await init();
    await _flutterTts.speak(text);
  }

  Future<void> speakSupportMessage(String senderName, String message) async {
    if (!_isInitialized) await init();
    String txt;
    if (message == '🔥') {
      txt = '$senderName te envía fuego';
    } else if (message == '💪') {
      txt = '$senderName dice: ¡Fuerza!';
    } else if (message == '⚡') {
      txt = '$senderName te envía energía';
    } else if (message == '👏') {
      txt = '$senderName te está aplaudiendo';
    } else {
      txt = '$senderName dice: $message';
    }
    await _flutterTts.speak(txt);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}