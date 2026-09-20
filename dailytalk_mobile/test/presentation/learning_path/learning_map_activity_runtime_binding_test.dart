import 'package:dailytalk_mobile/domain/learning/learning_models.dart';
import 'package:dailytalk_mobile/screens/dialogue_page.dart';
import 'package:dailytalk_mobile/screens/quiz_page.dart';
import 'package:dailytalk_mobile/screens/revision_page.dart';
import 'package:dailytalk_mobile/screens/vocabulary_pairs_page.dart';
import 'package:dailytalk_mobile/state/app_locale_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildTestApp(Widget home) {
  return AppLocaleScope(
    controller: AppLocaleController.instance,
    child: MaterialApp(home: home),
  );
}

void main() {
  testWidgets(
    'vocabulary mission renders authored execution instead of legacy bank',
    (tester) async {
      final execution = VocabularyActivityExecution(
        items: <VocabularyExecutionItem>[
          VocabularyExecutionItem(
            id: 'sentinel-item',
            text: LocalizedText(<String, String>{
              'pt-PT': 'FONTE_47A2',
              'fr-FR': 'ALVO_47A2',
            }),
          ),
        ],
      );

      await tester.pumpWidget(
        _buildTestApp(
          VocabularyPairsPage(
            userLanguageCode: 'pt-PT',
            learningLanguageCode: 'fr-FR',
            execution: execution,
            contentDefaultLocale: 'pt-PT',
          ),
        ),
      );

      expect(find.text('FONTE_47A2'), findsOneWidget);
      expect(find.text('ALVO_47A2'), findsOneWidget);
    },
  );

  testWidgets('dialogue mission renders authored scenario', (tester) async {
    final execution = DialogueActivityExecution(
      scenarioTitle: LocalizedText(<String, String>{
        'pt-PT': 'CENARIO_DIALOGO_47A2',
        'fr-FR': 'SCENARIO_DIALOGUE_47A2',
      }),
      scenarioDescription: LocalizedText(<String, String>{
        'pt-PT': 'DESCRICAO_DIALOGO_47A2',
        'fr-FR': 'DESCRIPTION_DIALOGUE_47A2',
      }),
      turns: <DialogueExecutionTurn>[
        DialogueExecutionTurn(
          id: 'turn-1',
          partnerMessage: LocalizedText(<String, String>{
            'pt-PT': 'Olá',
            'fr-FR': 'Bonjour',
          }),
          prompt: LocalizedText(<String, String>{
            'pt-PT': 'Responde',
            'fr-FR': 'Réponds',
          }),
          correctReply: LocalizedText(<String, String>{
            'pt-PT': 'Obrigado',
            'fr-FR': 'Merci',
          }),
          distractors: <LocalizedText>[
            LocalizedText(<String, String>{
              'pt-PT': 'Adeus',
              'fr-FR': 'Au revoir',
            }),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      _buildTestApp(
        DialoguePage(
          userLanguageCode: 'pt-PT',
          learningLanguageCode: 'fr-FR',
          execution: execution,
          contentDefaultLocale: 'pt-PT',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CENARIO_DIALOGO_47A2'), findsOneWidget);
    expect(find.text('DESCRICAO_DIALOGO_47A2'), findsOneWidget);
  });

  testWidgets('quiz mission renders authored question', (tester) async {
    final execution = QuizActivityExecution(
      questions: <QuizExecutionQuestion>[
        QuizExecutionQuestion(
          id: 'question-1',
          category: LocalizedText(<String, String>{
            'pt-PT': 'CATEGORIA_QUIZ_47A2',
          }),
          scenario: LocalizedText(<String, String>{
            'pt-PT': 'CENARIO_QUIZ_47A2',
          }),
          prompt: LocalizedText(<String, String>{'pt-PT': 'PROMPT_QUIZ_47A2'}),
          correctAnswer: LocalizedText(<String, String>{
            'pt-PT': 'Certa',
            'fr-FR': 'Correcte',
          }),
          distractors: <LocalizedText>[
            LocalizedText(<String, String>{
              'pt-PT': 'Errada',
              'fr-FR': 'Fausse',
            }),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      _buildTestApp(
        QuizPage(
          userLanguageCode: 'pt-PT',
          learningLanguageCode: 'fr-FR',
          execution: execution,
          contentDefaultLocale: 'pt-PT',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CENARIO_QUIZ_47A2'), findsOneWidget);
    expect(find.text('PROMPT_QUIZ_47A2'), findsOneWidget);
  });

  testWidgets('review mission renders authored card', (tester) async {
    final execution = ReviewActivityExecution(
      cards: <ReviewExecutionCard>[
        ReviewExecutionCard(
          id: 'card-1',
          category: LocalizedText(<String, String>{
            'pt-PT': 'CATEGORIA_REVISAO_47A2',
          }),
          context: LocalizedText(<String, String>{
            'pt-PT': 'CONTEXTO_REVISAO_47A2',
          }),
          text: LocalizedText(<String, String>{
            'pt-PT': 'TEXTO_REVISAO_PT_47A2',
            'fr-FR': 'TEXTO_REVISAO_FR_47A2',
          }),
        ),
      ],
    );

    await tester.pumpWidget(
      _buildTestApp(
        RevisionPage(
          userLanguageCode: 'pt-PT',
          learningLanguageCode: 'fr-FR',
          execution: execution,
          contentDefaultLocale: 'pt-PT',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CATEGORIA_REVISAO_47A2'), findsOneWidget);
    expect(find.text('TEXTO_REVISAO_FR_47A2'), findsOneWidget);
  });
}
