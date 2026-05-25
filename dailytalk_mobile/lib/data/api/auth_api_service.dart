import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../../models/auth_user.dart';
import '../storage/auth_token_storage.dart';

/// Serviço de autenticação da API DailyTalk.pt.
class AuthApiService {
  AuthApiService({http.Client? client, AuthTokenStorage? tokenStorage})
    : _client = client ?? http.Client(),
      _tokenStorage = tokenStorage ?? AuthTokenStorage();

  final http.Client _client;
  final AuthTokenStorage _tokenStorage;

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
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': name,
            'email': email,
            'password': password,
            'role': role,
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
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(AppConfig.apiTimeout);

    return _parseAuthSession(response);
  }

  Future<PasswordResetRequestResult> requestPasswordReset({
    required String email,
  }) async {
    if (AppConfig.useMockApi) {
      return const PasswordResetRequestResult(
        message: 'Modo mock: usa o código mock-reset-token para testar.',
        debugResetToken: 'mock-reset-token',
      );
    }

    final response = await _client
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/auth/forgot-password'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email}),
        )
        .timeout(AppConfig.apiTimeout);

    final decoded = _decodeResponse(response);
    return PasswordResetRequestResult(
      message: decoded['message']?.toString() ??
          'Se o email existir, serão enviadas instruções de recuperação.',
      debugResetToken: decoded['resetToken']?.toString(),
    );
  }

  Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    if (AppConfig.useMockApi) {
      return;
    }

    final response = await _client
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/auth/reset-password'),
          headers: const {'Content-Type': 'application/json'},
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

    final response = await _client
        .get(
          Uri.parse('${AppConfig.apiBaseUrl}/me'),
          headers: await _authHeaders(),
        )
        .timeout(AppConfig.apiTimeout);

    final decoded = _decodeResponse(response);
    return AuthUser.fromJson(Map<String, dynamic>.from(decoded['user'] as Map));
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

    void addIfNotNull(String key, Object? value) {
      if (value != null) {
        payload[key] = value;
      }
    }

    addIfNotNull('appLanguageCode', appLanguageCode);
    addIfNotNull('learningLanguageCode', learningLanguageCode);
    addIfNotNull('selectedProfile', selectedProfile);
    addIfNotNull('difficultyLevel', difficultyLevel);

    final response = await _client
        .put(
          Uri.parse('${AppConfig.apiBaseUrl}/me/preferences'),
          headers: await _authHeaders(),
          body: jsonEncode(payload),
        )
        .timeout(AppConfig.apiTimeout);

    final decoded = _decodeResponse(response);
    return AuthUser.fromJson(Map<String, dynamic>.from(decoded['user'] as Map));
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _tokenStorage.readToken();

    if (token == null || token.isEmpty) {
      throw Exception('Sessão expirada. Inicia sessão novamente.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  AuthSession _parseAuthSession(http.Response response) {
    final decoded = _decodeResponse(response);
    final token = decoded['token']?.toString();

    if (token == null || token.isEmpty) {
      throw Exception('A API não devolveu token de autenticação.');
    }

    return AuthSession(
      token: token,
      user: AuthUser.fromJson(
        Map<String, dynamic>.from(decoded['user'] as Map),
      ),
    );
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map && decoded['error'] != null
          ? decoded['error'].toString()
          : 'Erro HTTP ${response.statusCode}.';
      throw Exception(message);
    }

    if (decoded is! Map) {
      throw Exception('Resposta inválida da API.');
    }

    return Map<String, dynamic>.from(decoded);
  }
}

/// Resultado de login ou registo.
class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final AuthUser user;
}

/// Resultado do pedido de recuperação de palavra-passe.
class PasswordResetRequestResult {
  const PasswordResetRequestResult({
    required this.message,
    this.debugResetToken,
  });

  final String message;

  /// Token devolvido apenas em modo de protótipo/debug.
  /// Em produção real, este valor deve ser enviado por email e não pela API.
  final String? debugResetToken;
}
