import '../../models/auth_user.dart';
import '../api/auth_api_service.dart';
import '../storage/auth_token_storage.dart';

/// Repository de autenticação.
///
/// Centraliza login, registo, validação de sessão, recuperação de palavra-passe
/// e logout.
class AuthRepository {
  AuthRepository({
    AuthApiService? apiService,
    AuthTokenStorage? tokenStorage,
  })  : _tokenStorage = tokenStorage ?? AuthTokenStorage(),
        _apiService = apiService ?? AuthApiService(tokenStorage: tokenStorage);

  final AuthApiService _apiService;
  final AuthTokenStorage _tokenStorage;

  Future<bool> isLoggedIn() async {
    final token = await _tokenStorage.readToken();
    return token != null && token.isNotEmpty;
  }

  Future<AuthUser?> getCurrentUser() async {
    if (!await isLoggedIn()) {
      return null;
    }

    return _apiService.getCurrentUser();
  }

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final session = await _apiService.login(email: email, password: password);
    await _tokenStorage.saveToken(session.token);
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
    await _tokenStorage.saveToken(session.token);
    return session.user;
  }

  Future<PasswordResetRequestResult> requestPasswordReset({
    required String email,
  }) {
    return _apiService.requestPasswordReset(email: email);
  }

  Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) {
    return _apiService.resetPassword(
      email: email,
      resetToken: resetToken,
      newPassword: newPassword,
    );
  }

  Future<AuthUser> updatePreferences({
    String? appLanguageCode,
    String? learningLanguageCode,
    String? selectedProfile,
    String? difficultyLevel,
  }) {
    return _apiService.updatePreferences(
      appLanguageCode: appLanguageCode,
      learningLanguageCode: learningLanguageCode,
      selectedProfile: selectedProfile,
      difficultyLevel: difficultyLevel,
    );
  }

  Future<void> logout() async {
    await _tokenStorage.deleteToken();
  }
}
