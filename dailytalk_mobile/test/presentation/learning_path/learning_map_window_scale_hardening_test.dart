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
  test('1003-stage path loads a bounded three-stage final segment', () async {
    const stageCount = 1003;
    const windowSize = 4;

    final fixture = await _fixture(
      stageCount: stageCount,
      windowSize: windowSize,
    );

    final controller = fixture.controller;
    addTearDown(controller.dispose);

    expect(await controller.loadInitial(), isTrue);

    expect(await controller.loadContainingPathElement('element-1002'), isTrue);

    final composition = controller.composition!;

    expect(composition.window.startStageIndex, 1000);
    expect(composition.window.loadedStageCount, 3);
    expect(composition.window.totalStageCount, stageCount);
    expect(composition.window.hasNext, isFalse);
    expect(composition.window.hasPrevious, isTrue);
    expect(composition.model.elements, hasLength(3));

    expect(fixture.projectionRequests.last, <String>[
      'element-1000',
      'element-1001',
      'element-1002',
    ]);

    expect(fixture.syncRequests.last, <String>[
      'activity-1000',
      'activity-1001',
      'activity-1002',
    ]);

    expect(fixture.catalogLoadCount, 1);
  });

  test(
    'next boundary returns false and preserves the last partial segment',
    () async {
      final fixture = await _fixture(stageCount: 1003, windowSize: 4);

      final controller = fixture.controller;
      addTearDown(controller.dispose);

      await controller.loadInitial();

      await controller.loadContainingPathElement('element-1002');

      final before = controller.composition;

      final readsBefore = fixture.projectionRequests.length;

      expect(controller.canLoadNext, isFalse);

      expect(await controller.loadNext(), isFalse);

      expect(identical(controller.composition, before), isTrue);

      expect(fixture.projectionRequests.length, readsBefore);

      expect(fixture.catalogLoadCount, 1);
    },
  );

  test('repeated distant direct jumps keep reads and model bounded', () async {
    const stageCount = 1003;
    const windowSize = 4;

    final fixture = await _fixture(
      stageCount: stageCount,
      windowSize: windowSize,
    );

    final controller = fixture.controller;
    addTearDown(controller.dispose);

    await controller.loadInitial();

    final targets = <int>[
      120,
      248,
      376,
      504,
      632,
      760,
      888,
      1002,
      4,
      500,
      996,
      44,
    ];

    for (final target in targets) {
      expect(
        await controller.loadContainingPathElement('element-$target'),
        isTrue,
      );

      final composition = controller.composition!;

      expect(composition.model.elements.length, lessThanOrEqualTo(windowSize));

      expect(
        composition.window.loadedStageCount,
        lessThanOrEqualTo(windowSize),
      );
    }

    for (final ids in fixture.projectionRequests) {
      expect(ids.length, lessThanOrEqualTo(windowSize));
    }

    for (final ids in fixture.syncRequests) {
      expect(ids.length, lessThanOrEqualTo(windowSize));
    }

    expect(fixture.projectionRequests.length, 1 + targets.length);

    expect(fixture.catalogLoadCount, 1);
  });

  test(
    'failed distant load preserves current composition and retry succeeds',
    () async {
      var failTarget = false;

      final fixture = await _fixture(
        stageCount: 1003,
        windowSize: 4,
        failProjection: (ids) {
          return failTarget && ids.contains('element-500');
        },
      );

      final controller = fixture.controller;
      addTearDown(controller.dispose);

      await controller.loadInitial();

      final before = controller.composition;

      failTarget = true;

      expect(
        await controller.loadContainingPathElement('element-501'),
        isFalse,
      );

      expect(controller.hasError, isTrue);

      expect(identical(controller.composition, before), isTrue);

      expect(fixture.catalogLoadCount, 1);

      failTarget = false;

      expect(await controller.loadContainingPathElement('element-501'), isTrue);

      expect(controller.hasError, isFalse);

      expect(controller.composition!.window.startStageIndex, 500);

      expect(controller.composition!.model.elements, hasLength(4));

      expect(fixture.catalogLoadCount, 1);
    },
  );
}

Future<_Fixture> _fixture({
  required int stageCount,
  required int windowSize,
  bool Function(List<String> ids)? failProjection,
}) async {
  final path = _buildPath(stageCount);

  var catalogLoadCount = 0;

  final projectionRequests = <List<String>>[];

  final syncRequests = <List<String>>[];

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

          if (failProjection != null && failProjection(ids)) {
            throw StateError('synthetic distant projection failure');
          }

          return ids
              .map((id) => _projection(id, recommendedIndex: stageCount - 1))
              .toList(growable: false);
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
        ({required String accountId, required String learningPathId}) async {
          final recommendedIndex = stageCount - 1;

          return <LearningProgressProjectionEntry>[
            _projection(
              'element-$recommendedIndex',
              recommendedIndex: recommendedIndex,
            ),
          ];
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
      initialStageCount: windowSize,
      segmentStageCount: windowSize,
    ),
  );

  final session = await coordinator.open(
    accountId: 'account-1',
    learningPathId: 'path-1',
    locale: 'pt-PT',
  );

  return _Fixture(
    controller: LearningMapWindowController(session: session),
    projectionRequests: projectionRequests,
    syncRequests: syncRequests,
    catalogCounter: () => catalogLoadCount,
  );
}

final class _Fixture {
  const _Fixture({
    required this.controller,
    required this.projectionRequests,
    required this.syncRequests,
    required int Function() catalogCounter,
  }) : _catalogCounter = catalogCounter;

  final LearningMapWindowController controller;

  final List<List<String>> projectionRequests;

  final List<List<String>> syncRequests;

  final int Function() _catalogCounter;

  int get catalogLoadCount => _catalogCounter();
}

LearningPath _buildPath(int stageCount) {
  return LearningPath(
    id: LearningPathId('path-1'),
    schemaVersion: SchemaVersion(1),
    defaultLocale: 'en',
    title: LocalizedText(const <String, String>{
      'en': 'Scale hardening path',
      'pt-PT': 'Percurso de robustez',
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
    activities: List<Activity>.generate(stageCount, _activity, growable: false),
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
        instructions: LocalizedText(const <String, String>{
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
  String pathElementId, {
  required int recommendedIndex,
}) {
  final index = int.parse(pathElementId.substring('element-'.length));

  return LearningProgressProjectionEntry(
    pathElementId: pathElementId,
    activityId: 'activity-$index',
    state: LearningActivityState.available,
    reason: ProgressionReason.ready,
    recommendationRank: index == recommendedIndex ? 0 : null,
    packageVersion: 9,
    updatedAt: DateTime.utc(2026, 9, 14, 18),
  );
}
