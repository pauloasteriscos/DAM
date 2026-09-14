import 'package:dailytalk_mobile/data/repositories/learning_progress_read_repository.dart';
import 'package:dailytalk_mobile/domain/learning/domain_ids.dart';
import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/learning_models.dart';
import 'package:dailytalk_mobile/domain/learning/progression_engine.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_read_service.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_stage_window.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_window_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'sessao le catalogo uma vez e pagina projection/sync por segmentos',
    () async {
      final path = _buildPath(6);

      var catalogLoadCount = 0;

      final projectionRequests = <List<String>>[];

      final syncRequests = <List<String>>[];

      final coordinator = LearningMapWindowCoordinator(
        loadActiveContent: (learningPathId) async {
          catalogLoadCount++;

          expect(learningPathId, 'path-1');

          return LearningMapActiveContentSnapshot(
            path: path,
            packageVersion: 9,
            recoveredFromFallback: false,
          );
        },
        loadWindowProjection:
            ({
              required String accountId,
              required String learningPathId,
              required Iterable<String> pathElementIds,
            }) async {
              final ids = pathElementIds.toList(growable: false);

              projectionRequests.add(ids);

              return ids.map((id) => _projection(id)).toList(growable: false);
            },
        loadWindowSync:
            ({
              required String accountId,
              required String learningPathId,
              required Iterable<String> activityIds,
            }) async {
              final ids = activityIds.toList(growable: false);

              syncRequests.add(ids);

              return const <String, ProgressSyncState>{};
            },
        loadGlobalRecommendations:
            ({
              required String accountId,
              required String learningPathId,
            }) async {
              return <LearningProgressProjectionEntry>[
                _projection('element-5', recommendationRank: 0),
              ];
            },
        loadGlobalCounts:
            ({
              required String accountId,
              required String learningPathId,
            }) async {
              return _counts(6);
            },
        policy: const LearningMapStageWindowPolicy(
          initialStageCount: 2,
          segmentStageCount: 2,
        ),
      );

      final session = await coordinator.open(
        accountId: ' account-1 ',
        learningPathId: ' path-1 ',
        locale: ' pt-PT ',
      );

      expect(catalogLoadCount, 1);
      expect(session.totalStageCount, 6);

      final first = await session.loadInitial();

      expect(catalogLoadCount, 1);

      expect(
        first.model.elements.map((element) => element.pathElementId).toList(),
        <String>['element-0', 'element-1'],
      );

      expect(first.model.totalActivityCount, 6);

      expect(first.primaryGlobalRecommendation?.pathElementId, 'element-5');

      expect(first.primaryGlobalRecommendationIsLoaded, isFalse);

      final second = await session.loadNext(first.window);

      expect(second, isNotNull);
      expect(catalogLoadCount, 1);

      expect(
        second!.model.elements.map((element) => element.pathElementId).toList(),
        <String>['element-2', 'element-3'],
      );

      expect(projectionRequests, <List<String>>[
        <String>['element-0', 'element-1'],
        <String>['element-2', 'element-3'],
      ]);

      expect(syncRequests, <List<String>>[
        <String>['activity-0', 'activity-1'],
        <String>['activity-2', 'activity-3'],
      ]);

      // O catálogo authored continua congelado na sessão.
      expect(catalogLoadCount, 1);
    },
  );

  test('politica bounded navega sem acumular stages antigas', () {
    final path = _buildPath(5);

    final descriptors = _descriptors(path);

    const policy = LearningMapStageWindowPolicy(
      initialStageCount: 2,
      segmentStageCount: 2,
    );

    const planner = LearningMapStageWindowPlanner();

    final initialRequest = policy.initial();

    expect(initialRequest.startStageIndex, 0);
    expect(initialRequest.stageCount, 2);

    final first = planner.plan(
      stages: descriptors,
      startStageIndex: initialRequest.startStageIndex,
      stageCount: initialRequest.stageCount,
    );

    expect(first.loadedStageCount, 2);
    expect(first.hasPrevious, isFalse);
    expect(first.hasNext, isTrue);

    final nextRequest = policy.next(first);

    expect(nextRequest, isNotNull);
    expect(nextRequest!.startStageIndex, 2);
    expect(nextRequest.stageCount, 2);

    final second = planner.plan(
      stages: descriptors,
      startStageIndex: nextRequest.startStageIndex,
      stageCount: nextRequest.stageCount,
    );

    expect(second.startStageIndex, 2);
    expect(second.loadedStageCount, 2);

    // Não acumulou as duas stages anteriores.
    expect(second.pathElementIds, <String>['element-2', 'element-3']);

    final previousRequest = policy.previous(second);

    expect(previousRequest, isNotNull);
    expect(previousRequest!.startStageIndex, 0);
    expect(previousRequest.stageCount, 2);

    final last = planner.plan(
      stages: descriptors,
      startStageIndex: 4,
      stageCount: 2,
    );

    expect(last.loadedStageCount, 1);
    expect(last.hasNext, isFalse);
    expect(policy.next(last), isNull);
  });

  test(
    'percurso com 1000 stages continua a ler somente 4 estados locais',
    () async {
      const totalStages = 1000;
      const windowSize = 4;

      final path = _buildPath(totalStages);

      var catalogLoadCount = 0;
      var projectionRowsRequested = 0;
      var syncActivitiesRequested = 0;

      List<String>? requestedProjectionIds;

      final coordinator = LearningMapWindowCoordinator(
        loadActiveContent: (learningPathId) async {
          catalogLoadCount++;

          return LearningMapActiveContentSnapshot(
            path: path,
            packageVersion: 9,
            recoveredFromFallback: false,
          );
        },
        loadWindowProjection:
            ({
              required String accountId,
              required String learningPathId,
              required Iterable<String> pathElementIds,
            }) async {
              final ids = pathElementIds.toList(growable: false);

              requestedProjectionIds = ids;
              projectionRowsRequested += ids.length;

              return ids.map(_projection).toList(growable: false);
            },
        loadWindowSync:
            ({
              required String accountId,
              required String learningPathId,
              required Iterable<String> activityIds,
            }) async {
              final ids = activityIds.toList(growable: false);

              syncActivitiesRequested += ids.length;

              return const <String, ProgressSyncState>{};
            },
        loadGlobalRecommendations:
            ({
              required String accountId,
              required String learningPathId,
            }) async {
              return <LearningProgressProjectionEntry>[
                _projection('element-999', recommendationRank: 0),
              ];
            },
        loadGlobalCounts:
            ({
              required String accountId,
              required String learningPathId,
            }) async {
              return _counts(totalStages);
            },
        policy: const LearningMapStageWindowPolicy(
          initialStageCount: windowSize,
          segmentStageCount: windowSize,
        ),
      );

      final session = await coordinator.open(
        accountId: 'account-1',
        learningPathId: 'path-1',
        locale: 'pt-PT',
      );

      final composition = await session.loadInitial();

      expect(catalogLoadCount, 1);
      expect(session.totalStageCount, 1000);

      // Prova estrutural de escala:
      // 1000 stages authored, mas somente 4 rows de projection.
      expect(projectionRowsRequested, 4);
      expect(syncActivitiesRequested, 4);

      expect(requestedProjectionIds, <String>[
        'element-0',
        'element-1',
        'element-2',
        'element-3',
      ]);

      expect(composition.model.elements.length, 4);

      // Métricas continuam referentes ao percurso inteiro.
      expect(composition.model.totalActivityCount, 1000);

      expect(composition.model.completedActivityCount, 0);

      // A recomendação global não é perdida apenas por estar longe.
      expect(
        composition.primaryGlobalRecommendation?.pathElementId,
        'element-999',
      );

      expect(composition.primaryGlobalRecommendationIsLoaded, isFalse);
    },
  );
}

