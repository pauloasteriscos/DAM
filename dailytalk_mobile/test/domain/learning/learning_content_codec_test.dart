import 'dart:convert';
import 'dart:io';

import 'package:dailytalk_mobile/domain/learning/learning_domain.dart';
import 'package:flutter_test/flutter_test.dart';

const _examplePath = 'assets/content/phase1_example_path.v1.json';
const _codec = LearningContentCodec();

String _exampleSource() => File(_examplePath).readAsStringSync();

Map<String, dynamic> _examplePackage() =>
    jsonDecode(_exampleSource()) as Map<String, dynamic>;

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
    final package = _examplePackage()..['schemaVersion'] = 2;

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
