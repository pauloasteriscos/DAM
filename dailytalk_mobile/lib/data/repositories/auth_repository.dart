import '../../models/auth_user.dart';
import '../api/auth_api_service.dart';
import '../storage/auth_token_storage.dart';

/// Repository de autenticação.
///
/// Centraliza login, registo, validação de sessão, recuperação de palavra-passe
/// e logout.
class AuthRepository {
  AuthRepository({AuthApiService? apiService, AuthTokenStorage? tokenStorage})
    : _tokenStorage = tokenStorage ?? AuthTokenStorage(),
      _apiService = apiService ?? AuthApiService(tokenStorage: tokenStorage);

  final AuthApiService _apiService;
  final AuthTokenStorage _tokenStorage;

  Future<bool> isLoggedIn() async {
    final token = await _tokenStorage.readToken();
    if (token != null && token.isNotEmpty) return true;

    // Permite recuperar silenciosamente uma escrita interrompida em que o
    // refresh token e a identidade do dispositivo já ficaram persistidos.
    return _tokenStorage.hasBoundSession();
  }

  Future<AuthUser?> getCurrentUser() async {
    if (!await isLoggedIn()) {
      return null;
    }

    try {
      return await _apiService.getCurrentUser();
    } catch (_) {
      // Uma falha de rede, expiração técnica ou atualização do backend não
      // elimina a sessão local nem impede a abertura imediata da aplicação.
      return _tokenStorage.readCachedUser();
    }
  }

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final session = await _apiService.login(email: email, password: password);
    await _persistSession(session);
    return session.user;
  }

  Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
    String role = 'student',
  }) async {
    final session = await _apiService.register(
      name: name,
      email: email,
      password: password,
      role: role,
    );
    await _persistSession(session);
    return session.user;
  }

  Future<void> _persistSession(AuthSession session) async {
    await _tokenStorage.saveSession(
      accessToken: session.token,
      refreshToken: session.refreshToken,
      accessTokenExpiresAt: session.accessTokenExpiresAt,
      deviceId: session.deviceId,
    );
    await _tokenStorage.saveCachedUser(session.user);
  }

  Future<PasswordResetRequestResult> requestPasswordReset({
    required String email,
  }) => _apiService.requestPasswordReset(email: email);

  Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) => _apiService.resetPassword(
    email: email,
    resetToken: resetToken,
    newPassword: newPassword,
  );

  Future<AuthUser> updatePreferences({
    String? appLanguageCode,
    String? learningLanguageCode,
    String? selectedProfile,
    String? difficultyLevel,
  }) => _apiService.updatePreferences(
    appLanguageCode: appLanguageCode,
    learningLanguageCode: learningLanguageCode,
    selectedProfile: selectedProfile,
    difficultyLevel: difficultyLevel,
  );

  Future<void> logout() => _tokenStorage.clearSession();
}