LearningPath _buildPath(int stageCount) {
  if (stageCount <= 0) {
    throw ArgumentError.value(stageCount, 'stageCount');
  }

  final activities = List<Activity>.generate(
    stageCount,
    _activity,
    growable: false,
  );

  final stages = List<Stage>.generate(stageCount, _stage, growable: false);

  return LearningPath(
    id: LearningPathId('path-1'),
    schemaVersion: SchemaVersion(1),
    defaultLocale: 'en',
    title: LocalizedText(const <String, String>{
      'en': 'Large mobility path',
      'pt-PT': 'Percurso de mobilidade',
    }),
    journeys: <Journey>[
      Journey(
        id: JourneyId('journey-1'),
        title: LocalizedText(const <String, String>{
          'en': 'Mobility journey',
          'pt-PT': 'Jornada de mobilidade',
        }),
        stages: stages,
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

LearningProgressProjectionEntry _projection(
  String pathElementId, {
  int? recommendationRank,
}) {
  final suffix = pathElementId.substring('element-'.length);

  return LearningProgressProjectionEntry(
    pathElementId: pathElementId,
    activityId: 'activity-$suffix',
    state: LearningActivityState.available,
    reason: ProgressionReason.ready,
    recommendationRank: recommendationRank,
    packageVersion: 9,
    updatedAt: DateTime.utc(2026, 9, 14, 14),
  );
}

LearningProgressProjectionCounts _counts(int totalStages) {
  return LearningProgressProjectionCounts(
    projectionRowCount: totalStages,
    totalActivityCount: totalStages,
    completedActivityCount: 0,
    minPackageVersion: 9,
    maxPackageVersion: 9,
  );
}

List<LearningMapStageDescriptor> _descriptors(LearningPath path) {
  final result = <LearningMapStageDescriptor>[];

  for (final journey in path.journeys) {
    for (final stage in journey.stages) {
      result.add(
        LearningMapStageDescriptor(
          journeyId: journey.id.value,
          stageId: stage.id.value,
          pathElementIds: stage.elements.map((element) => element.id.value),
          activityIds: stage.elements.map(
            (element) => element.activityId!.value,
          ),
        ),
      );
    }
  }

  return result;
}
