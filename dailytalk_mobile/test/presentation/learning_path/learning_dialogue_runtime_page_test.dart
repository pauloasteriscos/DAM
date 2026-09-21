import 'package:dailytalk_mobile/domain/learning/learning_models.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_dialogue_runtime_page.dart';
import 'package:dailytalk_mobile/state/app_learning_language_controller.dart';
import 'package:dailytalk_mobile/state/app_locale_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await AppLocaleController.instance.setLanguageCode('pt-PT');
    await AppLearningLanguageController.instance.setLanguageCode(
      'it-IT',
      persist: false,
    );
  });

  testWidgets(
    'schema-v2 dialogue renders authored scenario and completes visual flow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: LearningDialogueRuntimePage(
            execution: _execution(),
            contentDefaultLocale: 'pt-PT',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Primeira apresentação'), findsOneWidget);
      expect(find.text('Apresenta-te ao anfitrião.'), findsOneWidget);
      expect(find.text('Ciao! Come ti chiami?'), findsOneWidget);
      expect(find.text('Como te apresentas?'), findsOneWidget);
      expect(find.text('Mi chiamo Paulo.'), findsOneWidget);
      expect(find.text('Primeiro intervalo na escola'), findsNothing);

      final correctOption = find.byKey(
        const ValueKey<String>('mission-dialogue-option-turn-1-correct'),
      );
      final primaryButton = find.byKey(
        const ValueKey<String>('mission-dialogue-primary'),
      );

      await tester.ensureVisible(correctOption);
      await tester.tap(correctOption);
      await tester.pump();

      await tester.ensureVisible(primaryButton);
      await tester.pumpAndSettle();
      await tester.tap(primaryButton);
      await tester.pump();

      expect(find.text('Boa escolha.'), findsOneWidget);

      await tester.ensureVisible(primaryButton);
      await tester.pumpAndSettle();
      await tester.tap(primaryButton);
      await tester.pump();

      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('learning-activity-completed-page')),
        findsOneWidget,
      );
      expect(find.text('Atividade concluída'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
    },
  );
}

DialogueActivityExecution _execution() {
  return DialogueActivityExecution(
    scenarioTitle: LocalizedText(<String, String>{
      'pt-PT': 'Primeira apresentação',
      'it-IT': 'Prima presentazione',
    }),
    scenarioDescription: LocalizedText(<String, String>{
      'pt-PT': 'Apresenta-te ao anfitrião.',
      'it-IT': 'Presentati alla famiglia ospitante.',
    }),
    turns: <DialogueExecutionTurn>[
      DialogueExecutionTurn(
        id: 'turn-1',
        partnerMessage: LocalizedText(<String, String>{
          'pt-PT': 'Olá! Como te chamas?',
          'it-IT': 'Ciao! Come ti chiami?',
        }),
        prompt: LocalizedText(<String, String>{
          'pt-PT': 'Como te apresentas?',
          'it-IT': 'Come ti presenti?',
        }),
        correctReply: LocalizedText(<String, String>{
          'pt-PT': 'Chamo-me Paulo.',
          'it-IT': 'Mi chiamo Paulo.',
        }),
        distractors: <LocalizedText>[
          LocalizedText(<String, String>{
            'pt-PT': 'Até logo.',
            'it-IT': 'A dopo.',
          }),
          LocalizedText(<String, String>{
            'pt-PT': 'Não sei.',
            'it-IT': 'Non lo so.',
          }),
        ],
      ),
    ],
  );
}
