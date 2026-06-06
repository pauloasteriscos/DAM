import 'package:flutter/widgets.dart';

import '../data/dao/app_settings_dao.dart';
import '../data/database/app_database.dart';

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

  String get languageCode => _languageCode;

  Locale get locale {
    final parts = _languageCode.split('-');
    return Locale(parts.first, parts.length > 1 ? parts[1] : null);
  }

  /// Carrega o idioma guardado localmente antes de apresentar a aplicação.
  Future<void> initialize() async {
    try {
      final db = await AppDatabase.instance.database;
      final settingsDao = AppSettingsDao(db);
      _languageCode = normalizeAppLanguageCode(
        await settingsDao.getNativeLanguageCode(),
      );
    } catch (_) {
      _languageCode = 'pt-PT';
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
    final element =
        context.getElementForInheritedWidgetOfExactType<AppLocaleScope>();

    assert(
      element != null,
      'AppLocaleScope não encontrado na árvore de widgets.',
    );

    final scope = element!.widget as AppLocaleScope;
    return scope.notifier!;
  }
}
