import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dailytalk_mobile/domain/learning/domain_ids.dart';
import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/learning_lexical_contract.dart';
import 'package:dailytalk_mobile/domain/learning/learning_lexical_contract_codec.dart';
import 'package:dailytalk_mobile/domain/learning/learning_lexical_validator.dart';
import 'package:dailytalk_mobile/domain/learning/learning_models.dart';

void main() {
  group('LearningLexicalCoverageValidator', () {
    test(
      'aceita vocabulário da mesma etapa como cobertura sem criar pré-requisito',
      () {
        final path = _path();
        final contract = LearningLexicalContract(
          schemaVersion: 1,
          learningPathId: path.id,
          activities: <LearningLexicalActivityContract>[
            LearningLexicalActivityContract(
              activityId: ActivityId('arrival.vocabulary-01'),
              introduces: const <String>[
                'greeting.hello',
                'greeting.good-morning',
              ],
              practises: const <String>[
                'greeting.hello',
                'greeting.good-morning',
              ],
            ),
            LearningLexicalActivityContract(
              activityId: ActivityId('arrival.dialogue-01'),
              practises: const <String>['greeting.hello'],
            ),
            LearningLexicalActivityContract(
              activityId: ActivityId('arrival.speech-01'),
              practises: const <String>['greeting.good-morning'],
            ),
            LearningLexicalActivityContract(
              activityId: ActivityId('home.vocabulary-01'),
              introduces: const <String>['home.room'],
            ),
            LearningLexicalActivityContract(
              activityId: ActivityId('home.dialogue-01'),
              practises: const <String>['greeting.hello', 'home.room'],
            ),
            LearningLexicalActivityContract(
              activityId: ActivityId('home.speech-01'),
              reinforces: const <String>['home.room'],
            ),
          ],
        );

        final result = const LearningLexicalCoverageValidator().inspect(
          path,
          contract,
        );

        expect(result.isValid, isTrue);
      },
    );

    test('rejeita léxico usado sem cobertura de vocabulário', () {
      final path = _path();
      final contract = LearningLexicalContract(
        schemaVersion: 1,
        learningPathId: path.id,
        activities: <LearningLexicalActivityContract>[
          LearningLexicalActivityContract(
            activityId: ActivityId('arrival.vocabulary-01'),
            introduces: const <String>['greeting.hello'],
          ),
          LearningLexicalActivityContract(
            activityId: ActivityId('arrival.dialogue-01'),
            practises: const <String>['greeting.good-morning'],
          ),
          LearningLexicalActivityContract(
            activityId: ActivityId('arrival.speech-01'),
          ),
          LearningLexicalActivityContract(
            activityId: ActivityId('home.vocabulary-01'),
          ),
          LearningLexicalActivityContract(
            activityId: ActivityId('home.dialogue-01'),
          ),
          LearningLexicalActivityContract(
            activityId: ActivityId('home.speech-01'),
          ),
        ],
      );

      final result = const LearningLexicalCoverageValidator().inspect(
        path,
        contract,
      );

      expect(
        result.issues.any(
          (issue) =>
              issue.code ==
                  LearningLexicalValidationCode.missingVocabularyCoverage &&
              issue.reference == 'greeting.good-morning',
        ),
        isTrue,
      );
    });

    test('somente vocabulário pode introduzir léxico nesta fase', () {
      final path = _path();
      final contract = LearningLexicalContract(
        schemaVersion: 1,
        learningPathId: path.id,
        activities: <LearningLexicalActivityContract>[
          LearningLexicalActivityContract(
            activityId: ActivityId('arrival.vocabulary-01'),
          ),
          LearningLexicalActivityContract(
            activityId: ActivityId('arrival.dialogue-01'),
            introduces: const <String>['greeting.hello'],
          ),
          LearningLexicalActivityContract(
            activityId: ActivityId('arrival.speech-01'),
          ),
          LearningLexicalActivityContract(
            activityId: ActivityId('home.vocabulary-01'),
          ),
          LearningLexicalActivityContract(
            activityId: ActivityId('home.dialogue-01'),
          ),
          LearningLexicalActivityContract(
            activityId: ActivityId('home.speech-01'),
          ),
        ],
      );

      final result = const LearningLexicalCoverageValidator().inspect(
        path,
        contract,
      );

      expect(
        result.issues.any(
          (issue) =>
              issue.code ==
              LearningLexicalValidationCode.introductionOnNonVocabulary,
        ),
        isTrue,
      );
    });

    test('exige contrato para vocabulary/dialogue/speech', () {
      final path = _path();
      final contract = LearningLexicalContract(
        schemaVersion: 1,
        learningPathId: path.id,
        activities: <LearningLexicalActivityContract>[
          LearningLexicalActivityContract(
            activityId: ActivityId('arrival.vocabulary-01'),
          ),
        ],
      );

      final result = const LearningLexicalCoverageValidator().inspect(
        path,
        contract,
      );

      expect(
        result.issues
            .where(
              (issue) =>
                  issue.code ==
                  LearningLexicalValidationCode.missingActivityContract,
            )
            .length,
        5,
      );
    });
  });

  group('LearningLexicalContractCodec', () {
    test('round-trip preserva o contrato editorial', () {
      final source = jsonEncode(<String, Object>{
        'schemaVersion': 1,
        'learningPathId': 'student.it-it.phase1',
        'activities': <Object>[
          <String, Object>{
            'activityId': 'arrival.vocabulary-01',
            'introduces': <String>['greeting.hello', 'greeting.good-morning'],
            'practises': <String>['greeting.hello'],
            'reinforces': <String>[],
          },
        ],
      });

      const codec = LearningLexicalContractCodec();
      final decoded = codec.decodeString(source);
      final encoded = codec.encodeString(decoded);
      final roundTrip = codec.decodeString(encoded);

      expect(roundTrip.learningPathId.value, 'student.it-it.phase1');
      expect(roundTrip.activities, hasLength(1));
      expect(
        roundTrip.activities.single.introduces,
        containsAll(<String>['greeting.hello', 'greeting.good-morning']),
      );
    });
  });
}

