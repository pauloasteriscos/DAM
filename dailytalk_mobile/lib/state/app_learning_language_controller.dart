import 'package:flutter/foundation.dart';

import '../data/dao/app_settings_dao.dart';
import '../data/database/app_database.dart';

/// Idiomas atualmente disponibilizados para prática no DailyTalk.pt.
const List<String> supportedLearningLanguageCodes = <String>[
  'pt-PT',
  'en-US',
  'es-ES',
  'fr-FR',
  'it-IT',
  'de-DE',
];

/// Estado global do idioma que o utilizador pretende praticar.
///
/// Este controlador ainda não escolhe o Learning Path. Nesta etapa ele apenas
/// representa e persiste a preferência `target_language_code`. A ligação
/// `learningLanguageCode -> learningPathId` pertence à Fase 4.7B.2A.
class AppLearningLanguageController extends ChangeNotifier {
  AppLearningLanguageController._();

  static final AppLearningLanguageController instance =
      AppLearningLanguageController._();

  String _languageCode = 'it-IT';

  String get languageCode => _languageCode;

  /// Carrega a preferência local antes da primeira apresentação da aplicação.
  Future<void> initialize() async {
    try {
      final db = await AppDatabase.instance.database;
      final settingsDao = AppSettingsDao(db);
      _languageCode = normalizeLearningLanguageCode(
        await settingsDao.getTargetLanguageCode(),
      );
    } catch (_) {
      _languageCode = 'it-IT';
    }
  }

  /// Atualiza imediatamente o idioma observado pela interface.
  ///
  /// Quando [persist] é verdadeiro, guarda também a preferência local. A
  /// sincronização remota permanece responsabilidade do fluxo que originou a
  /// alteração, preservando a lógica atual do ecrã Language.
  Future<void> setLanguageCode(
    String languageCode, {
    bool persist = true,
  }) async {
    final normalized = normalizeLearningLanguageCode(languageCode);

    if (_languageCode != normalized) {
      _languageCode = normalized;
      notifyListeners();
    }

    if (!persist) {
      return;
    }

    try {
      final db = await AppDatabase.instance.database;
      final settingsDao = AppSettingsDao(db);
      await settingsDao.setValue(
        key: AppSettingsDao.targetLanguageKey,
        value: normalized,
      );
    } catch (_) {
      // A interface já foi atualizada. Uma falha de persistência local não
      // deve impedir a utilização da aplicação.
    }
  }
}

String normalizeLearningLanguageCode(String? languageCode) {
  if (languageCode == null || languageCode.trim().isEmpty) {
    return 'it-IT';
  }

  final normalized = languageCode.replaceAll('_', '-');

  for (final supportedCode in supportedLearningLanguageCodes) {
    if (supportedCode.toLowerCase() == normalized.toLowerCase()) {
      return supportedCode;
    }
  }

  final baseLanguage = normalized.split('-').first.toLowerCase();
  return supportedLearningLanguageCodes.firstWhere(
    (code) => code.split('-').first.toLowerCase() == baseLanguage,
    orElse: () => 'it-IT',
  );
}
