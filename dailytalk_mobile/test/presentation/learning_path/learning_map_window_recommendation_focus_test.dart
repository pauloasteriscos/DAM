import 'package:dailytalk_mobile/data/repositories/learning_progress_read_repository.dart';
import 'package:dailytalk_mobile/domain/learning/domain_ids.dart';
import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/learning_models.dart';
import 'package:dailytalk_mobile/domain/learning/progression_engine.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_read_service.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_window_controller.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_window_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('policy localiza segmento com initial e segment diferentes', () {
    const policy = LearningMapStageWindowPolicy(
      initialStageCount: 3,
      segmentStageCount: 2,
    );

    final initial = policy.containingStageIndex(
      stageIndex: 2,
      totalStageCount: 10,
    );
    expect(initial.startStageIndex, 0);
    expect(initial.stageCount, 3);

    final second = policy.containingStageIndex(
      stageIndex: 3,
      totalStageCount: 10,
    );
    expect(second.startStageIndex, 3);
    expect(second.stageCount, 2);

    final third = policy.containingStageIndex(
      stageIndex: 6,
      totalStageCount: 10,
    );
    expect(third.startStageIndex, 5);
    expect(third.stageCount, 2);

    final last = policy.containingStageIndex(
      stageIndex: 9,
      totalStageCount: 10,
    );
    expect(last.startStageIndex, 9);
    expect(last.stageCount, 2);
  });

  test(
    'sessao localiza PathElement diretamente no segmento authored',
    () async {
      final fixture = await _fixture(
        stageCount: 10,
        initialSize: 3,
        segmentSize: 2,
        recommendations: const <int, int>{8: 0},
      );

      final request = fixture.session.requestContainingPathElement('element-8');

      expect(request, isNotNull);
      expect(request!.startStageIndex, 7);
      expect(request.stageCount, 2);

      expect(
        fixture.session.requestContainingPathElement('does-not-exist'),
        isNull,
      );

      expect(fixture.catalogLoadCount, 1);
    },
  );

  test(
    'controller salta diretamente para recommendation global distante',
    () async {
      final fixture = await _fixture(
        stageCount: 12,
        initialSize: 2,
        segmentSize: 2,
        recommendations: const <int, int>{10: 0},
      );

      final controller = fixture.controller;
      addTearDown(controller.dispose);

      expect(await controller.loadInitial(), isTrue);

      final focused = await controller.focusGlobalRecommendation();

      expect(focused, isNotNull);
      expect(focused!.pathElementId, 'element-10');

      expect(controller.composition!.window.startStageIndex, 10);

      expect(fixture.projectionRequests, <List<String>>[
        <String>['element-0', 'element-1'],
        <String>['element-10', 'element-11'],
      ]);

      expect(fixture.catalogLoadCount, 1);
    },
  );

  test('recommendation unsupported e ignorada', () async {
    final fixture = await _fixture(
      stageCount: 10,
      initialSize: 2,
      segmentSize: 2,
      recommendations: const <int, int>{5: 0, 7: 1},
      activityTypes: const <int, LearningActivityType>{
        5: LearningActivityType.speech,
        7: LearningActivityType.dialogue,
      },
    );

    final controller = fixture.controller;
    addTearDown(controller.dispose);

    await controller.loadInitial();

    final focused = await controller.focusGlobalRecommendation();

    expect(focused, isNotNull);
    expect(focused!.pathElementId, 'element-7');

    expect(controller.composition!.window.startStageIndex, 6);

    expect(fixture.projectionRequests, <List<String>>[
      <String>['element-0', 'element-1'],
      <String>['element-4', 'element-5'],
      <String>['element-6', 'element-7'],
    ]);
  });

  test('recommendation locked e ignorada', () async {
    final fixture = await _fixture(
      stageCount: 10,
      initialSize: 2,
      segmentSize: 2,
      recommendations: const <int, int>{4: 0, 6: 1},
      states: const <int, LearningActivityState>{
        4: LearningActivityState.locked,
      },
    );

    final controller = fixture.controller;
    addTearDown(controller.dispose);

    await controller.loadInitial();

    final focused = await controller.focusGlobalRecommendation();

    expect(focused, isNotNull);
    expect(focused!.pathElementId, 'element-6');
    expect(controller.composition!.window.startStageIndex, 6);
  });

  test('sem recommendation navegavel restaura segmento original', () async {
    final fixture = await _fixture(
      stageCount: 8,
      initialSize: 2,
      segmentSize: 2,
      recommendations: const <int, int>{5: 0},
      activityTypes: const <int, LearningActivityType>{
        5: LearningActivityType.speech,
      },
    );

    final controller = fixture.controller;
    addTearDown(controller.dispose);

    await controller.loadInitial();
    controller.rememberCurrentScrollOffset(123);

    final focused = await controller.focusGlobalRecommendation();

    expect(focused, isNull);
    expect(controller.composition!.window.startStageIndex, 0);
    expect(controller.currentScrollOffset, 123);

    expect(fixture.projectionRequests, <List<String>>[
      <String>['element-0', 'element-1'],
      <String>['element-4', 'element-5'],
      <String>['element-0', 'element-1'],
    ]);
  });
}

