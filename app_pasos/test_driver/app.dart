import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:app_pasos/main.dart' as app;

const _storage = FlutterSecureStorage();

Future<String> _handleData(String? message) async {
  switch (message) {
    case 'token':
      return await _storage.read(key: 'auth_token') ?? '';
    case 'ping':
      return 'pong';
    default:
      return '';
  }
}

void main() {
  enableFlutterDriverExtension(handler: _handleData);
  app.main();
}
