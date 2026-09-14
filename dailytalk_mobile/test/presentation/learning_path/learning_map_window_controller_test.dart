import 'dart:async';

import 'package:dailytalk_mobile/data/repositories/learning_progress_read_repository.dart';
import 'package:dailytalk_mobile/domain/learning/domain_ids.dart';
import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/learning_models.dart';
import 'package:dailytalk_mobile/domain/learning/progression_engine.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_read_service.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_view.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_window_controller.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_window_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('controller troca segmentos e preserva scroll por janela', () async {
    final fixture = await _fixture(stageCount: 6, segmentSize: 2);

    final controller = fixture.controller;
    addTearDown(controller.dispose);

    expect(await controller.loadInitial(), isTrue);

    expect(_elementIds(controller), <String>['element-0', 'element-1']);

    controller.rememberCurrentScrollOffset(125);

    expect(await controller.loadNext(), isTrue);

    expect(_elementIds(controller), <String>['element-2', 'element-3']);

    expect(controller.currentScrollOffset, 0);

    controller.rememberCurrentScrollOffset(47);

    expect(await controller.loadPrevious(), isTrue);

    expect(_elementIds(controller), <String>['element-0', 'element-1']);

    expect(controller.currentScrollOffset, 125);

    expect(await controller.loadNext(), isTrue);

    expect(controller.currentScrollOffset, 47);

    expect(fixture.catalogLoadCount, 1);
  });

  test('falha ao trocar segmento preserva ultimo modelo valido', () async {
    final fixture = await _fixture(
      stageCount: 6,
      segmentSize: 2,
      failWhenProjectionContains: 'element-2',
    );

    final controller = fixture.controller;
    addTearDown(controller.dispose);

    expect(await controller.loadInitial(), isTrue);

    final before = controller.composition;

    expect(before, isNotNull);

    final changed = await controller.loadNext();

    expect(changed, isFalse);
    expect(controller.hasError, isTrue);
    expect(controller.isLoading, isFalse);

    expect(identical(controller.composition, before), isTrue);

    expect(controller.composition?.window.startStageIndex, 0);
  });

  test('reloadCurrent rele apenas o segmento atual', () async {
    final fixture = await _fixture(stageCount: 8, segmentSize: 2);

    final controller = fixture.controller;
    addTearDown(controller.dispose);

    await controller.loadInitial();
    await controller.loadNext();

    final requestsBefore = fixture.projectionRequests.length;

    expect(await controller.reloadCurrent(), isTrue);

    expect(fixture.projectionRequests.length, requestsBefore + 1);

    expect(fixture.projectionRequests.last, <String>['element-2', 'element-3']);

    expect(controller.composition?.window.startStageIndex, 2);

    expect(fixture.catalogLoadCount, 1);
  });

  test('segundo load concorrente e recusado sem corromper estado', () async {
    final path = _buildPath(4);

    final gate = Completer<void>();

    var projectionCalls = 0;

    final coordinator = LearningMapWindowCoordinator(
      loadActiveContent: (_) async => LearningMapActiveContentSnapshot(
        path: path,
        packageVersion: 9,
        recoveredFromFallback: false,
      ),
      loadWindowProjection:
          ({
            required String accountId,
            required String learningPathId,
            required Iterable<String> pathElementIds,
          }) async {
            projectionCalls++;

            await gate.future;

            return pathElementIds
                .map((id) => _projection(id, stageCount: 4))
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
            return <LearningProgressProjectionEntry>[
              _projection('element-3', stageCount: 4, recommendationRank: 0),
            ];
          },
      loadGlobalCounts:
          ({required String accountId, required String learningPathId}) async {
            return _counts(4);
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

    final controller = LearningMapWindowController(session: session);

    addTearDown(controller.dispose);

    final first = controller.loadInitial();

    await Future<void>.delayed(Duration.zero);

    expect(controller.isLoading, isTrue);

    final concurrent = await controller.loadInitial();

    expect(concurrent, isFalse);

    gate.complete();

    expect(await first, isTrue);
    expect(projectionCalls, 1);

    expect(_elementIds(controller), <String>['element-0', 'element-1']);
  });

  testWidgets(
    'viewport apresenta apenas o segmento corrente no LearningMapView lazy',
    (tester) async {
      final fixture = await _fixture(stageCount: 6, segmentSize: 2);

      final controller = fixture.controller;
      final scrollController = ScrollController();

      addTearDown(controller.dispose);
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 700,
              child: LearningMapWindowViewport(
                controller: controller,
                scrollController: scrollController,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(LearningMapView), findsOneWidget);

      var view = tester.widget<LearningMapView>(find.byType(LearningMapView));

      expect(identical(view.scrollController, scrollController), isTrue);

      expect(
        view.model.elements.map((element) => element.pathElementId).toList(),
        <String>['element-0', 'element-1'],
      );

      expect(find.byType(SliverList), findsWidgets);

      expect(await controller.loadNext(), isTrue);

      await tester.pumpAndSettle();

      view = tester.widget<LearningMapView>(find.byType(LearningMapView));

      expect(
        view.model.elements.map((element) => element.pathElementId).toList(),
        <String>['element-2', 'element-3'],
      );

      expect(identical(view.scrollController, scrollController), isTrue);

      expect(fixture.catalogLoadCount, 1);
    },
  );
}

List<String> _elementIds(LearningMapWindowController controller) {
  return controller.composition!.model.elements
      .map((element) => element.pathElementId)
      .toList(growable: false);
}

Future<_Fixture> _fixture({
  required int stageCount,
  required int segmentSize,
  String? failWhenProjectionContains,
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

          if (failWhenProjectionContains != null &&
              ids.contains(failWhenProjectionContains)) {
            throw StateError('synthetic selective-read failure');
          }

          return ids
              .map((id) => _projection(id, stageCount: stageCount))
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
          return <LearningProgressProjectionEntry>[
            _projection(
              'element-${stageCount - 1}',
              stageCount: stageCount,
              recommendationRank: 0,
            ),
          ];
        },
    loadGlobalCounts:
        ({required String accountId, required String learningPathId}) async {
          return _counts(stageCount);
        },
    policy: LearningMapStageWindowPolicy(
      initialStageCount: segmentSize,
      segmentStageCount: segmentSize,
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
    readCatalogLoadCount: () => catalogLoadCount,
  );
}

final class _Fixture {
  const _Fixture({
    required this.controller,
    required this.projectionRequests,
    required int Function() readCatalogLoadCount,
  }) : _readCatalogLoadCount = readCatalogLoadCount;

  final LearningMapWindowController controller;

  final List<List<String>> projectionRequests;

  final int Function() _readCatalogLoadCount;

  int get catalogLoadCount => _readCatalogLoadCount();
}

LearningPath _buildPath(int stageCount) {
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
      'en': 'Segmented path',
      'pt-PT': 'Percurso segmentado',
    }),
    journeys: <Journey>[
      Journey(
        id: JourneyId('journey-1'),
        title: LocalizedText(const <String, String>{
          'en': 'Journey',
          'pt-PT': 'Jornada',
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
  required int stageCount,
  int? recommendationRank,
}) {
  final suffix = pathElementId.substring('element-'.length);

  final isPrimaryRecommendation = suffix == '${stageCount - 1}';

  return LearningProgressProjectionEntry(
    pathElementId: pathElementId,
    activityId: 'activity-$suffix',
    state: LearningActivityState.available,
    reason: ProgressionReason.ready,
    recommendationRank:
        recommendationRank ?? (isPrimaryRecommendation ? 0 : null),
    packageVersion: 9,
    updatedAt: DateTime.utc(2026, 9, 14, 15),
  );
}

LearningProgressProjectionCounts _counts(int stageCount) {
  return LearningProgressProjectionCounts(
    projectionRowCount: stageCount,
    totalActivityCount: stageCount,
    completedActivityCount: 0,
    minPackageVersion: 9,
    maxPackageVersion: 9,
  );
}
