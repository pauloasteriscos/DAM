import 'package:dailytalk_mobile/data/repositories/learning_progress_read_repository.dart';
import 'package:dailytalk_mobile/domain/learning/domain_ids.dart';
import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/learning_models.dart';
import 'package:dailytalk_mobile/domain/learning/progression_engine.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_assembler.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_stage_window.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_window_composer.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_window_read_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const composer = LearningMapWindowComposer();

  test('compoe somente stages da janela com metricas globais', () {
    final path = _buildPath();
    final snapshot = _snapshot(path);

    final composition = composer.compose(
      activePath: path,
      snapshot: snapshot,
      locale: 'pt-PT',
    );

    final model = composition.model;

    expect(model.learningPathId, 'path-1');
    expect(model.totalActivityCount, 4);
    expect(model.completedActivityCount, 2);
    expect(model.completionRatio, 0.5);

    expect(model.journeys, hasLength(2));

    expect(model.journeys.map((journey) => journey.id).toList(), <String>[
      'journey-a',
      'journey-b',
    ]);

    expect(
      model.journeys
          .expand((journey) => journey.stages)
          .map((stage) => stage.id)
          .toList(),
      <String>['stage-1', 'stage-2'],
    );

    expect(
      model.elements.map((element) => element.pathElementId).toList(),
      <String>['element-1', 'element-2'],
    );

    // Métricas por stage continuam locais à janela.
    final stages = model.journeys.expand((journey) => journey.stages).toList();

    expect(stages[0].activityCount, 1);
    expect(stages[0].completedActivityCount, 1);
    expect(stages[1].activityCount, 1);
    expect(stages[1].completedActivityCount, 0);

    // O melhor recomendado global está fora da janela.
    expect(composition.primaryGlobalRecommendation?.pathElementId, 'element-3');

    expect(composition.primaryGlobalRecommendationIsLoaded, isFalse);

    // A recomendação visível dentro da janela continua intacta,
    // sem substituir a recomendação global.
    expect(model.nextRecommendedElement?.pathElementId, 'element-2');

    expect(model.nextRecommendedElement?.recommendationRank, 1);
  });

  test('empate global usa ordem authored e nao ordem do SQLite', () {
    final path = _buildPath();

    final snapshot = _snapshot(
      path,
      windowProjection: _windowProjection(path, includeRecommendation: false),
      globalRecommendations: <LearningProgressProjectionEntry>[
        _projection(
          elementId: 'element-3',
          activityId: 'activity-3',
          state: LearningActivityState.available,
          reason: ProgressionReason.ready,
          recommendationRank: 0,
        ),
        _projection(
          elementId: 'element-0',
          activityId: 'activity-0',
          state: LearningActivityState.available,
          reason: ProgressionReason.ready,
          recommendationRank: 0,
        ),
      ],
    );

    final composition = composer.compose(
      activePath: path,
      snapshot: snapshot,
      locale: 'en',
    );

    expect(
      composition.globalRecommendations
          .map((entry) => entry.pathElementId)
          .toList(),
      <String>['element-0', 'element-3'],
    );

    expect(composition.primaryGlobalRecommendation?.pathElementId, 'element-0');

    expect(composition.primaryGlobalRecommendationIsLoaded, isFalse);
  });

  test('StageWindow divergente do catalogo oficial falha fechado', () {
    final path = _buildPath();

    final descriptors = _descriptors(path);

    descriptors[1] = LearningMapStageDescriptor(
      journeyId: 'journey-a',
      stageId: 'stage-1',
      pathElementIds: const <String>['wrong-element'],
      activityIds: const <String>['activity-1'],
    );

    final window = const LearningMapStageWindowPlanner().plan(
      stages: descriptors,
      startStageIndex: 1,
      stageCount: 2,
    );

    final snapshot = LearningMapWindowReadSnapshot(
      learningPathId: 'path-1',
      packageVersion: 9,
      recoveredFromFallback: false,
      window: window,
      windowProjection: <LearningProgressProjectionEntry>[
        _projection(
          elementId: 'wrong-element',
          activityId: 'activity-1',
          state: LearningActivityState.completed,
          reason: ProgressionReason.completed,
        ),
        _projection(
          elementId: 'element-2',
          activityId: 'activity-2',
          state: LearningActivityState.available,
          reason: ProgressionReason.ready,
        ),
      ],
      windowSyncStates: const <String, ProgressSyncState>{},
      globalRecommendations: const <LearningProgressProjectionEntry>[],
      globalCounts: _globalCounts(),
    );

    expect(
      () => composer.compose(
        activePath: path,
        snapshot: snapshot,
        locale: 'pt-PT',
      ),
      throwsStateError,
    );
  });

  test('assembler continua estrito quando falta projection da janela', () {
    final path = _buildPath();

    final snapshot = _snapshot(
      path,
      windowProjection: <LearningProgressProjectionEntry>[
        _projection(
          elementId: 'element-1',
          activityId: 'activity-1',
          state: LearningActivityState.completed,
          reason: ProgressionReason.completed,
        ),
      ],
      globalRecommendations: const <LearningProgressProjectionEntry>[],
    );

    expect(
      () => composer.compose(
        activePath: path,
        snapshot: snapshot,
        locale: 'pt-PT',
      ),
      throwsA(
        isA<LearningMapAssemblyException>().having(
          (error) => error.code,
          'code',
          LearningMapAssemblyErrorCode.missingProjectionEntry,
        ),
      ),
    );
  });

  test('aggregate global incompleto falha fechado', () {
    final path = _buildPath();

    final snapshot = _snapshot(
      path,
      counts: LearningProgressProjectionCounts(
        projectionRowCount: 3,
        totalActivityCount: 3,
        completedActivityCount: 1,
        minPackageVersion: 9,
        maxPackageVersion: 9,
      ),
    );

    expect(
      () => composer.compose(
        activePath: path,
        snapshot: snapshot,
        locale: 'pt-PT',
      ),
      throwsStateError,
    );
  });

  test('recommendation windowed e global divergentes falham fechado', () {
    final path = _buildPath();

    final snapshot = _snapshot(
      path,
      globalRecommendations: <LearningProgressProjectionEntry>[
        _projection(
          elementId: 'element-3',
          activityId: 'activity-3',
          state: LearningActivityState.available,
          reason: ProgressionReason.ready,
          recommendationRank: 0,
        ),
        _projection(
          elementId: 'element-2',
          activityId: 'activity-2',
          state: LearningActivityState.available,
          reason: ProgressionReason.ready,
          recommendationRank: 7,
        ),
      ],
    );

    expect(
      () => composer.compose(
        activePath: path,
        snapshot: snapshot,
        locale: 'pt-PT',
      ),
      throwsStateError,
    );
  });
}

