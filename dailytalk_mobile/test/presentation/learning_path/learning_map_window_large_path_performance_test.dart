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
  test(
    '1000-stage path stays bounded across repeated segment transitions',
    () async {
      const stageCount = 1000;
      const windowSize = 4;
      const repeatedCycles = 50;

      final fixture = await _fixture(
        stageCount: stageCount,
        windowSize: windowSize,
      );

      final controller = fixture.controller;
      addTearDown(controller.dispose);

      final initialWatch = Stopwatch()..start();

      expect(await controller.loadInitial(), isTrue);

      initialWatch.stop();

      expect(fixture.catalogLoadCount, 1);
      expect(controller.composition!.window.startStageIndex, 0);
      expect(controller.composition!.window.loadedStageCount, windowSize);
      expect(controller.composition!.window.totalStageCount, stageCount);
      expect(controller.composition!.model.elements, hasLength(windowSize));

      final directJumpWatch = Stopwatch()..start();

      expect(await controller.loadContainingPathElement('element-999'), isTrue);

      directJumpWatch.stop();

      expect(controller.composition!.window.startStageIndex, 996);
      expect(controller.composition!.model.elements, hasLength(windowSize));

      // Initial read + direct final-segment read. No intermediate window should
      // have been materialized by the direct authored-index lookup.
      expect(fixture.projectionRequests, hasLength(2));

      expect(fixture.projectionRequests[0], <String>[
        'element-0',
        'element-1',
        'element-2',
        'element-3',
      ]);

      expect(fixture.projectionRequests[1], <String>[
        'element-996',
        'element-997',
        'element-998',
        'element-999',
      ]);

      final transitionMicros = <int>[];

      for (var cycle = 0; cycle < repeatedCycles; cycle++) {
        final previousWatch = Stopwatch()..start();

        expect(await controller.loadPrevious(), isTrue);

        previousWatch.stop();
        transitionMicros.add(previousWatch.elapsedMicroseconds);

        expect(controller.composition!.window.startStageIndex, 992);
        expect(controller.composition!.window.loadedStageCount, windowSize);
        expect(controller.composition!.model.elements, hasLength(windowSize));

        final nextWatch = Stopwatch()..start();

        expect(await controller.loadNext(), isTrue);

        nextWatch.stop();
        transitionMicros.add(nextWatch.elapsedMicroseconds);

        expect(controller.composition!.window.startStageIndex, 996);
        expect(controller.composition!.window.loadedStageCount, windowSize);
        expect(controller.composition!.model.elements, hasLength(windowSize));
      }

      // 2 initial operations + 100 repeated bounded transitions.
      expect(fixture.projectionRequests, hasLength(2 + repeatedCycles * 2));

      for (final ids in fixture.projectionRequests) {
        expect(ids.length, lessThanOrEqualTo(windowSize));
      }

      for (final ids in fixture.syncRequests) {
        expect(ids.length, lessThanOrEqualTo(windowSize));
      }

      expect(
        fixture.projectionRequests.expand((ids) => ids).where((id) {
          final index = int.parse(id.substring('element-'.length));

          return index > 3 && index < 992;
        }),
        isEmpty,
      );

      expect(fixture.catalogLoadCount, 1);

      final sorted = List<int>.of(transitionMicros)..sort();

      final p50 = _percentile(sorted, 0.50);
      final p95 = _percentile(sorted, 0.95);
      final maximum = sorted.last;

      // Measurement only. These timings are host/VM observations, not an
      // Android device pass/fail budget.
      // ignore: avoid_print
      print(
        'DAILYTALK_C45C4A_PERF '
        'stages=$stageCount '
        'window=$windowSize '
        'transitions=${transitionMicros.length} '
        'initial_us=${initialWatch.elapsedMicroseconds} '
        'direct_jump_us=${directJumpWatch.elapsedMicroseconds} '
        'p50_us=$p50 '
        'p95_us=$p95 '
        'max_us=$maximum '
        'projection_reads=${fixture.projectionRequests.length} '
        'catalog_reads=${fixture.catalogLoadCount}',
      );
    },
  );

  test(
    'sampled authored lookups always resolve bounded four-stage segments',
    () async {
      const stageCount = 1000;
      const windowSize = 4;

      final fixture = await _fixture(
        stageCount: stageCount,
        windowSize: windowSize,
      );

      final samples = <int>[0, 1, 3, 4, 127, 499, 998, 999];

      for (final index in samples) {
        final request = fixture.session.requestContainingPathElement(
          'element-$index',
        );

        expect(request, isNotNull);
        expect(request!.stageCount, windowSize);
        expect(request.startStageIndex, (index ~/ windowSize) * windowSize);
      }

      expect(
        fixture.session.requestContainingPathElement('element-1000'),
        isNull,
      );

      expect(fixture.catalogLoadCount, 1);
      expect(fixture.projectionRequests, isEmpty);
      expect(fixture.syncRequests, isEmpty);
    },
  );
}

int _percentile(List<int> sortedValues, double quantile) {
  if (sortedValues.isEmpty) {
    throw ArgumentError.value(
      sortedValues,
      'sortedValues',
      'must not be empty',
    );
  }

  final rawIndex = ((sortedValues.length - 1) * quantile).round();

  return sortedValues[rawIndex.clamp(0, sortedValues.length - 1)];
}

Future<_Fixture> _fixture({
  required int stageCount,
  required int windowSize,
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

          return ids.map(_projection).toList(growable: false);
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
          return <LearningProgressProjectionEntry>[_projection('element-999')];
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
    session: session,
    controller: LearningMapWindowController(session: session),
    projectionRequests: projectionRequests,
    syncRequests: syncRequests,
    catalogCounter: () => catalogLoadCount,
  );
}

final class _Fixture {
  const _Fixture({
    required this.session,
    required this.controller,
    required this.projectionRequests,
    required this.syncRequests,
    required int Function() catalogCounter,
  }) : _catalogCounter = catalogCounter;

  final LearningMapWindowSession session;
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
      'en': 'Large path',
      'pt-PT': 'Percurso extenso',
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

LearningProgressProjectionEntry _projection(String pathElementId) {
  final index = int.parse(pathElementId.substring('element-'.length));

  return LearningProgressProjectionEntry(
    pathElementId: pathElementId,
    activityId: 'activity-$index',
    state: LearningActivityState.available,
    reason: ProgressionReason.ready,
    recommendationRank: index == 999 ? 0 : null,
    packageVersion: 9,
    updatedAt: DateTime.utc(2026, 9, 14, 17),
  );
}
