import '../data/dao/app_settings_dao.dart';
import '../data/database/app_database.dart';
import '../data/repositories/auth_repository.dart';
import 'app_learning_language_controller.dart';
import 'app_locale_controller.dart';
import 'app_session_controller.dart';

/// Par de idiomas escolhido pelo utilizador.
///
/// A seleção é apenas um pedido. A aplicação efetiva a alteração através de
/// [LanguagePreferencesCoordinator], para que todos os pontos da UI usem o
/// mesmo mecanismo de persistência, atualização global e sincronização.
final class LanguagePreferenceSelection {
  const LanguagePreferenceSelection({
    required this.appLanguageCode,
    required this.learningLanguageCode,
  });

  final String appLanguageCode;
  final String learningLanguageCode;
}

/// Resultado da aplicação de um par de idiomas.
final class LanguagePreferenceApplyResult {
  const LanguagePreferenceApplyResult({
    required this.appLanguageCode,
    required this.learningLanguageCode,
    required this.localPersisted,
    required this.remoteSyncAttempted,
    required this.remoteSynced,
  });

  final String appLanguageCode;
  final String learningLanguageCode;
  final bool localPersisted;
  final bool remoteSyncAttempted;
  final bool remoteSynced;
}

/// Único ponto de escrita das preferências de idioma em runtime.
///
/// Tanto o seletor rápido por bandeira como o ecrã Language delegam aqui.
/// Isto evita fluxos concorrentes que atualizem SQLite, controllers e API em
/// ordens diferentes.
final class LanguagePreferencesCoordinator {
  LanguagePreferencesCoordinator._();

  static final LanguagePreferencesCoordinator instance =
      LanguagePreferencesCoordinator._();

  final AuthRepository _authRepository = AuthRepository();

  Future<LanguagePreferenceApplyResult> apply({
    required String appLanguageCode,
    required String learningLanguageCode,
  }) async {
    var normalizedApp = normalizeAppLanguageCode(appLanguageCode);
    var normalizedLearning = normalizeLearningLanguageCode(
      learningLanguageCode,
    );

    if (normalizedApp == normalizedLearning) {
      throw ArgumentError(
        'Os idiomas da aplicação e de prática devem diferir.',
      );
    }

    var localPersisted = await _persistPair(
      appLanguageCode: normalizedApp,
      learningLanguageCode: normalizedLearning,
    );

    // O runtime é atualizado localmente primeiro. A aplicação continua a
    // funcionar offline e a eventual falha da API não reverte a escolha.
    await AppLocaleController.instance.setLanguageCode(
      normalizedApp,
      persist: false,
    );
    await AppLearningLanguageController.instance.setLanguageCode(
      normalizedLearning,
      persist: false,
    );

    final session = AppSessionController.instance;
    if (!session.isAuthenticated) {
      return LanguagePreferenceApplyResult(
        appLanguageCode: normalizedApp,
        learningLanguageCode: normalizedLearning,
        localPersisted: localPersisted,
        remoteSyncAttempted: false,
        remoteSynced: false,
      );
    }

    try {
      final updatedUser = await _authRepository.updatePreferences(
        appLanguageCode: normalizedApp,
        learningLanguageCode: normalizedLearning,
      );

      final remoteApp = normalizeAppLanguageCode(
        updatedUser.preferences.appLanguageCode,
      );
      final remoteLearning = normalizeLearningLanguageCode(
        updatedUser.preferences.learningLanguageCode,
      );

      // Nunca aceitar que uma resposta remota deixe o par inválido. Nesse
      // cenário conservamos a escolha local válida e tratamos a sincronização
      // como incompleta.
      if (remoteApp == remoteLearning) {
        return LanguagePreferenceApplyResult(
          appLanguageCode: normalizedApp,
          learningLanguageCode: normalizedLearning,
          localPersisted: localPersisted,
          remoteSyncAttempted: true,
          remoteSynced: false,
        );
      }

      normalizedApp = remoteApp;
      normalizedLearning = remoteLearning;

      localPersisted = await _persistPair(
        appLanguageCode: normalizedApp,
        learningLanguageCode: normalizedLearning,
      );

      await AppLocaleController.instance.setLanguageCode(
        normalizedApp,
        persist: false,
      );
      await AppLearningLanguageController.instance.setLanguageCode(
        normalizedLearning,
        persist: false,
      );

      session.markAuthenticated(updatedUser);

      return LanguagePreferenceApplyResult(
        appLanguageCode: normalizedApp,
        learningLanguageCode: normalizedLearning,
        localPersisted: localPersisted,
        remoteSyncAttempted: true,
        remoteSynced: true,
      );
    } catch (_) {
      return LanguagePreferenceApplyResult(
        appLanguageCode: normalizedApp,
        learningLanguageCode: normalizedLearning,
        localPersisted: localPersisted,
        remoteSyncAttempted: true,
        remoteSynced: false,
      );
    }
  }

  Future<bool> _persistPair({
    required String appLanguageCode,
    required String learningLanguageCode,
  }) async {
    try {
      final db = await AppDatabase.instance.database;
      final settingsDao = AppSettingsDao(db);
      await settingsDao.setLanguagePair(
        nativeLanguageCode: appLanguageCode,
        targetLanguageCode: learningLanguageCode,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
