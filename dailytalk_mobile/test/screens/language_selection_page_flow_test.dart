import 'package:dailytalk_mobile/screens/language_selection_page.dart';
import 'package:dailytalk_mobile/state/app_learning_language_controller.dart';
import 'package:dailytalk_mobile/state/app_locale_controller.dart';
import 'package:dailytalk_mobile/state/app_session_controller.dart';
import 'package:dailytalk_mobile/state/language_preferences_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    AppSessionController.instance.startTestMode();
    await AppLocaleController.instance.setLanguageCode('pt-PT');
    await AppLearningLanguageController.instance.setLanguageCode(
      'it-IT',
      persist: false,
    );
  });

  testWidgets('Language devolve a selecao antes de alterar o controller global', (
    tester,
  ) async {
    LanguagePreferenceSelection? selection;

    await tester.pumpWidget(
      AppLocaleScope(
        controller: AppLocaleController.instance,
        child: AppSessionScope(
          controller: AppSessionController.instance,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    key: const ValueKey<String>('open-language'),
                    onPressed: () async {
                      selection = await Navigator.of(context)
                          .push<LanguagePreferenceSelection>(
                            MaterialPageRoute<LanguagePreferenceSelection>(
                              builder: (_) => const LanguageSelectionPage(),
                            ),
                          );
                    },
                    child: const Text('Language'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('open-language')));
    await tester.pumpAndSettle();

    final learningDropdown = find.byKey(
      const ValueKey<String>('language-learning-dropdown'),
    );
    expect(learningDropdown, findsOneWidget);

    await tester.ensureVisible(learningDropdown);
    await tester.pumpAndSettle();
    await tester.tap(learningDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('🇺🇸  English').last);
    await tester.pumpAndSettle();

    final save = find.byKey(const ValueKey<String>('language-save'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(selection, isNotNull);
    expect(selection!.appLanguageCode, 'pt-PT');
    expect(selection!.learningLanguageCode, 'en-US');

    // A rota Language apenas devolve a intenção. A alteração global acontece
    // depois, através do coordenador único chamado pelo fluxo que abriu a rota.
    expect(AppLearningLanguageController.instance.languageCode, 'it-IT');
  });

  testWidgets(
    'fluxo Language aberto dentro de Navigator interno usa Navigator raiz',
    (tester) async {
      final rootNavigatorKey = GlobalKey<NavigatorState>();
      final innerNavigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        AppLocaleScope(
          controller: AppLocaleController.instance,
          child: AppSessionScope(
            controller: AppSessionController.instance,
            child: MaterialApp(
              navigatorKey: rootNavigatorKey,
              home: Navigator(
                key: innerNavigatorKey,
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (innerContext) => Scaffold(
                    body: Center(
                      child: FilledButton(
                        key: const ValueKey<String>('open-root-language-flow'),
                        onPressed: () =>
                            openLanguageSelectionFlow(innerContext),
                        child: const Text('Language'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('open-root-language-flow')),
      );
      await tester.pumpAndSettle();

      expect(rootNavigatorKey.currentState!.canPop(), isTrue);
      expect(innerNavigatorKey.currentState!.canPop(), isFalse);

      final learningDropdown = find.byKey(
        const ValueKey<String>('language-learning-dropdown'),
      );
      await tester.ensureVisible(learningDropdown);
      await tester.pumpAndSettle();
      await tester.tap(learningDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('🇺🇸  English').last);
      await tester.pumpAndSettle();

      final save = find.byKey(const ValueKey<String>('language-save'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(AppLearningLanguageController.instance.languageCode, 'en-US');
      expect(innerNavigatorKey.currentState!.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'coordenador rejeita app e pratica com o mesmo idioma antes de persistir',
    () async {
      await expectLater(
        LanguagePreferencesCoordinator.instance.apply(
          appLanguageCode: 'pt-PT',
          learningLanguageCode: 'pt-PT',
        ),
        throwsArgumentError,
      );
    },
  );
}
