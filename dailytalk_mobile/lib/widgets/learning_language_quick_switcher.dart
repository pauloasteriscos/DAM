import 'package:flutter/material.dart';

import '../data/repositories/auth_repository.dart';
import '../l10n/app_localizations.dart';
import '../state/app_learning_language_controller.dart';
import '../state/app_locale_controller.dart';
import '../state/app_session_controller.dart';

/// Bandeira persistente do idioma a praticar.
///
/// O botão mostra apenas a bandeira. Ao tocar, abre um seletor rápido que
/// altera `learningLanguageCode` usando a mesma preferência já usada pelo
/// ecrã Language. O shell observa essa alteração, regressa ao mapa e carrega o
/// percurso oficial associado ao novo idioma.
class LearningLanguageQuickSwitcher extends StatelessWidget {
  const LearningLanguageQuickSwitcher({super.key, this.compact = false});

  final bool compact;

  static const List<_LearningLanguageOption> _languages =
      <_LearningLanguageOption>[
        _LearningLanguageOption(
          code: 'pt-PT',
          name: 'Português',
          assetPath: 'assets/flags/pt-PT.png',
        ),
        _LearningLanguageOption(
          code: 'en-US',
          name: 'English',
          assetPath: 'assets/flags/en-US.png',
        ),
        _LearningLanguageOption(
          code: 'es-ES',
          name: 'Español',
          assetPath: 'assets/flags/es-ES.png',
        ),
        _LearningLanguageOption(
          code: 'fr-FR',
          name: 'Français',
          assetPath: 'assets/flags/fr-FR.png',
        ),
        _LearningLanguageOption(
          code: 'it-IT',
          name: 'Italiano',
          assetPath: 'assets/flags/it-IT.png',
        ),
        _LearningLanguageOption(
          code: 'de-DE',
          name: 'Deutsch',
          assetPath: 'assets/flags/de-DE.png',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final controller = AppLearningLanguageController.instance;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final language = _languageByCode(controller.languageCode);
        final buttonSize = compact ? 40.0 : 44.0;
        final flagWidth = compact ? 27.0 : 30.0;
        final flagHeight = compact ? 18.0 : 20.0;

        return Tooltip(
          message: '${_tr('Idioma a praticar')}: ${language.name}',
          child: Semantics(
            button: true,
            label: '${_tr('Idioma a praticar')}: ${language.name}',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey<String>(
                  'learning-language-flag-${language.code}',
                ),
                borderRadius: BorderRadius.circular(12),
                onTap: () => _openQuickSelector(context),
                child: SizedBox(
                  width: buttonSize,
                  height: buttonSize,
                  child: Center(
                    child: _FlagImage(
                      language: language,
                      width: flagWidth,
                      height: flagHeight,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openQuickSelector(BuildContext context) async {
    final controller = AppLearningLanguageController.instance;
    final appLanguageCode = AppLocaleController.instance.languageCode;
    final selectedCode = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF10232D),
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.78,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                      child: Text(
                        _tr('Idioma a praticar'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: _languages.map((language) {
                    final selected =
                        language.code == controller.languageCode;
                    final sameAsApp = language.code == appLanguageCode;

                    return ListTile(
                      key: ValueKey<String>(
                        'learning-language-option-${language.code}',
                      ),
                      enabled: !sameAsApp,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: _FlagImage(
                        language: language,
                        width: 34,
                        height: 23,
                      ),
                      title: Text(
                        language.name,
                        style: TextStyle(
                          color: sameAsApp ? Colors.white38 : Colors.white,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                      subtitle: sameAsApp
                          ? Text(
                              _tr('Idioma da aplicação'),
                              style: const TextStyle(color: Colors.white38),
                            )
                          : null,
                      trailing: selected
                          ? const Icon(
                              Icons.check_circle,
                              color: Color(0xFF35C8FF),
                            )
                          : null,
                      onTap: sameAsApp
                          ? null
                          : () => Navigator.of(
                              sheetContext,
                            ).pop(language.code),
                    );
                        }).toList(growable: false),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (selectedCode == null ||
        selectedCode == controller.languageCode ||
        !context.mounted) {
      return;
    }

    await _saveLearningLanguage(context, selectedCode);
  }

  Future<void> _saveLearningLanguage(
    BuildContext context,
    String languageCode,
  ) async {
    final controller = AppLearningLanguageController.instance;
    final session = AppSessionController.instance;
    final messenger = ScaffoldMessenger.of(context);
    final normalized = normalizeLearningLanguageCode(languageCode);

    // Mantém a mesma regra já aplicada pelo ecrã Language.
    if (normalized == AppLocaleController.instance.languageCode) {
      messenger.showSnackBar(
        SnackBar(content: Text(_tr('Escolhe dois idiomas diferentes.'))),
      );
      return;
    }

    final shouldSyncRemotely = session.isAuthenticated;

    // A notificação pode fazer o shell regressar imediatamente ao mapa e
    // desmontar o runtime onde o seletor foi aberto. A sincronização remota
    // não pode depender de esse BuildContext continuar montado.
    await controller.setLanguageCode(normalized);

    if (!shouldSyncRemotely) {
      return;
    }

    try {
      final updatedUser = await AuthRepository().updatePreferences(
        learningLanguageCode: normalized,
      );
      final savedCode = normalizeLearningLanguageCode(
        updatedUser.preferences.learningLanguageCode,
      );

      await controller.setLanguageCode(savedCode);
      session.markAuthenticated(updatedUser);
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'Idioma guardado neste dispositivo. A sincronização será tentada mais tarde.',
            ),
          ),
        ),
      );
    }
  }

  static String _tr(String source) {
    return AppTranslations.translate(
      source,
      AppLocaleController.instance.languageCode,
    );
  }

  static _LearningLanguageOption _languageByCode(String code) {
    final normalized = normalizeLearningLanguageCode(code);
    return _languages.firstWhere(
      (language) => language.code == normalized,
      orElse: () => _languages.firstWhere(
        (language) => language.code == 'it-IT',
      ),
    );
  }
}

class _FlagImage extends StatelessWidget {
  const _FlagImage({
    required this.language,
    required this.width,
    required this.height,
  });

  final _LearningLanguageOption language;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24, width: 0.8),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Image.asset(
          language.assetPath,
          width: width,
          height: height,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

class _LearningLanguageOption {
  const _LearningLanguageOption({
    required this.code,
    required this.name,
    required this.assetPath,
  });

  final String code;
  final String name;
  final String assetPath;
}
