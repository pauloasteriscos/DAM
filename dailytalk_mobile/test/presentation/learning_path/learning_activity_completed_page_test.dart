import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_activity_completed_page.dart';
import 'package:dailytalk_mobile/state/app_locale_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await AppLocaleController.instance.setLanguageCode('pt-PT');
  });

  testWidgets(
    'completion page shows runtime summary without progression write',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  key: const ValueKey<String>('open-completion'),
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const LearningActivityCompletedPage(
                          activityType: LearningActivityType.vocabulary,
                          title: 'Palavras de acolhimento',
                          competencyCount: 2,
                          metrics: <LearningCompletionMetric>[
                            LearningCompletionMetric(
                              label: 'Pares',
                              value: '6/6',
                              icon: Icons.link_rounded,
                            ),
                            LearningCompletionMetric(
                              label: 'Tentativas',
                              value: '7',
                              icon: Icons.touch_app_rounded,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('open-completion')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('learning-activity-completed-page')),
        findsOneWidget,
      );
      expect(find.text('Atividade concluída'), findsOneWidget);
      expect(find.text('Palavras de acolhimento'), findsOneWidget);
      expect(find.text('6/6'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('2 competências trabalhadas'), findsOneWidget);

      final continueButton = find.byKey(
        const ValueKey<String>('learning-completion-continue'),
      );
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('open-completion')),
        findsOneWidget,
      );
    },
  );
}
