import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3000/api';
    if (Platform.isAndroid) return 'https://app-pasos.onrender.com/api';
    return 'http://localhost:3000/api';
  }

  static const Duration timeout = Duration(seconds: 60);
}
