import 'dart:async';

import 'package:dailytalk_mobile/data/repositories/learning_progress_read_repository.dart';
import 'package:dailytalk_mobile/domain/learning/domain_ids.dart';
import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/learning_models.dart';
import 'package:dailytalk_mobile/domain/learning/progression_engine.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_activity_navigation.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_read_service.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_window_controller.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_window_segment_controls.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_window_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('segment controls expose range and boundary availability', (
    tester,
  ) async {
    var previousCount = 0;
    var nextCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LearningMapWindowSegmentControls(
            startStageIndex: 0,
            loadedStageCount: 2,
            totalStageCount: 6,
            canPrevious: false,
            canNext: true,
            isBusy: false,
            hasError: false,
            onPrevious: () {
              previousCount++;
            },
            onNext: () {
              nextCount++;
            },
          ),
        ),
      ),
    );

    expect(find.text('1\u20132 / 6'), findsOneWidget);

    final previous = tester.widget<IconButton>(
      find.byKey(const Key('learning-map-window-previous-segment')),
    );

    final next = tester.widget<IconButton>(
      find.byKey(const Key('learning-map-window-next-segment')),
    );

    expect(previous.onPressed, isNull);
    expect(next.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('learning-map-window-next-segment')));

    await tester.pump();

    expect(previousCount, 0);
    expect(nextCount, 1);
  });

  testWidgets('busy state disables both controls and shows progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LearningMapWindowSegmentControls(
            startStageIndex: 2,
            loadedStageCount: 2,
            totalStageCount: 6,
            canPrevious: true,
            canNext: true,
            isBusy: true,
            hasError: false,
            onPrevious: () {},
            onNext: () {},
          ),
        ),
      ),
    );

    final previous = tester.widget<IconButton>(
      find.byKey(const Key('learning-map-window-previous-segment')),
    );

    final next = tester.widget<IconButton>(
      find.byKey(const Key('learning-map-window-next-segment')),
    );

    expect(previous.onPressed, isNull);
    expect(next.onPressed, isNull);

    expect(
      find.byKey(const Key('learning-map-window-segment-busy')),
      findsOneWidget,
    );
  });

  testWidgets('viewport next and previous load bounded segments', (
    tester,
  ) async {
    final fixture = await _fixture(stageCount: 6);

    final controller = fixture.controller;

    addTearDown(controller.dispose);

    await controller.loadInitial();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: LearningMapWindowViewport(
              controller: controller,
              autoLoad: false,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await _scrollToWindowControls(tester);

    expect(find.text('1\u20132 / 6'), findsOneWidget);

    await tester.tap(find.byKey(const Key('learning-map-window-next-segment')));

    await tester.pumpAndSettle();

    expect(controller.composition!.window.startStageIndex, 2);

    await _scrollToWindowControls(tester);

    expect(find.text('3\u20134 / 6'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('learning-map-window-previous-segment')),
    );

    await tester.pumpAndSettle();

    expect(controller.composition!.window.startStageIndex, 0);

    expect(fixture.projectionRequests, <List<String>>[
      <String>['element-0', 'element-1'],
      <String>['element-2', 'element-3'],
      <String>['element-0', 'element-1'],
    ]);

    expect(fixture.catalogLoadCount, 1);
  });

  testWidgets(
    'failed next keeps current segment and retry repeats same transition',
    (tester) async {
      var failNext = false;

      final fixture = await _fixture(
        stageCount: 6,
        failRead: (ids) => failNext && ids.contains('element-2'),
      );

      final controller = fixture.controller;

      addTearDown(controller.dispose);

      await controller.loadInitial();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 700,
              child: LearningMapWindowViewport(
                controller: controller,
                autoLoad: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await _scrollToWindowControls(tester);

      failNext = true;

      await tester.tap(
        find.byKey(const Key('learning-map-window-next-segment')),
      );

      await tester.pumpAndSettle();

      expect(controller.composition!.window.startStageIndex, 0);

      expect(controller.hasError, isTrue);

      expect(
        find.byKey(const Key('learning-map-window-segment-error')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('learning-map-window-retry-segment')),
        findsOneWidget,
      );

      failNext = false;

      await tester.tap(
        find.byKey(const Key('learning-map-window-retry-segment')),
      );

      await tester.pumpAndSettle();

      expect(controller.composition!.window.startStageIndex, 2);

      expect(controller.hasError, isFalse);

      expect(
        find.byKey(const Key('learning-map-window-segment-error')),
        findsNothing,
      );
    },
  );

  testWidgets('segment controls disable while activity flow is running', (
    tester,
  ) async {
    final fixture = await _fixture(stageCount: 6);

    final controller = fixture.controller;

    addTearDown(controller.dispose);

    await controller.loadInitial();
    await controller.loadNext();

    final gate = Completer<LearningMapActivityNavigationOutcome>();

    final currentElement = controller.composition!.model.elements.first;

    final activityFuture = controller.openActivityAndRefresh(
      currentElement,
      openActivity: (_) => gate.future,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: LearningMapWindowViewport(
              controller: controller,
              autoLoad: false,
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(controller.isActivityFlowRunning, isTrue);

    await _scrollToWindowControls(tester);

    final previous = tester.widget<IconButton>(
      find.byKey(const Key('learning-map-window-previous-segment')),
    );

    final next = tester.widget<IconButton>(
      find.byKey(const Key('learning-map-window-next-segment')),
    );

    expect(previous.onPressed, isNull);
    expect(next.onPressed, isNull);

    expect(
      find.byKey(const Key('learning-map-window-segment-busy')),
      findsOneWidget,
    );

    gate.complete(LearningMapActivityNavigationOutcome.blocked);

    await activityFuture;
    await tester.pumpAndSettle();

    expect(controller.isActivityFlowRunning, isFalse);
  });

  testWidgets('viewport hides controls when the whole path fits one window', (
    tester,
  ) async {
    final fixture = await _fixture(stageCount: 2);

    final controller = fixture.controller;

    addTearDown(controller.dispose);

    await controller.loadInitial();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: LearningMapWindowViewport(
              controller: controller,
              autoLoad: false,
              footer: const SizedBox(
                key: Key('learning-map-test-footer'),
                height: 120,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('learning-map-window-previous-segment')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('learning-map-window-next-segment')),
      findsNothing,
    );

    await _scrollToMapBottom(tester);

    expect(find.byKey(const Key('learning-map-test-footer')), findsOneWidget);
  });
}

Future<void> _scrollToWindowControls(WidgetTester tester) async {
  for (var attempt = 0; attempt < 12; attempt++) {
    if (find
        .byKey(const Key('learning-map-window-next-segment'))
        .evaluate()
        .isNotEmpty) {
      return;
    }

    await tester.drag(
      find.byKey(const Key('learning-map-scroll-view')),
      const Offset(0, -500),
    );

    // The busy-state regression intentionally keeps an indeterminate progress
    // animation alive. pumpAndSettle() can therefore never settle here.
    await tester.pump(const Duration(milliseconds: 50));
  }

  fail('Segment controls did not become visible at the end of the map scroll.');
}

Future<void> _scrollToMapBottom(WidgetTester tester) async {
  for (var attempt = 0; attempt < 12; attempt++) {
    if (find
        .byKey(const Key('learning-map-test-footer'))
        .evaluate()
        .isNotEmpty) {
      return;
    }

    await tester.drag(
      find.byKey(const Key('learning-map-scroll-view')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
  }

  fail('Footer did not become visible at the end of the map scroll.');
}

Future<_Fixture> _fixture({
  required int stageCount,
  bool Function(List<String> ids)? failRead,
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

          if (failRead != null && failRead(ids)) {
            throw StateError('synthetic segment read failure');
          }

          return ids.map(_projection).toList(growable: false);
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
          return <LearningProgressProjectionEntry>[_projection('element-0')];
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
      'en': 'Segment controls path',
      'pt-PT': 'Percurso segmentado',
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
    recommendationRank: index == 0 ? 0 : null,
    packageVersion: 9,
    updatedAt: DateTime.utc(2026, 9, 14, 16, 30),
  );
}
