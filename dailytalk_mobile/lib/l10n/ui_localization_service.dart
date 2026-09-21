import 'package:flutter/foundation.dart';

import '../data/repositories/ui_translation_repository.dart';
import 'ui_localization_contract.dart';

/// Cache de traduções da interface para o locale ativo.
///
/// SQLite é consultado apenas quando o locale/bundle é carregado. Chamadas de
/// [text] fazem lookup O(1) em memória e não executam SQL durante build().
class UiLocalizationService extends ChangeNotifier {
  UiLocalizationService(
    this.repository, {
    this.fallbackLocale = UiLocalizationContract.fallbackLocale,
  });

  final UiTranslationRepository repository;
  final String fallbackLocale;

  String? _locale;
  int? _bundleVersion;
  Map<String, String> _activeCache = const <String, String>{};
  Map<String, String> _fallbackCache = const <String, String>{};

  String? get locale => _locale;
  int? get bundleVersion => _bundleVersion;
  int get cachedKeyCount => _activeCache.length;
  bool get isLoaded => _locale != null;

  Future<void> loadLocale(
    String locale, {
    Set<String> requiredKeys = UiLocalizationContract.requiredKeysCurrent,
  }) async {
    final active = await repository.readActiveBundle(locale);
    if (active == null) {
      throw StateError('Não existe bundle de UI ativo para $locale.');
    }

    final missing = requiredKeys.difference(active.translations.keys.toSet());
    if (missing.isNotEmpty) {
      throw UiTranslationBundleIncomplete(
        locale: active.locale,
        bundleVersion: active.bundleVersion,
        missingKeys: missing,
      );
    }

    Map<String, String> fallback = const <String, String>{};
    if (active.locale.toLowerCase() != fallbackLocale.toLowerCase()) {
      final fallbackBundle = await repository.readActiveBundle(fallbackLocale);
      if (fallbackBundle != null) {
        fallback = fallbackBundle.translations;
      }
    }

    _locale = active.locale;
    _bundleVersion = active.bundleVersion;
    _activeCache = Map<String, String>.unmodifiable(active.translations);
    _fallbackCache = Map<String, String>.unmodifiable(fallback);
    notifyListeners();
  }

  String text(
    String key, {
    Map<String, Object?> parameters = const <String, Object?>{},
  }) {
    if (!isLoaded) {
      throw StateError('UiLocalizationService ainda não foi carregado.');
    }

    final cached = _activeCache[key] ?? _fallbackCache[key];
    if (cached == null) {
      throw StateError(
        'Chave de tradução de UI ausente: $key (locale=$_locale).',
      );
    }

    var resolved = cached;
    for (final entry in parameters.entries) {
      resolved = resolved.replaceAll('{${entry.key}}', '${entry.value ?? ''}');
    }
    return resolved;
  }

  bool contains(String key) =>
      _activeCache.containsKey(key) || _fallbackCache.containsKey(key);

  void clear() {
    _locale = null;
    _bundleVersion = null;
    _activeCache = const <String, String>{};
    _fallbackCache = const <String, String>{};
    notifyListeners();
  }
}
