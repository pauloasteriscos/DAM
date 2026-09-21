import 'app_localizations.dart';
import '../state/app_locale_controller.dart';

/// Ponte de migração para LC-001.
///
/// Ecrãs migrados usam primeiro o bundle SQLite/cache por chave semântica.
/// O tradutor legado só é consultado se a infraestrutura dinâmica não tiver
/// conseguido inicializar, mantendo a aplicação utilizável durante a migração.
abstract final class UiTextResolver {
  static String text(
    String key, {
    required String legacySource,
    Map<String, Object?> parameters = const <String, Object?>{},
  }) {
    final controller = AppLocaleController.instance;

    if (controller.isDynamicLocalizationReady) {
      return controller.uiLocalization.text(key, parameters: parameters);
    }

    return AppTranslations.translate(
      legacySource,
      controller.languageCode,
      parameters: parameters,
    );
  }
}
