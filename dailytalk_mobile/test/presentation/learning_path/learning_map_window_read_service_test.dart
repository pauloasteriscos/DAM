import 'package:dailytalk_mobile/data/repositories/learning_progress_read_repository.dart';
import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/progression_engine.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_stage_window.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_window_read_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'reads only window state while preserving global recommendation and counts',
    () async {
      List<String>? projectionIds;
      List<String>? syncIds;

      final service = LearningMapWindowReadService(
        loadCatalog: (_) async => _catalog(),
        loadWindowProjection:
            ({
              required String accountId,
              required String learningPathId,
              required Iterable<String> pathElementIds,
            }) async {
              expect(accountId, 'account-1');
              expect(learningPathId, 'path-1');

              projectionIds = pathElementIds.toList(growable: false);

              return projectionIds!
                  .map(_projectionForWindow)
                  .toList(growable: false);
            },
        loadWindowSync:
            ({
              required String accountId,
              required String learningPathId,
              required Iterable<String> activityIds,
            }) async {
              syncIds = activityIds.toList(growable: false);

              return <String, ProgressSyncState>{
                'activity-b': ProgressSyncState.pending,
              };
            },
        loadGlobalRecommendations:
            ({
              required String accountId,
              required String learningPathId,
            }) async {
              return <LearningProgressProjectionEntry>[
                _projection(
                  elementId: 'element-3-a',
                  activityId: 'activity-d',
                  recommendationRank: 0,
                ),
              ];
            },
        loadGlobalCounts:
            ({
              required String accountId,
              required String learningPathId,
            }) async {
              return LearningProgressProjectionCounts(
                projectionRowCount: 6,
                totalActivityCount: 6,
                completedActivityCount: 2,
                minPackageVersion: 9,
                maxPackageVersion: 9,
              );
            },
      );

      final snapshot = await service.load(
        accountId: ' account-1 ',
        learningPathId: ' path-1 ',
        startStageIndex: 1,
        stageCount: 2,
      );

      expect(projectionIds, <String>[
        'element-1-a',
        'element-1-b',
        'element-2-a',
      ]);

      expect(syncIds, <String>['activity-b', 'activity-shared', 'activity-c']);

      expect(snapshot.window.pathElementIds, projectionIds);

      expect(
        snapshot.globalRecommendations.single.pathElementId,
        'element-3-a',
      );

      expect(snapshot.window.pathElementIds, isNot(contains('element-3-a')));

      expect(snapshot.globalCounts.totalActivityCount, 6);

      expect(snapshot.globalCounts.completedActivityCount, 2);

      expect(snapshot.packageVersion, 9);
      expect(snapshot.recoveredFromFallback, isTrue);
    },
  );

  test('catalog path mismatch fails before window readers', () async {
    var readerCalled = false;

    final service = LearningMapWindowReadService(
      loadCatalog: (_) async {
        return LearningMapWindowCatalogSnapshot(
          learningPathId: 'other-path',
          packageVersion: 9,
          recoveredFromFallback: false,
          stages: _catalog().stages,
        );
      },
      loadWindowProjection:
          ({
            required String accountId,
            required String learningPathId,
            required Iterable<String> pathElementIds,
          }) async {
            readerCalled = true;
            return const <LearningProgressProjectionEntry>[];
          },
      loadWindowSync:
          ({
            required String accountId,
            required String learningPathId,
            required Iterable<String> activityIds,
          }) async {
            readerCalled = true;
            return const <String, ProgressSyncState>{};
          },
      loadGlobalRecommendations:
          ({required String accountId, required String learningPathId}) async {
            readerCalled = true;
            return const <LearningProgressProjectionEntry>[];
          },
      loadGlobalCounts:
          ({required String accountId, required String learningPathId}) async {
            readerCalled = true;
            return LearningProgressProjectionCounts(
              projectionRowCount: 1,
              totalActivityCount: 1,
              completedActivityCount: 0,
              minPackageVersion: 9,
              maxPackageVersion: 9,
            );
          },
    );

    await expectLater(
      service.load(
        accountId: 'account-1',
        learningPathId: 'path-1',
        startStageIndex: 0,
        stageCount: 1,
      ),
      throwsStateError,
    );

    expect(readerCalled, isFalse);
  });

  test('missing window projection fails closed', () async {
    final service = _service(
      projectionLoader:
          ({
            required String accountId,
            required String learningPathId,
            required Iterable<String> pathElementIds,
          }) async {
            final ids = pathElementIds.toList(growable: false);

            return <LearningProgressProjectionEntry>[
              _projectionForWindow(ids.first),
            ];
          },
    );

    await expectLater(
      service.load(
        accountId: 'account-1',
        learningPathId: 'path-1',
        startStageIndex: 1,
        stageCount: 1,
      ),
      throwsStateError,
    );
  });

  test('unexpected sync activity fails closed', () async {
    final service = _service(
      syncLoader:
          ({
            required String accountId,
            required String learningPathId,
            required Iterable<String> activityIds,
          }) async {
            return <String, ProgressSyncState>{
              'outside-window': ProgressSyncState.pending,
            };
          },
    );

    await expectLater(
      service.load(
        accountId: 'account-1',
        learningPathId: 'path-1',
        startStageIndex: 1,
        stageCount: 1,
      ),
      throwsStateError,
    );
  });

  test('global recommendation outside catalog fails closed', () async {
    final service = _service(
      recommendationLoader:
          ({required String accountId, required String learningPathId}) async {
            return <LearningProgressProjectionEntry>[
              _projection(
                elementId: 'unknown-element',
                activityId: 'activity-x',
                recommendationRank: 0,
              ),
            ];
          },
    );

    await expectLater(
      service.load(
        accountId: 'account-1',
        learningPathId: 'path-1',
        startStageIndex: 0,
        stageCount: 1,
      ),
      throwsStateError,
    );
  });

  test('mixed global package counts fail closed', () async {
    final service = _service(
      countsLoader:
          ({required String accountId, required String learningPathId}) async {
            return LearningProgressProjectionCounts(
              projectionRowCount: 6,
              totalActivityCount: 6,
              completedActivityCount: 2,
              minPackageVersion: 9,
              maxPackageVersion: 10,
            );
          },
    );

    await expectLater(
      service.load(
        accountId: 'account-1',
        learningPathId: 'path-1',
        startStageIndex: 0,
        stageCount: 1,
      ),
      throwsStateError,
    );
  });
}

