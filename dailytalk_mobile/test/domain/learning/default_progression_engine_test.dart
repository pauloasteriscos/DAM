import 'package:dailytalk_mobile/domain/learning/learning_domain.dart';
import 'package:flutter_test/flutter_test.dart';

Activity _activity(ActivityId id) {
  final revision = ActivityRevision(
    id: RevisionId('${id.value}.revision-01'),
    activityId: id,
    revisionNumber: 1,
    title: LocalizedText({'pt-PT': id.value}),
    instructions: LocalizedText({'pt-PT': 'Executar atividade.'}),
    visibility: ContentVisibility.public,
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
  String id, {
  PrerequisiteRule? prerequisites,
  PracticePreference preference = PracticePreference.balanced,
}) {
  final activityId = ActivityId('activity.$id');
  return PathElement(
    id: PathElementId('element.$id'),
    type: PathElementType.activity,
    activityId: activityId,
    prerequisites: prerequisites,
    practicePreference: preference,
  );
}

LearningPath _path(List<Stage> stages) {
  final activityIds = <ActivityId>{
    for (final stage in stages)
      for (final element in stage.elements)
        if (element.activityId != null) element.activityId!,
  };
  final competencyIds = <CompetencyId>{};
  for (final stage in stages) {
    for (final element in stage.elements) {
      final prerequisites = element.prerequisites;
      if (prerequisites != null) {
        _collectPrerequisiteReferences(
          prerequisites,
          activityIds,
          competencyIds,
        );
      }
    }
  }
  return LearningPath(
    id: LearningPathId('phase1.increment-02'),
    schemaVersion: SchemaVersion(1),
    defaultLocale: 'pt-PT',
    title: LocalizedText({'pt-PT': 'Percurso'}),
    journeys: [
      Journey(
        id: JourneyId('journey.main'),
        title: LocalizedText({'pt-PT': 'Jornada'}),
        stages: stages,
      ),
    ],
    activities: activityIds.map(_activity),
    competencies: competencyIds.map(
      (id) => Competency(
        id: id,
        title: LocalizedText({'pt-PT': id.value}),
        description: LocalizedText({'pt-PT': 'Competência de teste.'}),
      ),
    ),
  );
}

void _collectPrerequisiteReferences(
  PrerequisiteRule rule,
  Set<ActivityId> activityIds,
  Set<CompetencyId> competencyIds,
) {
  if (rule is ActivityCompletedRequirement) {
    activityIds.add(rule.activityId);
  } else if (rule is CompetencyAchievedRequirement) {
    competencyIds.add(rule.competencyId);
  } else if (rule is PrerequisiteGroup) {
    for (final child in rule.rules) {
      _collectPrerequisiteReferences(child, activityIds, competencyIds);
    }
  }
}

Stage _stage(String id, List<PathElement> elements) => Stage(
      id: StageId('stage.$id'),
      title: LocalizedText({'pt-PT': id}),
      elements: elements,
    );

ProgressionResult _evaluate(
  List<PathElement> elements, {
  ProgressionFacts? facts,
  Iterable<ActivityId> inProgress = const [],
  PracticePreference preference = PracticePreference.balanced,
}) {
  return const DefaultProgressionEngine().evaluate(
    ProgressionRequest(
      learningPath: _path([_stage('main', elements)]),
      facts: facts ?? ProgressionFacts(),
      activitiesInProgress: inProgress,
      practicePreference: preference,
    ),
  );
}

void main() {
  test('aplica precedência dos quatro estados e desbloqueio local imediato', () {
    final gate = ActivityId('activity.gate');
    final completed = _element('completed');
    final active = _element(
      'active',
      prerequisites: ActivityCompletedRequirement(
        ActivityId('activity.missing'),
      ),
    );
    final unlocked = _element(
      'unlocked',
      prerequisites: ActivityCompletedRequirement(gate),
    );
    final locked = _element(
      'locked',
      prerequisites: ActivityCompletedRequirement(
        ActivityId('activity.missing'),
      ),
    );

    final result = _evaluate(
      [completed, active, unlocked, locked],
      facts: ProgressionFacts(
        completedActivities: [completed.activityId!, gate],
      ),
      inProgress: [active.activityId!],
    );

    expect(result.decisions[completed.id]?.state, LearningActivityState.completed);
    expect(result.decisions[active.id]?.state, LearningActivityState.inProgress);
    expect(result.decisions[unlocked.id]?.state, LearningActivityState.available);
    expect(result.decisions[locked.id]?.state, LearningActivityState.locked);
  });

  test('avalia grupos de pré-requisitos ALL e ANY', () {
    final first = ActivityId('activity.first');
    final second = ActivityId('activity.second');
    final all = _element(
      'all',
      prerequisites: PrerequisiteGroup.all([
        ActivityCompletedRequirement(first),
        ActivityCompletedRequirement(second),
      ]),
    );
    final any = _element(
      'any',
      prerequisites: PrerequisiteGroup.any([
        ActivityCompletedRequirement(first),
        ActivityCompletedRequirement(second),
      ]),
    );

    final result = _evaluate(
      [all, any],
      facts: ProgressionFacts(completedActivities: [first]),
    );

    expect(result.decisions[all.id]?.state, LearningActivityState.locked);
    expect(result.decisions[any.id]?.state, LearningActivityState.available);
  });

  test('mantém caminhos paralelos disponíveis', () {
    final left = _element('left');
    final right = _element('right');
    final result = _evaluate([left, right]);

    expect(result.decisions[left.id]?.state, LearningActivityState.available);
    expect(result.decisions[right.id]?.state, LearningActivityState.available);
    expect(result.recommendations, [left.id, right.id]);
  });

  test('preferência apenas reordena recomendações', () {
    final vocabulary = _element(
      'vocabulary',
      preference: PracticePreference.vocabulary,
    );
    final dialogue = _element(
      'dialogue',
      preference: PracticePreference.dialogue,
    );
    final result = _evaluate(
      [vocabulary, dialogue],
      preference: PracticePreference.dialogue,
    );

    expect(result.recommendations, [dialogue.id, vocabulary.id]);
    expect(result.decisions[vocabulary.id]?.state, LearningActivityState.available);
    expect(result.decisions[dialogue.id]?.state, LearningActivityState.available);
  });

  test('prioriza a retoma de atividade em curso', () {
    final active = _element(
      'active',
      preference: PracticePreference.vocabulary,
    );
    final preferred = _element(
      'preferred',
      preference: PracticePreference.dialogue,
    );
    final result = _evaluate(
      [preferred, active],
      inProgress: [active.activityId!],
      preference: PracticePreference.dialogue,
    );

    expect(result.recommendations.first, active.id);
  });

  test('rejeita PathElementId duplicado em etapas diferentes', () {
    final first = _element('duplicate');
    final second = PathElement(
      id: first.id,
      type: PathElementType.activity,
      activityId: ActivityId('activity.other'),
    );
    final request = ProgressionRequest(
      learningPath: _path([
        _stage('first', [first]),
        _stage('second', [second]),
      ]),
      facts: ProgressionFacts(),
    );

    expect(
      () => const DefaultProgressionEngine().evaluate(request),
      throwsArgumentError,
    );
  });
}