LearningMapWindowReadSnapshot _snapshot(
  LearningPath path, {
  List<LearningProgressProjectionEntry>? windowProjection,
  List<LearningProgressProjectionEntry>? globalRecommendations,
  LearningProgressProjectionCounts? counts,
}) {
  final window = const LearningMapStageWindowPlanner().plan(
    stages: _descriptors(path),
    startStageIndex: 1,
    stageCount: 2,
  );

  return LearningMapWindowReadSnapshot(
    learningPathId: path.id.value,
    packageVersion: 9,
    recoveredFromFallback: false,
    window: window,
    windowProjection: windowProjection ?? _windowProjection(path),
    windowSyncStates: const <String, ProgressSyncState>{
      'activity-1': ProgressSyncState.pending,
    },
    globalRecommendations:
        globalRecommendations ??
        <LearningProgressProjectionEntry>[
          _projection(
            elementId: 'element-3',
            activityId: 'activity-3',
            state: LearningActivityState.available,
            reason: ProgressionReason.ready,
            recommendationRank: 0,
          ),
          _projection(
            elementId: 'element-2',
            activityId: 'activity-2',
            state: LearningActivityState.available,
            reason: ProgressionReason.ready,
            recommendationRank: 1,
          ),
        ],
    globalCounts: counts ?? _globalCounts(),
  );
}

LearningProgressProjectionCounts _globalCounts() {
  return LearningProgressProjectionCounts(
    projectionRowCount: 4,
    totalActivityCount: 4,
    completedActivityCount: 2,
    minPackageVersion: 9,
    maxPackageVersion: 9,
  );
}

