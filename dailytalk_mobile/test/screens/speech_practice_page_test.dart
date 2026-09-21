import 'package:dailytalk_mobile/domain/learning/learning_models.dart';
import 'package:dailytalk_mobile/screens/speech_practice_page.dart';
import 'package:dailytalk_mobile/state/app_learning_language_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('schema v2 speech runtime consumes authored prompts in order', (
    tester,
  ) async {
    final execution = SpeechActivityExecution(
      prompts: <SpeechExecutionPrompt>[
        SpeechExecutionPrompt(
          id: 'one',
          text: LocalizedText(<String, String>{
            'pt-PT': 'Repete: Bonjour !',
            'fr-FR': 'Bonjour !',
          }),
        ),
        SpeechExecutionPrompt(
          id: 'two',
          text: LocalizedText(<String, String>{
            'pt-PT': 'Repete: Merci !',
            'fr-FR': 'Merci !',
          }),
        ),
      ],
    );

    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'PT'),
        home: SpeechPracticePage(execution: execution),
      ),
    );

    expect(find.text('Repete: Bonjour !'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('speech-confirm-repeat')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('speech-confirm-repeat')),
    );
    await tester.pump();
    expect(find.text('Repete: Merci !'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('speech-confirm-repeat')),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('learning-activity-completed-page')),
      findsOneWidget,
    );
    expect(find.text('Atividade concluída'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('legacy speech remains executable without schema-v2 payload', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SpeechPracticePage()));

    expect(find.text('Bonjour !'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('speech-confirm-repeat')),
      findsOneWidget,
    );
  });

  testWidgets(
    'schema v2 speech resolves authored prompt in practice language',
    (tester) async {
      await AppLearningLanguageController.instance.setLanguageCode(
        'fr-FR',
        persist: false,
      );
      addTearDown(() async {
        await AppLearningLanguageController.instance.setLanguageCode(
          'it-IT',
          persist: false,
        );
      });

      final execution = SpeechActivityExecution(
        prompts: <SpeechExecutionPrompt>[
          SpeechExecutionPrompt(
            id: 'one',
            text: LocalizedText(<String, String>{
              'pt-PT': 'Repete: Bonjour !',
              'fr-FR': 'Bonjour !',
            }),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pt', 'PT'),
          home: SpeechPracticePage(execution: execution),
        ),
      );

      expect(find.text('Bonjour !'), findsOneWidget);
      expect(find.text('Repete: Bonjour !'), findsNothing);
    },
  );
}
