import 'dart:convert';
import 'dart:io';

import 'package:dailytalk_mobile/domain/learning/learning_domain.dart';
import 'package:flutter_test/flutter_test.dart';

const _examplePath = 'assets/content/phase1_example_path.v1.json';
const _examplePathV2 = 'assets/content/phase1_example_path.v2.json';
const _codec = LearningContentCodec();

String _exampleSource() => File(_examplePath).readAsStringSync();
String _exampleSourceV2() => File(_examplePathV2).readAsStringSync();

Map<String, dynamic> _examplePackage() =>
    jsonDecode(_exampleSource()) as Map<String, dynamic>;

Map<String, dynamic> _examplePackageV2() =>
    jsonDecode(_exampleSourceV2()) as Map<String, dynamic>;

TypeMatcher<LearningContentException> _contentError(
  LearningContentErrorCode code,
) =>
    isA<LearningContentException>().having((error) => error.code, 'code', code);

PathElementDecision _decision(ProgressionResult result, String elementId) =>
    result.decisions[PathElementId(elementId)]!;

void main() {
  test('interpreta pacote exemplo com duas etapas e três caminhos', () {
    final path = _codec.decodeString(_exampleSource());

    expect(path.schemaVersion, SchemaVersion(1));
    expect(path.journeys.single.stages, hasLength(2));
    expect(path.journeys.single.stages.first.elements, hasLength(3));
    expect(path.journeys.single.stages.last.elements, hasLength(3));
    expect(path.activities, hasLength(6));
    expect(
      path.journeys.single.stages.first.elements.map(
        (element) => element.practicePreference,
      ),
      [
        PracticePreference.vocabulary,
        PracticePreference.dialogue,
        PracticePreference.speech,
      ],
    );
  });

  test('pacote interpretado preserva regras ALL e ANY', () {
    final path = _codec.decodeString(_exampleSource());
    final elements = path.journeys.single.stages.last.elements;

    final dialogueRule = elements[1].prerequisites! as PrerequisiteGroup;
    final speechRule = elements[2].prerequisites! as PrerequisiteGroup;

    expect(dialogueRule.operator, PrerequisiteOperator.any);
    expect(dialogueRule.rules, hasLength(2));
    expect(speechRule.operator, PrerequisiteOperator.all);
    expect(speechRule.rules, hasLength(2));
  });

  test('desbloqueia imediatamente caminhos permitidos pelo pacote', () {
    final path = _codec.decodeString(_exampleSource());
    final result = const DefaultProgressionEngine().evaluate(
      ProgressionRequest(
        learningPath: path,
        facts: ProgressionFacts(
          completedActivities: [ActivityId('arrival.vocabulary-01')],
        ),
      ),
    );

    expect(
      _decision(result, 'arrival.vocabulary-02.element').state,
      LearningActivityState.available,
    );
    expect(
      _decision(result, 'arrival.dialogue-02.element').state,
      LearningActivityState.available,
    );
    expect(
      _decision(result, 'arrival.speech-02.element').state,
      LearningActivityState.locked,
    );
  });

  test('round-trip preserva o agregado válido', () {
    final original = _codec.decodeString(_exampleSource());
    final restored = _codec.decodeString(
      _codec.encodeString(original, pretty: true),
    );

    expect(restored.id, original.id);
    expect(restored.schemaVersion, original.schemaVersion);
    expect(restored.activities.length, original.activities.length);
    expect(restored.journeys.single.stages.length, 2);
    expect(
      restored.activities.first.currentRevisionId,
      original.activities.first.currentRevisionId,
    );
  });

  test('schema v1 permanece retrocompatível e sem execution', () {
    final path = _codec.decodeString(_exampleSource());

    expect(path.schemaVersion, SchemaVersion(1));
    expect(
      path.activities.expand((activity) => activity.revisions),
      everyElement(
        isA<ActivityRevision>().having(
          (revision) => revision.execution,
          'execution',
          isNull,
        ),
      ),
    );
  });

  test('interpreta schema v2 com execution tipado por revisão', () {
    final path = _codec.decodeString(_exampleSourceV2());

    expect(path.schemaVersion, SchemaVersion(2));

    final vocabulary = path.activities.singleWhere(
      (activity) => activity.id.value == 'arrival.vocabulary-01',
    );
    final vocabularyExecution =
        vocabulary.currentRevision.execution as VocabularyActivityExecution;
    expect(vocabularyExecution.items, hasLength(4));
    expect(
      vocabularyExecution.items.first.text.resolve(
        'fr-FR',
        fallbackLocale: path.defaultLocale,
      ),
      'Bonjour',
    );

    final dialogue = path.activities.singleWhere(
      (activity) => activity.id.value == 'arrival.dialogue-01',
    );
    final dialogueExecution =
        dialogue.currentRevision.execution as DialogueActivityExecution;
    expect(dialogueExecution.turns, hasLength(2));
    expect(dialogueExecution.turns.first.distractors, hasLength(2));

    final speech = path.activities.singleWhere(
      (activity) => activity.id.value == 'arrival.speech-01',
    );
    final speechExecution =
        speech.currentRevision.execution as SpeechActivityExecution;
    expect(speechExecution.prompts, hasLength(3));
  });

  test('round-trip do schema v2 preserva execution', () {
    final original = _codec.decodeString(_exampleSourceV2());
    final restored = _codec.decodeString(
      _codec.encodeString(original, pretty: true),
    );

    expect(restored.schemaVersion, SchemaVersion(2));
    expect(
      restored.activities.first.currentRevision.execution,
      isA<VocabularyActivityExecution>(),
    );
    expect(
      (restored.activities.first.currentRevision.execution!
              as VocabularyActivityExecution)
          .items,
      hasLength(4),
    );
  });

  test('schema v2 exige execution em todas as revisões', () {
    final package = _examplePackageV2();
    final activities = package['activities']! as List<dynamic>;
    final first = activities.first as Map<String, dynamic>;
    final revisions = first['revisions']! as List<dynamic>;
    final revision = revisions.first as Map<String, dynamic>;
    revision.remove('execution');

    expect(
      () => _codec.decode(package),
      throwsA(_contentError(LearningContentErrorCode.missingField)),
    );
  });

  test('schema v2 rejeita execution de tipo diferente da atividade', () {
    final package = _examplePackageV2();
    final activities = package['activities']! as List<dynamic>;
    final first = activities.first as Map<String, dynamic>;
    final revisions = first['revisions']! as List<dynamic>;
    final revision = revisions.first as Map<String, dynamic>;
    final execution = revision['execution']! as Map<String, dynamic>;
    execution['kind'] = 'quiz';

    expect(
      () => _codec.decode(package),
      throwsA(_contentError(LearningContentErrorCode.invalidContent)),
    );
  });

  test(
    'schema v1 rejeita campo execution para evitar downgrade silencioso',
    () {
      final package = _examplePackage();
      final activities = package['activities']! as List<dynamic>;
      final first = activities.first as Map<String, dynamic>;
      final revisions = first['revisions']! as List<dynamic>;
      final revision = revisions.first as Map<String, dynamic>;
      revision['execution'] = <String, dynamic>{
        'kind': 'vocabulary',
        'items': <dynamic>[],
      };

      expect(
        () => _codec.decode(package),
        throwsA(_contentError(LearningContentErrorCode.unexpectedField)),
      );
    },
  );

  test('schema v2 interpreta payloads de quiz e review', () {
    final quizPackage = _examplePackageV2();
    final quizActivities = quizPackage['activities']! as List<dynamic>;
    final quizActivity = quizActivities.first as Map<String, dynamic>;
    quizActivity['type'] = 'quiz';
    final quizRevision =
        (quizActivity['revisions']! as List<dynamic>).first
            as Map<String, dynamic>;
    quizRevision['execution'] = <String, dynamic>{
      'kind': 'quiz',
      'questions': <dynamic>[
        <String, dynamic>{
          'id': 'q1',
          'category': <String, String>{'pt-PT': 'Chegada'},
          'scenario': <String, String>{'pt-PT': 'Conheces a família.'},
          'prompt': <String, String>{'pt-PT': 'O que dizes?'},
          'correctAnswer': <String, String>{'pt-PT': 'Olá!'},
          'distractors': <dynamic>[
            <String, String>{'pt-PT': 'Adeus.'},
          ],
        },
      ],
    };
    expect(
      _codec.decode(quizPackage).activities.first.currentRevision.execution,
      isA<QuizActivityExecution>(),
    );

    final reviewPackage = _examplePackageV2();
    final reviewActivities = reviewPackage['activities']! as List<dynamic>;
    final reviewActivity = reviewActivities.first as Map<String, dynamic>;
    reviewActivity['type'] = 'review';
    final reviewRevision =
        (reviewActivity['revisions']! as List<dynamic>).first
            as Map<String, dynamic>;
    reviewRevision['execution'] = <String, dynamic>{
      'kind': 'review',
      'cards': <dynamic>[
        <String, dynamic>{
          'id': 'card-1',
          'category': <String, String>{'pt-PT': 'Cumprimentos'},
          'context': <String, String>{'pt-PT': 'Ao chegar.'},
          'text': <String, String>{'pt-PT': 'Bonjour'},
        },
      ],
    };
    expect(
      _codec.decode(reviewPackage).activities.first.currentRevision.execution,
      isA<ReviewActivityExecution>(),
    );
  });

  test('rejeita JSON malformado com código estável', () {
    expect(
      () => _codec.decodeString('{'),
      throwsA(_contentError(LearningContentErrorCode.invalidJson)),
    );
  });

  test('rejeita raiz que não seja objeto', () {
    expect(
      () => _codec.decodeString('[]'),
      throwsA(_contentError(LearningContentErrorCode.invalidRoot)),
    );
  });

  test('rejeita versão de schema não suportada', () {
    final package = _examplePackage()..['schemaVersion'] = 3;

    expect(
      () => _codec.decode(package),
      throwsA(_contentError(LearningContentErrorCode.unsupportedSchemaVersion)),
    );
  });

  test('rejeita campo obrigatório ausente', () {
    final package = _examplePackage()..remove('defaultLocale');

    expect(
      () => _codec.decode(package),
      throwsA(_contentError(LearningContentErrorCode.missingField)),
    );
  });

  test('rejeita campo não reconhecido pelo schema', () {
    final package = _examplePackage()..['futureField'] = true;

    expect(
      () => _codec.decode(package),
      throwsA(_contentError(LearningContentErrorCode.unexpectedField)),
    );
  });

  test('rejeita enum desconhecido', () {
    final package = _examplePackage();
    final activities = package['activities']! as List<dynamic>;
    final first = activities.first as Map<String, dynamic>;
    first['type'] = 'unknown';

    expect(
      () => _codec.decode(package),
      throwsA(_contentError(LearningContentErrorCode.invalidEnumValue)),
    );
  });

  test('rejeita pacote com referência global quebrada', () {
    final package = _examplePackage();
    final journeys = package['journeys']! as List<dynamic>;
    final journey = journeys.first as Map<String, dynamic>;
    final stages = journey['stages']! as List<dynamic>;
    final stage = stages.first as Map<String, dynamic>;
    final elements = stage['elements']! as List<dynamic>;
    final element = elements.first as Map<String, dynamic>;
    element['activityId'] = 'activity.missing';

    expect(
      () => _codec.decode(package),
      throwsA(
        _contentError(LearningContentErrorCode.invalidLearningPath).having(
          (error) => error.validationIssues.map((issue) => issue.code),
          'validationIssues',
          contains(LearningPathValidationCode.missingElementActivity),
        ),
      ),
    );
  });
}
