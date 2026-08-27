import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../../models/auth_user.dart';
import '../../security/auth_session_service.dart';
import '../../security/device_key_service.dart';
import '../storage/auth_token_storage.dart';

/// Serviço de autenticação da API DailyTalk.pt.
class AuthApiService {
  AuthApiService({
    http.Client? client,
    AuthTokenStorage? tokenStorage,
    DeviceKeyService? deviceKeyService,
    AuthSessionService? authSessionService,
  }) : _client = client ?? http.Client(),
       _tokenStorage = tokenStorage ?? AuthTokenStorage(),
       _deviceKeyService = deviceKeyService ?? DeviceKeyService(),
       _authSessionService =
           authSessionService ??
           AuthSessionService(
             client: client,
             tokenStorage: tokenStorage,
             deviceKeyService: deviceKeyService,
           );

  final http.Client _client;
  final AuthTokenStorage _tokenStorage;
  final DeviceKeyService _deviceKeyService;
  final AuthSessionService _authSessionService;

  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
    String role = 'student',
  }) async {
    if (AppConfig.useMockApi) {
      return AuthSession(
        token: 'mock-token-${DateTime.now().millisecondsSinceEpoch}',
        user: AuthUser(
          id: 'mock-user',
          name: name,
          email: email,
          role: role,
          preferences: AuthUserPreferences(
            appLanguageCode: 'pt-PT',
            learningLanguageCode: 'it-IT',
            selectedProfile: role,
            difficultyLevel: 'beginner',
          ),
        ),
      );
    }

    final response = await _client
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/auth/register'),
          headers: AppConfig.jsonHeaders,
          body: jsonEncode({
            'name': name,
            'email': email,
            'password': password,
            'role': role,
            'device': await _deviceKeyService.registrationPayload(),
          }),
        )
        .timeout(AppConfig.apiTimeout);

    return _parseAuthSession(response);
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    if (AppConfig.useMockApi) {
      return AuthSession(
        token: 'mock-token-${DateTime.now().millisecondsSinceEpoch}',
        user: AuthUser(
          id: 'mock-user',
          name: 'Utilizador DailyTalk',
          email: email,
          role: 'student',
          preferences: const AuthUserPreferences(
            appLanguageCode: 'pt-PT',
            learningLanguageCode: 'it-IT',
            selectedProfile: 'student',
            difficultyLevel: 'beginner',
          ),
        ),
      );
    }

    final response = await _client
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/auth/login'),
          headers: AppConfig.jsonHeaders,
          body: jsonEncode({
            'email': email,
            'password': password,
            'device': await _deviceKeyService.registrationPayload(),
          }),
        )
        .timeout(AppConfig.apiTimeout);

    return _parseAuthSession(response);
  }

  Future<PasswordResetRequestResult> requestPasswordReset({
    required String email,
  }) async {
    if (AppConfig.useMockApi) {
      return const PasswordResetRequestResult(
        message:
            'Modo protótipo: usa o código apresentado para testar a recuperação.',
        debugResetToken: 'mock-reset-token',
        isPrototypeDebug: true,
      );
    }

    final response = await _client
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/auth/forgot-password'),
          headers: AppConfig.jsonHeaders,
          body: jsonEncode({'email': email}),
        )
        .timeout(AppConfig.apiTimeout);
    final decoded = _decodeResponse(response);

    return PasswordResetRequestResult(
      message:
          decoded['message']?.toString() ??
          'Se o email existir, serão disponibilizadas instruções de recuperação.',
      debugResetToken: decoded['resetToken']?.toString(),
      isPrototypeDebug: decoded['debug'] == true,
      expiresAt: decoded['expiresAt']?.toString(),
    );
  }

  Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    if (AppConfig.useMockApi) return;

    final response = await _client
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/auth/reset-password'),
          headers: AppConfig.jsonHeaders,
          body: jsonEncode({
            'email': email,
            'token': resetToken,
            'newPassword': newPassword,
          }),
        )
        .timeout(AppConfig.apiTimeout);
    _decodeResponse(response);
  }

  Future<AuthUser> getCurrentUser() async {
    if (AppConfig.useMockApi) {
      return const AuthUser(
        id: 'mock-user',
        name: 'Utilizador DailyTalk',
        email: 'demo@dailytalk.pt',
        role: 'student',
        preferences: AuthUserPreferences(
          appLanguageCode: 'pt-PT',
          learningLanguageCode: 'it-IT',
          selectedProfile: 'student',
          difficultyLevel: 'beginner',
        ),
      );
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/me');
    final response = await _client
        .get(
          uri,
          headers: await _authSessionService.authenticatedHeaders(
            method: 'GET',
            uri: uri,
          ),
        )
        .timeout(AppConfig.apiTimeout);
    final decoded = _decodeResponse(response);
    final user = AuthUser.fromJson(
      Map<String, dynamic>.from(decoded['user'] as Map),
    );
    await _tokenStorage.saveCachedUser(user);
    return user;
  }

  Future<AuthUser> updatePreferences({
    String? appLanguageCode,
    String? learningLanguageCode,
    String? selectedProfile,
    String? difficultyLevel,
  }) async {
    if (AppConfig.useMockApi) {
      return AuthUser(
        id: 'mock-user',
        name: 'Utilizador DailyTalk',
        email: 'demo@dailytalk.pt',
        role: selectedProfile ?? 'student',
        preferences: AuthUserPreferences(
          appLanguageCode: appLanguageCode ?? 'pt-PT',
          learningLanguageCode: learningLanguageCode ?? 'it-IT',
          selectedProfile: selectedProfile ?? 'student',
          difficultyLevel: difficultyLevel ?? 'beginner',
        ),
      );
    }

    final payload = <String, dynamic>{};
    if (appLanguageCode != null) payload['appLanguageCode'] = appLanguageCode;
    if (learningLanguageCode != null) {
      payload['learningLanguageCode'] = learningLanguageCode;
    }
    if (selectedProfile != null) payload['selectedProfile'] = selectedProfile;
    if (difficultyLevel != null) payload['difficultyLevel'] = difficultyLevel;

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/me/preferences');
    final response = await _client
        .put(
          uri,
          headers: await _authSessionService.authenticatedHeaders(
            method: 'PUT',
            uri: uri,
          ),
          body: jsonEncode(payload),
        )
        .timeout(AppConfig.apiTimeout);
    final decoded = _decodeResponse(response);
    final user = AuthUser.fromJson(
      Map<String, dynamic>.from(decoded['user'] as Map),
    );
    await _tokenStorage.saveCachedUser(user);
    return user;
  }

  AuthSession _parseAuthSession(http.Response response) {
    final decoded = _decodeResponse(response);
    final token =
        decoded['accessToken']?.toString() ?? decoded['token']?.toString();
    if (token == null || token.isEmpty) {
      throw Exception('A API não devolveu token de autenticação.');
    }

    return AuthSession(
      token: token,
      refreshToken: decoded['refreshToken']?.toString(),
      accessTokenExpiresAt: decoded['accessTokenExpiresAt']?.toString(),
      deviceId: decoded['deviceId']?.toString(),
      user: AuthUser.fromJson(
        Map<String, dynamic>.from(decoded['user'] as Map),
      ),
    );
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    AppConfig.assertResponseEnvironment(response.headers);

    final Object decoded;
    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } on FormatException {
      throw Exception(
        'A API devolveu uma resposta inválida em JSON (HTTP ${response.statusCode}).',
      );
    }

    if (decoded is! Map) {
      throw Exception('Resposta inválida da API.');
    }
    final map = Map<String, dynamic>.from(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        map['error']?.toString() ?? 'Erro HTTP ${response.statusCode}.',
      );
    }
    return map;
  }
}

/// Resultado de login ou registo.
class AuthSession {
  const AuthSession({
    required this.token,
    required this.user,
    this.refreshToken,
    this.accessTokenExpiresAt,
    this.deviceId,
  });

  final String token;
  final String? refreshToken;
  final String? accessTokenExpiresAt;
  final String? deviceId;
  final AuthUser user;
}

/// Resultado do pedido de recuperação de palavra-passe.
class PasswordResetRequestResult {
  const PasswordResetRequestResult({
    required this.message,
    this.debugResetToken,
    this.isPrototypeDebug = false,
    this.expiresAt,
  });

  final String message;

  /// Token devolvido apenas em modo de protótipo/debug.
  /// Em produção real, este valor deve ser enviado por email e não pela API.
  final String? debugResetToken;

  /// Indica que a API está em modo de protótipo/debug e que o código deve
  /// ser apresentado na interface para permitir testar o fluxo sem email.
  final bool isPrototypeDebug;

  /// Data/hora de expiração do código, quando a API a devolver.
  final String? expiresAt;
}
