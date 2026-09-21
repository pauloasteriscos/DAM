import 'package:dailytalk_mobile/domain/learning/learning_models.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_vocabulary_runtime_page.dart';
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
    'schema-v2 vocabulary renders authored execution without legacy bank',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: LearningVocabularyRuntimePage(
            execution: _execution(),
            contentDefaultLocale: 'pt-PT',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Combina os pares'), findsOneWidget);
      expect(find.text('Olá'), findsOneWidget);
      expect(find.text('Ciao'), findsOneWidget);
      expect(find.text('Obrigado'), findsOneWidget);
      expect(find.text('Grazie'), findsOneWidget);
      expect(find.text('Estou cansado'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('mission-vocab-left-hello')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('mission-vocab-right-hello')),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey<String>('mission-vocab-left-thanks')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('mission-vocab-right-thanks')),
      );
      await tester.pump();

      expect(find.text('Prática terminada'), findsOneWidget);

      final complete = find.byKey(
        const ValueKey<String>('mission-vocab-complete'),
      );
      expect(complete, findsOneWidget);
      await tester.tap(complete);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('learning-activity-completed-page')),
        findsOneWidget,
      );
      expect(find.text('Atividade concluída'), findsOneWidget);
      expect(find.text('2/2'), findsOneWidget);
    },
  );

  testWidgets('target language text follows the practice-language controller', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LearningVocabularyRuntimePage(
          execution: _execution(),
          contentDefaultLocale: 'pt-PT',
        ),
      ),
    );

    expect(find.text('Ciao'), findsOneWidget);
    expect(find.text('Hello'), findsNothing);

    await AppLearningLanguageController.instance.setLanguageCode(
      'en-US',
      persist: false,
    );
    await tester.pump();

    expect(find.text('Ciao'), findsNothing);
    expect(find.text('Hello'), findsOneWidget);
  });
}

VocabularyActivityExecution _execution() {
  return VocabularyActivityExecution(
    items: <VocabularyExecutionItem>[
      VocabularyExecutionItem(
        id: 'hello',
        text: LocalizedText(<String, String>{
          'pt-PT': 'Olá',
          'it-IT': 'Ciao',
          'en-US': 'Hello',
        }),
      ),
      VocabularyExecutionItem(
        id: 'thanks',
        text: LocalizedText(<String, String>{
          'pt-PT': 'Obrigado',
          'it-IT': 'Grazie',
          'en-US': 'Thank you',
        }),
      ),
    ],
  );
}
