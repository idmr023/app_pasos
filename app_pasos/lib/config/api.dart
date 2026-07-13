import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3000/api';
    if (Platform.isAndroid) return _fromEnvironment;
    return 'http://localhost:3000/api';
  }

  static String get _fromEnvironment {
    const env = String.fromEnvironment('BACKEND_URL');
    if (env.isNotEmpty) return env;
    return 'http://192.168.18.15:3000/api';
  }

  static const Duration timeout = Duration(seconds: 60);
}
