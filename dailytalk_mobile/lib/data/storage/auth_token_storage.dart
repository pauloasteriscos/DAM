import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Armazenamento seguro do token JWT.
///
/// O token não deve ser guardado em SQLite nem em app_settings.
/// A tabela app_settings fica reservada para preferências não sensíveis.
class AuthTokenStorage {
  AuthTokenStorage({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;

  static const String _tokenKey = 'dailytalk_auth_token';

  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  Future<String?> readToken() {
    return _secureStorage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    await _secureStorage.delete(key: _tokenKey);
  }
}
