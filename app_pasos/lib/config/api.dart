import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  static String get baseUrl {
    const defined = String.fromEnvironment('BACKEND_URL');
    if (defined.isNotEmpty) return defined;
    if (kIsWeb) return 'https://app-pasos-za8s.onrender.com/api';
    if (Platform.isAndroid) return 'https://app-pasos-za8s.onrender.com/api';
    return 'http://localhost:3000/api';
  }

  static const Duration timeout = Duration(seconds: 30);
}
