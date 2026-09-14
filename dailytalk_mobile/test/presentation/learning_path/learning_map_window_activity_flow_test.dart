import 'dart:async';

import 'package:dailytalk_mobile/data/repositories/learning_progress_read_repository.dart';
import 'package:dailytalk_mobile/domain/learning/domain_ids.dart';
import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/learning_models.dart';
import 'package:dailytalk_mobile/domain/learning/progression_engine.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_activity_navigation.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_read_service.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_view.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_window_controller.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_window_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'opened route reloads current window then follows global recommendation',
    () async {
      final recommendations = <int, int>{0: 0};

      final fixture = await _fixture(
        stageCount: 8,
        recommendations: recommendations,
      );

      final controller = fixture.controller;

      addTearDown(controller.dispose);

      expect(await controller.loadInitial(), isTrue);

      final current = controller.composition!.model.elements.first;

      final result = await controller.openActivityAndRefresh(
        current,
        openActivity: (_) async {
          // Simulates progress already persisted by the activity layer
          // before the route returns.
          recommendations
            ..clear()
            ..[6] = 0
            ..[1] = 1;

          return LearningMapActivityNavigationOutcome.opened;
        },
      );

      expect(result, isNotNull);
      expect(
        result!.navigationOutcome,
        LearningMapActivityNavigationOutcome.opened,
      );
      expect(result.refreshedAfterReturn, isTrue);
      expect(result.openedAndRefreshed, isTrue);

      // The refreshed current-window model contains element-1 as a local
      // recommendation, but global rank 0 is element-6. C.2B must ignore
      // MissionFlow.nextMission as global authority.
      expect(result.focusedGlobalRecommendation?.pathElementId, 'element-6');

      expect(controller.composition!.window.startStageIndex, 6);

      expect(fixture.projectionRequests, <List<String>>[
        <String>['element-0', 'element-1'],
        <String>['element-0', 'element-1'],
        <String>['element-6', 'element-7'],
      ]);

      expect(fixture.catalogLoadCount, 1);
    },
  );

  test(
    'non-open navigation does not reload or focus another segment',
    () async {
      final recommendations = <int, int>{0: 0};

      final fixture = await _fixture(
        stageCount: 6,
        recommendations: recommendations,
      );

      final controller = fixture.controller;

      addTearDown(controller.dispose);

      await controller.loadInitial();

      final before = controller.composition;

      final result = await controller.openActivityAndRefresh(
        before!.model.elements.first,
        openActivity: (_) async => LearningMapActivityNavigationOutcome.blocked,
      );

      expect(result, isNotNull);
      expect(
        result!.navigationOutcome,
        LearningMapActivityNavigationOutcome.blocked,
      );
      expect(result.refreshedAfterReturn, isFalse);
      expect(result.focusedGlobalRecommendation, isNull);
      expect(identical(controller.composition, before), isTrue);
      expect(fixture.projectionRequests, hasLength(1));
    },
  );

  test('double open is refused while first activity flow is running', () async {
    final recommendations = <int, int>{0: 0};

    final fixture = await _fixture(
      stageCount: 4,
      recommendations: recommendations,
    );

    final controller = fixture.controller;

    addTearDown(controller.dispose);

    await controller.loadInitial();

    final gate = Completer<LearningMapActivityNavigationOutcome>();

    var openCount = 0;

    final element = controller.composition!.model.elements.first;

    final first = controller.openActivityAndRefresh(
      element,
      openActivity: (_) {
        openCount++;
        return gate.future;
      },
    );

    await Future<void>.delayed(Duration.zero);

    expect(controller.isActivityFlowRunning, isTrue);

    final second = await controller.openActivityAndRefresh(
      element,
      openActivity: (_) async {
        openCount++;
        return LearningMapActivityNavigationOutcome.opened;
      },
    );

    expect(second, isNull);
    expect(openCount, 1);

    gate.complete(LearningMapActivityNavigationOutcome.blocked);

    final firstResult = await first;

    expect(firstResult, isNotNull);
    expect(
      firstResult!.navigationOutcome,
      LearningMapActivityNavigationOutcome.blocked,
    );
    expect(controller.isActivityFlowRunning, isFalse);
  });

  testWidgets(
    'viewport built-in callback opens then reloads and focuses globally',
    (tester) async {
      final recommendations = <int, int>{0: 0};

      final fixture = await _fixture(
        stageCount: 6,
        recommendations: recommendations,
      );

      final controller = fixture.controller;

      addTearDown(controller.dispose);

      await controller.loadInitial();

      var openCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 700,
              child: LearningMapWindowViewport(
                controller: controller,
                autoLoad: false,
                activityOpenAction: (_) async {
                  openCount++;

                  recommendations
                    ..clear()
                    ..[4] = 0;

                  return LearningMapActivityNavigationOutcome.opened;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final view = tester.widget<LearningMapView>(find.byType(LearningMapView));

      expect(view.onActivityTap, isNotNull);

      view.onActivityTap!(view.model.elements.first);

      await tester.pumpAndSettle();

      expect(openCount, 1);
      expect(controller.composition!.window.startStageIndex, 4);
      expect(fixture.catalogLoadCount, 1);
    },
  );

  testWidgets(
    'custom onActivityTap remains an override and prevents built-in open',
    (tester) async {
      final recommendations = <int, int>{0: 0};

      final fixture = await _fixture(
        stageCount: 4,
        recommendations: recommendations,
      );

      final controller = fixture.controller;

      addTearDown(controller.dispose);

      await controller.loadInitial();

      var customTapCount = 0;
      var builtInOpenCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 700,
              child: LearningMapWindowViewport(
                controller: controller,
                autoLoad: false,
                onActivityTap: (_) {
                  customTapCount++;
                },
                activityOpenAction: (_) async {
                  builtInOpenCount++;

                  return LearningMapActivityNavigationOutcome.opened;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final view = tester.widget<LearningMapView>(find.byType(LearningMapView));

      view.onActivityTap!(view.model.elements.first);

      await tester.pump();

      expect(customTapCount, 1);
      expect(builtInOpenCount, 0);
      expect(fixture.projectionRequests, hasLength(1));
    },
  );
}

Future<_Fixture> _fixture({
  required int stageCount,
  required Map<int, int> recommendations,
}) async {
  final path = _buildPath(stageCount);

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
              .map((id) => _projection(id, recommendations))
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
                (entry) => _projection('element-${entry.key}', recommendations),
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
    policy: const LearningMapStageWindowPolicy(
      initialStageCount: 2,
      segmentStageCount: 2,
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
    catalogCounter: () => catalogLoadCount,
  );
}

final class _Fixture {
  const _Fixture({
    required this.controller,
    required this.projectionRequests,
    required int Function() catalogCounter,
  }) : _catalogCounter = catalogCounter;

  final LearningMapWindowController controller;

  final List<List<String>> projectionRequests;

  final int Function() _catalogCounter;

  int get catalogLoadCount => _catalogCounter();
}

LearningPath _buildPath(int stageCount) {
  return LearningPath(
    id: LearningPathId('path-1'),
    schemaVersion: SchemaVersion(1),
    defaultLocale: 'en',
    title: LocalizedText(const <String, String>{
      'en': 'Activity flow path',
      'pt-PT': 'Percurso de atividade',
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
  String pathElementId,
  Map<int, int> recommendations,
) {
  final index = int.parse(pathElementId.substring('element-'.length));

  return LearningProgressProjectionEntry(
    pathElementId: pathElementId,
    activityId: 'activity-$index',
    state: LearningActivityState.available,
    reason: ProgressionReason.ready,
    recommendationRank: recommendations[index],
    packageVersion: 9,
    updatedAt: DateTime.utc(2026, 9, 14, 16),
  );
}
