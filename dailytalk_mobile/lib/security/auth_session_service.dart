import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../data/storage/auth_token_storage.dart';
import 'device_key_service.dart';
import 'dpop_service.dart';

class SessionReauthenticationRequiredException implements Exception {
  const SessionReauthenticationRequiredException([
    this.message =
        'É necessário confirmar a conta antes da próxima sincronização.',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// Mantém uma sessão vinculada ao dispositivo sem interromper o utilizador.
///
/// Access tokens curtos são renovados em segundo plano com o refresh token e
/// uma prova DPoP assinada pela chave privada desta instalação.
class AuthSessionService {
  AuthSessionService({
    http.Client? client,
    AuthTokenStorage? tokenStorage,
    DeviceKeyService? deviceKeyService,
    DpopService? dpopService,
  }) : _client = client ?? http.Client(),
       _tokenStorage = tokenStorage ?? AuthTokenStorage() {
    _deviceKeyService = deviceKeyService ?? DeviceKeyService();
    _dpopService =
        dpopService ?? DpopService(deviceKeyService: _deviceKeyService);
  }

  final http.Client _client;
  final AuthTokenStorage _tokenStorage;
  late final DeviceKeyService _deviceKeyService;
  late final DpopService _dpopService;

  Future<Map<String, String>> authenticatedHeaders({
    required String method,
    required Uri uri,
    bool includeJsonContentType = true,
  }) async {
    AppConfig.assertApiUri(uri);

    final token = await ensureAccessToken();
    final isBound = await _tokenStorage.hasBoundSession();
    final headers = <String, String>{...AppConfig.environmentHeaders};

    if (includeJsonContentType) {
      headers['Content-Type'] = 'application/json';
    }

    if (!isBound) {
      headers['Authorization'] = 'Bearer $token';
      return headers;
    }

    final proof = await _dpopService.createProof(
      method: method,
      uri: uri,
      accessToken: token,
    );
    headers['Authorization'] = 'DPoP $token';
    headers['DPoP'] = proof;
    return headers;
  }

  Future<String> ensureAccessToken() async {
    var token = await _tokenStorage.readToken();

    // Uma escrita interrompida pode deixar apenas a credencial duradoura. O
    // utilizador não deve ser obrigado a entrar novamente por esse motivo.
    if (token == null || token.isEmpty) {
      if (await _tokenStorage.hasBoundSession()) {
        return _refreshSilently();
      }
      throw const SessionReauthenticationRequiredException();
    }

    if (!await _tokenStorage.hasBoundSession()) {
      await _enrolLegacySession(token);
      token = await _tokenStorage.readToken();
      if (token == null || token.isEmpty) {
        throw const SessionReauthenticationRequiredException();
      }
    }

    if (await _tokenStorage.isAccessTokenFresh()) {
      return token;
    }

    return _refreshSilently();
  }

  Future<String> _refreshSilently() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const SessionReauthenticationRequiredException();
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/refresh');
    final proof = await _dpopService.createProof(method: 'POST', uri: uri);

    try {
      final response = await _client
          .post(
            uri,
            headers: {...AppConfig.jsonHeaders, 'DPoP': proof},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(AppConfig.apiTimeout);
      final decoded = _decodeResponse(response);
      final accessToken =
          decoded['accessToken']?.toString() ?? decoded['token']?.toString();

      if (accessToken == null || accessToken.isEmpty) {
        throw const SessionReauthenticationRequiredException();
      }

      await _tokenStorage.saveSession(
        accessToken: accessToken,
        accessTokenExpiresAt: decoded['accessTokenExpiresAt']?.toString(),
        deviceId: decoded['deviceId']?.toString(),
      );
      return accessToken;
    } on SessionReauthenticationRequiredException {
      rethrow;
    } catch (error) {
      // A sessão e os dados locais são preservados. A interface pode continuar
      // offline e tentar novamente quando houver rede.
      throw SessionReauthenticationRequiredException(error.toString());
    }
  }

  Future<void> _enrolLegacySession(String legacyToken) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/devices/enrol-session');
    final device = await _deviceKeyService.registrationPayload();

    try {
      final response = await _client
          .post(
            uri,
            headers: {
              ...AppConfig.jsonHeaders,
              'Authorization': 'Bearer $legacyToken',
            },
            body: jsonEncode({'device': device}),
          )
          .timeout(AppConfig.apiTimeout);
      final decoded = _decodeResponse(response);
      final accessToken =
          decoded['accessToken']?.toString() ?? decoded['token']?.toString();
      final refreshToken = decoded['refreshToken']?.toString();
      final deviceId = decoded['deviceId']?.toString();

      if (accessToken == null ||
          accessToken.isEmpty ||
          refreshToken == null ||
          refreshToken.isEmpty ||
          deviceId == null ||
          deviceId.isEmpty) {
        throw const SessionReauthenticationRequiredException();
      }

      await _tokenStorage.saveSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        accessTokenExpiresAt: decoded['accessTokenExpiresAt']?.toString(),
        deviceId: deviceId,
      );
    } catch (error) {
      throw SessionReauthenticationRequiredException(error.toString());
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    AppConfig.assertResponseEnvironment(response.headers);

    final Object decoded;
    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } on FormatException {
      throw const SessionReauthenticationRequiredException(
        'A API devolveu uma resposta inválida.',
      );
    }

    if (decoded is! Map) {
      throw const SessionReauthenticationRequiredException(
        'A API devolveu uma resposta inválida.',
      );
    }
    final map = Map<String, dynamic>.from(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SessionReauthenticationRequiredException(
        map['error']?.toString() ?? 'Não foi possível renovar a sessão.',
      );
    }
    return map;
  }
}