LearningMapWindowReadService _service({
  LearningMapWindowProjectionLoader? projectionLoader,
  LearningMapWindowSyncLoader? syncLoader,
  LearningMapWindowRecommendationLoader? recommendationLoader,
  LearningMapWindowCountsLoader? countsLoader,
}) {
  return LearningMapWindowReadService(
    loadCatalog: (_) async => _catalog(),
    loadWindowProjection:
        projectionLoader ??
        ({
          required String accountId,
          required String learningPathId,
          required Iterable<String> pathElementIds,
        }) async {
          return pathElementIds
              .map(_projectionForWindow)
              .toList(growable: false);
        },
    loadWindowSync:
        syncLoader ??
        ({
          required String accountId,
          required String learningPathId,
          required Iterable<String> activityIds,
        }) async {
          return const <String, ProgressSyncState>{};
        },
    loadGlobalRecommendations:
        recommendationLoader ??
        ({required String accountId, required String learningPathId}) async {
          return <LearningProgressProjectionEntry>[
            _projection(
              elementId: 'element-3-a',
              activityId: 'activity-d',
              recommendationRank: 0,
            ),
          ];
        },
    loadGlobalCounts:
        countsLoader ??
        ({required String accountId, required String learningPathId}) async {
          return LearningProgressProjectionCounts(
            projectionRowCount: 6,
            totalActivityCount: 6,
            completedActivityCount: 2,
            minPackageVersion: 9,
            maxPackageVersion: 9,
          );
        },
  );
}

LearningMapWindowCatalogSnapshot _catalog() {
  return LearningMapWindowCatalogSnapshot(
    learningPathId: 'path-1',
    packageVersion: 9,
    recoveredFromFallback: true,
    stages: <LearningMapStageDescriptor>[
      LearningMapStageDescriptor(
        journeyId: 'journey-a',
        stageId: 'stage-0',
        pathElementIds: const <String>['element-0-a', 'element-0-b'],
        activityIds: const <String>['activity-a', 'activity-shared'],
      ),
      LearningMapStageDescriptor(
        journeyId: 'journey-a',
        stageId: 'stage-1',
        pathElementIds: const <String>['element-1-a', 'element-1-b'],
        activityIds: const <String>['activity-b', 'activity-shared'],
      ),
      LearningMapStageDescriptor(
        journeyId: 'journey-b',
        stageId: 'stage-2',
        pathElementIds: const <String>['element-2-a'],
        activityIds: const <String>['activity-c'],
      ),
      LearningMapStageDescriptor(
        journeyId: 'journey-b',
        stageId: 'stage-3',
        pathElementIds: const <String>['element-3-a'],
        activityIds: const <String>['activity-d'],
      ),
    ],
  );
}

LearningProgressProjectionEntry _projectionForWindow(String elementId) {
  return switch (elementId) {
    'element-0-a' => _projection(
      elementId: elementId,
      activityId: 'activity-a',
    ),
    'element-0-b' => _projection(
      elementId: elementId,
      activityId: 'activity-shared',
    ),
    'element-1-a' => _projection(
      elementId: elementId,
      activityId: 'activity-b',
    ),
    'element-1-b' => _projection(
      elementId: elementId,
      activityId: 'activity-shared',
    ),
    'element-2-a' => _projection(
      elementId: elementId,
      activityId: 'activity-c',
    ),
    'element-3-a' => _projection(
      elementId: elementId,
      activityId: 'activity-d',
    ),
    _ => throw StateError('Unknown test element: $elementId'),
  };
}

LearningProgressProjectionEntry _projection({
  required String elementId,
  required String? activityId,
  int? recommendationRank,
}) {
  return LearningProgressProjectionEntry(
    pathElementId: elementId,
    activityId: activityId,
    state: LearningActivityState.available,
    reason: ProgressionReason.ready,
    recommendationRank: recommendationRank,
    packageVersion: 9,
    updatedAt: DateTime.utc(2026, 9, 14, 12),
  );
}
