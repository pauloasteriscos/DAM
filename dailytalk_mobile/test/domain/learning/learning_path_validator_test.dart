import 'package:dailytalk_mobile/domain/learning/learning_domain.dart';
import 'package:flutter_test/flutter_test.dart';

LocalizedText _text(String value) => LocalizedText({'pt-PT': value});

Activity _activity(
  ActivityId id, {
  Iterable<CompetencyId> competencies = const [],
}) {
  final revision = ActivityRevision(
    id: RevisionId('${id.value}.revision-01'),
    activityId: id,
    revisionNumber: 1,
    title: _text(id.value),
    instructions: _text('Executar atividade.'),
    visibility: ContentVisibility.public,
    competencies: competencies,
  );
  return Activity(
    id: id,
    type: LearningActivityType.quiz,
    origin: ContentOrigin.official,
    currentRevisionId: revision.id,
    revisions: [revision],
  );
}

PathElement _element(
  String elementId,
  ActivityId activityId, {
  PrerequisiteRule? prerequisites,
}) {
  return PathElement(
    id: PathElementId(elementId),
    type: PathElementType.activity,
    activityId: activityId,
    prerequisites: prerequisites,
  );
}

Stage _stage(String id, Iterable<PathElement> elements) =>
    Stage(id: StageId(id), title: _text(id), elements: elements);

LearningPath _path({
  required Iterable<Activity> activities,
  required Iterable<Stage> stages,
  Iterable<Competency> competencies = const [],
}) {
  return LearningPath(
    id: LearningPathId('phase1.increment-03'),
    schemaVersion: SchemaVersion(1),
    defaultLocale: 'pt-PT',
    title: _text('Percurso'),
    journeys: [
      Journey(
        id: JourneyId('journey.main'),
        title: _text('Jornada'),
        stages: stages,
      ),
    ],
    activities: activities,
    competencies: competencies,
  );
}

Set<LearningPathValidationCode> _codes(LearningPathValidationResult result) =>
    result.issues.map((issue) => issue.code).toSet();

void main() {
  const validator = LearningPathValidator();

  test('aceita percurso com referências globais íntegras', () {
    final firstId = ActivityId('activity.first');
    final secondId = ActivityId('activity.second');
    final competencyId = CompetencyId('competency.greeting');
    final path = _path(
      activities: [
        _activity(firstId, competencies: [competencyId]),
        _activity(secondId),
      ],
      competencies: [
        Competency(
          id: competencyId,
          title: _text('Cumprimentar'),
          description: _text('Usar cumprimentos.'),
        ),
      ],
      stages: [
        _stage('stage.main', [
          _element('element.first', firstId),
          _element(
            'element.second',
            secondId,
            prerequisites: PrerequisiteGroup.all([
              ActivityCompletedRequirement(firstId),
              CompetencyAchievedRequirement(competencyId),
            ]),
          ),
        ]),
      ],
    );

    expect(validator.inspect(path).isValid, isTrue);
    expect(() => validator.validate(path), returnsNormally);
  });

  test('deteta atividade inexistente referenciada por elemento', () {
    final missingId = ActivityId('activity.missing');
    final result = validator.inspect(
      _path(
        activities: const [],
        stages: [
          _stage('stage.main', [_element('element.missing', missingId)]),
        ],
      ),
    );

    expect(
      _codes(result),
      contains(LearningPathValidationCode.missingElementActivity),
    );
  });

  test('deteta referências inexistentes em pré-requisitos compostos', () {
    final targetId = ActivityId('activity.target');
    final result = validator.inspect(
      _path(
        activities: [_activity(targetId)],
        stages: [
          _stage('stage.main', [
            _element(
              'element.target',
              targetId,
              prerequisites: PrerequisiteGroup.all([
                ActivityCompletedRequirement(ActivityId('activity.missing')),
                CompetencyAchievedRequirement(
                  CompetencyId('competency.missing'),
                ),
              ]),
            ),
          ]),
        ],
      ),
    );

    expect(
      _codes(result),
      containsAll({
        LearningPathValidationCode.missingPrerequisiteActivity,
        LearningPathValidationCode.missingPrerequisiteCompetency,
      }),
    );
  });

  test('deteta competência inexistente numa revisão', () {
    final activityId = ActivityId('activity.first');
    final result = validator.inspect(
      _path(
        activities: [
          _activity(
            activityId,
            competencies: [CompetencyId('competency.missing')],
          ),
        ],
        stages: [
          _stage('stage.main', [_element('element.first', activityId)]),
        ],
      ),
    );

    expect(
      _codes(result),
      contains(LearningPathValidationCode.missingRevisionCompetency),
    );
  });

  test('deteta PathElementId duplicado entre etapas', () {
    final firstId = ActivityId('activity.first');
    final secondId = ActivityId('activity.second');
    final result = validator.inspect(
      _path(
        activities: [_activity(firstId), _activity(secondId)],
        stages: [
          _stage('stage.first', [_element('element.duplicate', firstId)]),
          _stage('stage.second', [_element('element.duplicate', secondId)]),
        ],
      ),
    );

    expect(
      _codes(result),
      contains(LearningPathValidationCode.duplicatePathElementId),
    );
  });

  test('deteta ciclo entre pré-requisitos de atividades', () {
    final firstId = ActivityId('activity.first');
    final secondId = ActivityId('activity.second');
    final result = validator.inspect(
      _path(
        activities: [_activity(firstId), _activity(secondId)],
        stages: [
          _stage('stage.main', [
            _element(
              'element.first',
              firstId,
              prerequisites: ActivityCompletedRequirement(secondId),
            ),
            _element(
              'element.second',
              secondId,
              prerequisites: ActivityCompletedRequirement(firstId),
            ),
          ]),
        ],
      ),
    );

    expect(
      _codes(result),
      contains(LearningPathValidationCode.cyclicActivityPrerequisite),
    );
    expect(result.issues.last.reference, contains('activity.first'));
    expect(result.issues.last.reference, contains('activity.second'));
  });

  test('motor rejeita percurso inválido antes de calcular estados', () {
    final missingId = ActivityId('activity.missing');
    final path = _path(
      activities: const [],
      stages: [
        _stage('stage.main', [_element('element.missing', missingId)]),
      ],
    );

    expect(
      () => const DefaultProgressionEngine().evaluate(
        ProgressionRequest(learningPath: path, facts: ProgressionFacts()),
      ),
      throwsA(isA<LearningPathValidationException>()),
    );
  });
}
