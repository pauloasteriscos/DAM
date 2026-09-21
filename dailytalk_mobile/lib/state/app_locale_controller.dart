import 'package:flutter/widgets.dart';

import '../data/dao/app_settings_dao.dart';
import '../data/database/app_database.dart';
import '../data/repositories/ui_translation_repository.dart';
import '../data/services/ui_translation_bootstrap_service.dart';
import '../l10n/ui_localization_service.dart';

/// Idiomas atualmente suportados pela interface do DailyTalk.pt.
const List<String> supportedAppLanguageCodes = <String>[
  'pt-PT',
  'en-US',
  'es-ES',
  'fr-FR',
  'it-IT',
  'de-DE',
];

/// Controlador global do idioma da interface.
///
/// Implementa o padrão Observer através de [ChangeNotifier]. Sempre que o
/// idioma muda, os ecrãs que observam [AppLocaleScope] são reconstruídos.
class AppLocaleController extends ChangeNotifier {
  AppLocaleController._();

  static final AppLocaleController instance = AppLocaleController._();

  String _languageCode = 'pt-PT';
  UiLocalizationService? _uiLocalizationService;

  String get languageCode => _languageCode;
  bool get isDynamicLocalizationReady => _uiLocalizationService != null;

  UiLocalizationService get uiLocalization {
    final service = _uiLocalizationService;
    if (service == null) {
      throw StateError('UiLocalizationService ainda não foi inicializado.');
    }
    return service;
  }

  Locale get locale {
    final parts = _languageCode.split('-');
    return Locale(parts.first, parts.length > 1 ? parts[1] : null);
  }

  /// Carrega o idioma guardado localmente antes de apresentar a aplicação.
  Future<void> initialize() async {
    final db = await AppDatabase.instance.database;

    try {
      final settingsDao = AppSettingsDao(db);
      _languageCode = normalizeAppLanguageCode(
        await settingsDao.getNativeLanguageCode(),
      );
    } catch (_) {
      _languageCode = 'pt-PT';
    }

    // LC-001.2: instala os seis bundles offline no SQLite e carrega o locale
    // ativo em memória antes do primeiro frame. Durante a migração gradual,
    // uma falha desta infraestrutura não impede o tradutor legado de manter a
    // aplicação utilizável; ecrãs já migrados consultam [uiLocalization].
    try {
      final repository = UiTranslationRepository(db);
      await UiTranslationBootstrapService(
        repository: repository,
      ).ensureLocalBundles();

      final service = UiLocalizationService(repository);
      await service.loadLocale(_languageCode);
      _uiLocalizationService = service;
    } catch (error, stackTrace) {
      _uiLocalizationService = null;
      debugPrint('Falha ao preparar localização dinâmica LC-001: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Atualiza imediatamente o idioma observado por toda a aplicação.
  ///
  /// Quando [persist] é verdadeiro, guarda também a preferência local. A
  /// página Language normalmente já guarda o par completo de idiomas e, por
  /// isso, chama este método sem persistência adicional.
  Future<void> setLanguageCode(
    String languageCode, {
    bool persist = false,
  }) async {
    final normalized = normalizeAppLanguageCode(languageCode);

    if (_languageCode != normalized) {
      // Se LC-001 já estiver pronto, troca primeiro o cache e só depois
      // notifica a árvore. Nenhum frame observa locale novo com bundle antigo.
      final localization = _uiLocalizationService;
      if (localization != null) {
        await localization.loadLocale(normalized);
      }

      _languageCode = normalized;
      notifyListeners();
    }

    if (persist) {
      try {
        final db = await AppDatabase.instance.database;
        final settingsDao = AppSettingsDao(db);
        await settingsDao.setValue(
          key: AppSettingsDao.nativeLanguageKey,
          value: normalized,
        );
      } catch (_) {
        // A interface já foi atualizada. Uma falha de persistência local não
        // deve bloquear o utilizador nem reverter o idioma em memória.
      }
    }
  }
}

String normalizeAppLanguageCode(String? languageCode) {
  if (languageCode == null || languageCode.trim().isEmpty) {
    return 'pt-PT';
  }

  final normalized = languageCode.replaceAll('_', '-');

  for (final supportedCode in supportedAppLanguageCodes) {
    if (supportedCode.toLowerCase() == normalized.toLowerCase()) {
      return supportedCode;
    }
  }

  final baseLanguage = normalized.split('-').first.toLowerCase();
  return supportedAppLanguageCodes.firstWhere(
    (code) => code.split('-').first.toLowerCase() == baseLanguage,
    orElse: () => 'pt-PT',
  );
}

/// Escopo que disponibiliza o controlador de idioma à árvore de widgets.
class AppLocaleScope extends InheritedNotifier<AppLocaleController> {
  const AppLocaleScope({
    super.key,
    required AppLocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLocaleController watch(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppLocaleScope>();

    assert(
      scope != null,
      'AppLocaleScope não encontrado na árvore de widgets.',
    );

    return scope!.notifier!;
  }

  static AppLocaleController read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<AppLocaleScope>();

    assert(
      element != null,
      'AppLocaleScope não encontrado na árvore de widgets.',
    );

    final scope = element!.widget as AppLocaleScope;
    return scope.notifier!;
  }
}