Future<_Fixture> _fixture({
  required int stageCount,
  required int initialSize,
  required int segmentSize,
  required Map<int, int> recommendations,
  Map<int, LearningActivityType> activityTypes =
      const <int, LearningActivityType>{},
  Map<int, LearningActivityState> states = const <int, LearningActivityState>{},
}) async {
  final path = _buildPath(stageCount, activityTypes);

  var catalogLoadCount = 0;
  final projectionRequests = <List<String>>[];

  final coordinator = LearningMapWindowCoordinator(
    loadActiveContent: (_) async {
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

          projectionRequests.add(ids);

          return ids
              .map((id) => _projection(id, recommendations, states))
              .toList(growable: false);
        },
    loadWindowSync:
        ({
          required String accountId,
          required String learningPathId,
          required Iterable<String> activityIds,
        }) async {
          return const <String, ProgressSyncState>{};
        },
    loadGlobalRecommendations:
        ({required String accountId, required String learningPathId}) async {
          return recommendations.entries
              .map(
                (entry) => _projection(
                  'element-${entry.key}',
                  recommendations,
                  states,
                ),
              )
              .toList(growable: false);
        },
    loadGlobalCounts:
        ({required String accountId, required String learningPathId}) async {
          return LearningProgressProjectionCounts(
            projectionRowCount: stageCount,
            totalActivityCount: stageCount,
            completedActivityCount: 0,
            minPackageVersion: 9,
            maxPackageVersion: 9,
          );
        },
    policy: LearningMapStageWindowPolicy(
      initialStageCount: initialSize,
      segmentStageCount: segmentSize,
    ),
  );

  final session = await coordinator.open(
    accountId: 'account-1',
    learningPathId: 'path-1',
    locale: 'pt-PT',
  );

  return _Fixture(
    session: session,
    controller: LearningMapWindowController(session: session),
    projectionRequests: projectionRequests,
    catalogCounter: () => catalogLoadCount,
  );
}

final class _Fixture {
  const _Fixture({
    required this.session,
    required this.controller,
    required this.projectionRequests,
    required int Function() catalogCounter,
  }) : _catalogCounter = catalogCounter;

  final LearningMapWindowSession session;
  final LearningMapWindowController controller;
  final List<List<String>> projectionRequests;
  final int Function() _catalogCounter;

  int get catalogLoadCount => _catalogCounter();
}

LearningPath _buildPath(int stageCount, Map<int, LearningActivityType> types) {
  return LearningPath(
    id: LearningPathId('path-1'),
    schemaVersion: SchemaVersion(1),
    defaultLocale: 'en',
    title: LocalizedText(const <String, String>{
      'en': 'Global recommendation path',
      'pt-PT': 'Percurso recomendado',
    }),
    journeys: <Journey>[
      Journey(
        id: JourneyId('journey-1'),
        title: LocalizedText(const <String, String>{
          'en': 'Journey',
          'pt-PT': 'Jornada',
        }),
        stages: List<Stage>.generate(stageCount, _stage, growable: false),
      ),
    ],
    activities: List<Activity>.generate(
      stageCount,
      (index) =>
          _activity(index, types[index] ?? LearningActivityType.dialogue),
      growable: false,
    ),
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

Activity _activity(int index, LearningActivityType type) {
  final activityId = ActivityId('activity-$index');

  final revisionId = RevisionId('activity-$index-r1');

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
        title: LocalizedText(<String, String>{
          'en': 'Activity $index',
          'pt-PT': 'Atividade $index',
        }),
        instructions: LocalizedText(<String, String>{
          'en': 'Practise.',
          'pt-PT': 'Pratica.',
        }),
        visibility: ContentVisibility.public,
        competencies: const <CompetencyId>{},
      ),
    ],
  );
}

LearningProgressProjectionEntry _projection(
  String pathElementId,
  Map<int, int> recommendations,
  Map<int, LearningActivityState> states,
) {
  final index = int.parse(pathElementId.substring('element-'.length));

  final state = states[index] ?? LearningActivityState.available;

  final reason = switch (state) {
    LearningActivityState.locked => ProgressionReason.prerequisitesNotMet,
    LearningActivityState.available => ProgressionReason.ready,
    LearningActivityState.inProgress => ProgressionReason.attemptStarted,
    LearningActivityState.completed => ProgressionReason.completed,
  };

  return LearningProgressProjectionEntry(
    pathElementId: pathElementId,
    activityId: 'activity-$index',
    state: state,
    reason: reason,
    recommendationRank: recommendations[index],
    packageVersion: 9,
    updatedAt: DateTime.utc(2026, 9, 14, 15, 30),
  );
}
