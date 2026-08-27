import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/app_config.dart';
import '../../models/auth_user.dart';

/// Armazenamento seguro da sessão DailyTalk associada ao dispositivo.
///
/// A atualização da aplicação preserva estes valores. Só o logout explícito
/// remove os tokens e o utilizador em cache. As chaves do dispositivo são
/// geridas separadamente por DeviceKeyService e não são apagadas no logout.
/// Armazena sessões PRD e DEV em espaços completamente separados.
///
/// Os nomes históricos são mantidos em PRD para preservar sessões após
/// atualizações. DEV usa o sufixo `_dev`, impedindo que tokens, utilizadores em
/// cache e identificadores de dispositivo sejam reutilizados em produção.
class AuthTokenStorage {
  AuthTokenStorage({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;

  String _key(String base) => '$base${AppConfig.storageKeySuffix}';

  String get _accessTokenKey => _key('dailytalk_auth_access_token_v2');
  String get _legacyTokenKey => _key('dailytalk_auth_token');
  String get _refreshTokenKey => _key('dailytalk_auth_refresh_token_v2');
  String get _accessExpiresAtKey => _key('dailytalk_auth_access_expires_at_v2');
  String get _deviceIdKey => _key('dailytalk_auth_device_id_v2');
  String get _cachedUserKey => _key('dailytalk_auth_cached_user_v2');

  Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
    String? accessTokenExpiresAt,
    String? deviceId,
  }) async {
    // Guardar primeiro as credenciais duradouras e o vínculo ao dispositivo.
    // Se a app for terminada durante a escrita, uma sessão sem access token
    // ainda pode ser recuperada silenciosamente através do refresh token.
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    }

    if (deviceId != null && deviceId.isNotEmpty) {
      await _secureStorage.write(key: _deviceIdKey, value: deviceId);
    }

    if (accessTokenExpiresAt != null && accessTokenExpiresAt.isNotEmpty) {
      await _secureStorage.write(
        key: _accessExpiresAtKey,
        value: accessTokenExpiresAt,
      );
    }

    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.delete(key: _legacyTokenKey);
  }

  /// Compatibilidade com código antigo.
  Future<void> saveToken(String token) => saveSession(accessToken: token);

  Future<String?> readToken() async {
    return await _secureStorage.read(key: _accessTokenKey) ??
        await _secureStorage.read(key: _legacyTokenKey);
  }

  Future<String?> readRefreshToken() =>
      _secureStorage.read(key: _refreshTokenKey);

  Future<String?> readAccessTokenExpiresAt() =>
      _secureStorage.read(key: _accessExpiresAtKey);

  Future<String?> readDeviceId() => _secureStorage.read(key: _deviceIdKey);

  Future<bool> hasBoundSession() async {
    final refreshToken = await readRefreshToken();
    final deviceId = await readDeviceId();

    return refreshToken != null &&
        refreshToken.isNotEmpty &&
        deviceId != null &&
        deviceId.isNotEmpty;
  }

  Future<void> saveCachedUser(AuthUser user) async {
    await _secureStorage.write(
      key: _cachedUserKey,
      value: jsonEncode(user.toJson()),
    );
  }

  Future<AuthUser?> readCachedUser() async {
    final value = await _secureStorage.read(key: _cachedUserKey);
    if (value == null || value.isEmpty) return null;

    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return null;
      return AuthUser.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<bool> isAccessTokenFresh({
    Duration safetyWindow = const Duration(seconds: 60),
  }) async {
    final token = await readToken();
    if (token == null || token.isEmpty) return false;

    final rawExpiry = await readAccessTokenExpiresAt();
    final expiry = rawExpiry == null
        ? _jwtExpiry(token)
        : DateTime.tryParse(rawExpiry);

    if (expiry == null) return false;

    return expiry.isAfter(DateTime.now().toUtc().add(safetyWindow));
  }

  Future<void> deleteToken() => clearSession();

  Future<void> clearSession() async {
    await Future.wait([
      _secureStorage.delete(key: _accessTokenKey),
      _secureStorage.delete(key: _legacyTokenKey),
      _secureStorage.delete(key: _refreshTokenKey),
      _secureStorage.delete(key: _accessExpiresAtKey),
      _secureStorage.delete(key: _deviceIdKey),
      _secureStorage.delete(key: _cachedUserKey),
    ]);
  }

  DateTime? _jwtExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final normalized = parts[1].padRight((parts[1].length + 3) ~/ 4 * 4, '=');
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));

      if (payload is! Map || payload['exp'] is! num) return null;

      return DateTime.fromMillisecondsSinceEpoch(
        (payload['exp'] as num).toInt() * 1000,
        isUtc: true,
      );
    } catch (_) {
      return null;
    }
  }
}
