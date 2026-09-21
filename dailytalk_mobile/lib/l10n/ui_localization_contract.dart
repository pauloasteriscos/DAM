/// LC-001 — contrato de localização e separação de idiomas.
///
/// O contrato distingue três papéis de texto:
/// - [LocalizationRole.app]: chrome/interface da aplicação;
/// - [LocalizationRole.scaffolding]: instruções, dicas, explicações e feedback;
/// - [LocalizationRole.target]: conteúdo que o utilizador deve aprender,
///   reconhecer ou produzir na língua-alvo.
///
/// APP e SCAFFOLDING são sempre resolvidos por `appLanguageCode`. TARGET é
/// sempre resolvido por `learningLanguageCode`. Widgets não devem decidir
/// esta política ad hoc.
abstract final class UiLocalizationContract {
  static const int schemaVersion = 1;
  static const String fallbackLocale = 'en-US';

  /// Conjunto inicial de chaves semânticas obrigatórias da fundação LC-001.
  ///
  /// Este conjunto cresce à medida que os ecrãs são migrados. Uma versão de
  /// bundle só pode ser ativada quando contém todas as chaves obrigatórias da
  /// versão do contrato que a aplicação exige.
  static const Set<String> requiredKeysV1 = <String>{
    UiTranslationKeys.commonContinue,
    UiTranslationKeys.commonCancel,
    UiTranslationKeys.commonSave,
    UiTranslationKeys.commonRetry,
    UiTranslationKeys.learningMapAllSaved,
    UiTranslationKeys.learningMapNextMission,
    UiTranslationKeys.learningMapAvailable,
    UiTranslationKeys.learningMapUpNext,
    UiTranslationKeys.learningMapJourney,
    UiTranslationKeys.learningMapStage,
    UiTranslationKeys.activityTypeVocabulary,
    UiTranslationKeys.activityTypeDialogue,
    UiTranslationKeys.activityTypeSpeech,
    UiTranslationKeys.systemLanguageSavedSyncDeferred,
    UiTranslationKeys.systemLanguagePairSaved,
    UiTranslationKeys.systemChooseDifferentLanguages,
  };

  static const Set<String> requiredKeysCurrent = requiredKeysV1;
}

/// Papel semântico de um texto visível segundo LC-001.
enum LocalizationRole {
  /// Menus, botões, labels, estados, mensagens e restante chrome da app.
  app,

  /// Instruções, dicas, explicações, ajuda, feedback e descrição pedagógica.
  scaffolding,

  /// Conteúdo que constitui a língua que está a ser aprendida.
  target;

  /// Resolve qual locale governa este papel.
  String locale({
    required String appLanguageCode,
    required String learningLanguageCode,
  }) {
    return switch (this) {
      LocalizationRole.app || LocalizationRole.scaffolding => appLanguageCode,
      LocalizationRole.target => learningLanguageCode,
    };
  }
}

/// Chaves estáveis e independentes de qualquer idioma humano.
abstract final class UiTranslationKeys {
  static const String commonContinue = 'common.continue';
  static const String commonCancel = 'common.cancel';
  static const String commonSave = 'common.save';
  static const String commonRetry = 'common.retry';

  static const String learningMapAllSaved = 'learningMap.allSaved';
  static const String learningMapNextMission = 'learningMap.nextMission';
  static const String learningMapAvailable = 'learningMap.available';
  static const String learningMapUpNext = 'learningMap.upNext';
  static const String learningMapJourney = 'learningMap.journey';
  static const String learningMapStage = 'learningMap.stage';

  static const String activityTypeVocabulary = 'activityType.vocabulary';
  static const String activityTypeDialogue = 'activityType.dialogue';
  static const String activityTypeSpeech = 'activityType.speech';

  static const String systemLanguageSavedSyncDeferred =
      'system.languageSavedSyncDeferred';
  static const String systemLanguagePairSaved = 'system.languagePairSaved';
  static const String systemChooseDifferentLanguages =
      'system.chooseDifferentLanguages';
}