LearningPath _path() {
  final activities = <Activity>[
    _activity('arrival.vocabulary-01', LearningActivityType.vocabulary),
    _activity('arrival.dialogue-01', LearningActivityType.dialogue),
    _activity('arrival.speech-01', LearningActivityType.speech),
    _activity('home.vocabulary-01', LearningActivityType.vocabulary),
    _activity('home.dialogue-01', LearningActivityType.dialogue),
    _activity('home.speech-01', LearningActivityType.speech),
  ];

  return LearningPath(
    id: LearningPathId('student.it-it.phase1'),
    schemaVersion: SchemaVersion(2),
    defaultLocale: 'it-IT',
    title: _text('Percorso'),
    competencies: const <Competency>[],
    activities: activities,
    journeys: <Journey>[
      Journey(
        id: JourneyId('journey-01'),
        title: _text('Arrivo'),
        stages: <Stage>[
          Stage(
            id: StageId('stage-01'),
            title: _text('Primo contatto'),
            elements: <PathElement>[
              _element('arrival.vocabulary-01'),
              _element('arrival.dialogue-01'),
              _element('arrival.speech-01'),
            ],
          ),
          Stage(
            id: StageId('stage-02'),
            title: _text('Casa'),
            elements: <PathElement>[
              _element('home.vocabulary-01'),
              _element('home.dialogue-01'),
              _element('home.speech-01'),
            ],
          ),
        ],
      ),
    ],
  );
}

Activity _activity(String id, LearningActivityType type) {
  final activityId = ActivityId(id);
  final revisionId = RevisionId('$id.revision-01');

  return Activity(
    id: activityId,
    type: type,
    origin: ContentOrigin.official,
    currentRevisionId: revisionId,
    revisions: <ActivityRevision>[
      ActivityRevision(
        id: revisionId,
        activityId: activityId,
        revisionNumber: 1,
        title: _text(id),
        instructions: _text('Istruzione'),
        visibility: ContentVisibility.public,
        execution: _execution(type),
      ),
    ],
  );
}

ActivityExecution _execution(LearningActivityType type) {
  switch (type) {
    case LearningActivityType.vocabulary:
      return VocabularyActivityExecution(
        items: <VocabularyExecutionItem>[
          VocabularyExecutionItem(id: 'item-01', text: _text('Ciao')),
        ],
      );
    case LearningActivityType.dialogue:
      return DialogueActivityExecution(
        scenarioTitle: _text('Dialogo'),
        scenarioDescription: _text('Scenario'),
        turns: <DialogueExecutionTurn>[
          DialogueExecutionTurn(
            id: 'turn-01',
            partnerMessage: _text('Ciao'),
            prompt: _text('Rispondi'),
            correctReply: _text('Ciao'),
            distractors: <LocalizedText>[_text('No')],
          ),
        ],
      );
    case LearningActivityType.speech:
      return SpeechActivityExecution(
        prompts: <SpeechExecutionPrompt>[
          SpeechExecutionPrompt(id: 'prompt-01', text: _text('Ciao')),
        ],
      );
    case LearningActivityType.quiz:
      return QuizActivityExecution(
        questions: <QuizExecutionQuestion>[
          QuizExecutionQuestion(
            id: 'question-01',
            category: _text('Quiz'),
            scenario: _text('Scenario'),
            prompt: _text('Domanda'),
            correctAnswer: _text('Sì'),
            distractors: <LocalizedText>[_text('No')],
          ),
        ],
      );
    case LearningActivityType.review:
      return ReviewActivityExecution(
        cards: <ReviewExecutionCard>[
          ReviewExecutionCard(
            id: 'card-01',
            category: _text('Review'),
            context: _text('Contesto'),
            text: _text('Ciao'),
          ),
        ],
      );
    case LearningActivityType.integratedChallenge:
      throw UnsupportedError('integratedChallenge não é usado neste teste');
  }
}

PathElement _element(String activityId) {
  return PathElement(
    id: PathElementId('$activityId.element'),
    type: PathElementType.activity,
    activityId: ActivityId(activityId),
  );
}

LocalizedText _text(String value) {
  return LocalizedText(<String, String>{'it-IT': value, 'en-US': value});
}