List<LearningProgressProjectionEntry> _windowProjection(
  LearningPath path, {
  bool includeRecommendation = true,
}) {
  return <LearningProgressProjectionEntry>[
    _projection(
      elementId: 'element-1',
      activityId: 'activity-1',
      state: LearningActivityState.completed,
      reason: ProgressionReason.completed,
    ),
    _projection(
      elementId: 'element-2',
      activityId: 'activity-2',
      state: LearningActivityState.available,
      reason: ProgressionReason.ready,
      recommendationRank: includeRecommendation ? 1 : null,
    ),
  ];
}

List<LearningMapStageDescriptor> _descriptors(LearningPath path) {
  final result = <LearningMapStageDescriptor>[];

  for (final journey in path.journeys) {
    for (final stage in journey.stages) {
      final activityIds = <String>[];
      final seen = <String>{};

      for (final element in stage.elements) {
        final activityId = element.activityId?.value;

        if (activityId != null && seen.add(activityId)) {
          activityIds.add(activityId);
        }
      }

      result.add(
        LearningMapStageDescriptor(
          journeyId: journey.id.value,
          stageId: stage.id.value,
          pathElementIds: stage.elements.map((element) => element.id.value),
          activityIds: activityIds,
        ),
      );
    }
  }

  return result;
}

LearningPath _buildPath() {
  final activities = List<Activity>.generate(
    4,
    (index) => _activity(index),
    growable: false,
  );

  return LearningPath(
    id: LearningPathId('path-1'),
    schemaVersion: SchemaVersion(1),
    defaultLocale: 'en',
    title: LocalizedText(<String, String>{
      'en': 'Mobility learning path',
      'pt-PT': 'Percurso de mobilidade',
    }),
    journeys: <Journey>[
      Journey(
        id: JourneyId('journey-a'),
        title: LocalizedText(<String, String>{
          'en': 'Journey A',
          'pt-PT': 'Jornada A',
        }),
        stages: <Stage>[_stage(0), _stage(1)],
      ),
      Journey(
        id: JourneyId('journey-b'),
        title: LocalizedText(<String, String>{
          'en': 'Journey B',
          'pt-PT': 'Jornada B',
        }),
        stages: <Stage>[_stage(2), _stage(3)],
      ),
    ],
    activities: activities,
    competencies: const <Competency>[],
  );
}

Stage _stage(int index) {
  return Stage(
    id: StageId('stage-$index'),
    title: LocalizedText(<String, String>{
      'en': 'Stage $index',
      'pt-PT': 'Etapa $index',
    }),
    elements: <PathElement>[
      PathElement(
        id: PathElementId('element-$index'),
        type: PathElementType.activity,
        activityId: ActivityId('activity-$index'),
      ),
    ],
  );
}

Activity _activity(int index) {
  final activityId = ActivityId('activity-$index');

  final revisionId = RevisionId('activity-$index-r1');

  return Activity(
    id: activityId,
    type: LearningActivityType.dialogue,
    origin: ContentOrigin.official,
    currentRevisionId: revisionId,
    revisions: <ActivityRevision>[
      ActivityRevision(
        id: revisionId,
        activityId: activityId,
        revisionNumber: 1,
        title: LocalizedText(<String, String>{
          'en': 'Activity $index',
          'pt-PT': 'Atividade $index',
        }),
        instructions: LocalizedText(<String, String>{
          'en': 'Practise activity $index.',
          'pt-PT': 'Pratica a atividade $index.',
        }),
        visibility: ContentVisibility.public,
        competencies: const <CompetencyId>{},
      ),
    ],
  );
}

LearningProgressProjectionEntry _projection({
  required String elementId,
  required String? activityId,
  required LearningActivityState state,
  required ProgressionReason reason,
  int? recommendationRank,
}) {
  return LearningProgressProjectionEntry(
    pathElementId: elementId,
    activityId: activityId,
    state: state,
    reason: reason,
    recommendationRank: recommendationRank,
    packageVersion: 9,
    updatedAt: DateTime.utc(2026, 9, 14, 14),
  );
}
