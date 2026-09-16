import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/progression_engine.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_view.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sync appears once globally with child-friendly language', (
    tester,
  ) async {
    final next = _activity(
      id: 'next',
      state: LearningActivityState.available,
      syncState: ProgressSyncState.pending,
      recommendationRank: 0,
    );

    await _pumpMap(tester, _model(<LearningMapElementViewModel>[next]));

    expect(find.byKey(const Key('learning-map-hero-sync')), findsOneWidget);
    expect(find.text('Por guardar'), findsOneWidget);
    expect(find.byKey(const Key('learning-map-sync-next')), findsNothing);
    expect(find.text('Por sincronizar'), findsNothing);
  });

  testWidgets('recommended mission keeps one obvious action', (tester) async {
    final next = _activity(
      id: 'next',
      state: LearningActivityState.available,
      recommendationRank: 0,
    );

    await _pumpMap(
      tester,
      _model(<LearningMapElementViewModel>[next]),
      onActivityTap: (_) {},
    );

    expect(find.text('Continuar'), findsOneWidget);
    expect(find.byKey(const Key('learning-map-continue-next')), findsOneWidget);
  });

  testWidgets('locked path explains the goal without exposing rule syntax', (
    tester,
  ) async {
    final sourceA = _activity(
      id: 'source-a',
      state: LearningActivityState.completed,
    );
    final sourceB = _activity(
      id: 'source-b',
      state: LearningActivityState.available,
    );
    final locked = _activity(
      id: 'locked',
      state: LearningActivityState.locked,
      prerequisites: LearningMapPrerequisiteViewModel.group(
        operator: PrerequisiteOperator.any,
        rules: <LearningMapPrerequisiteViewModel>[
          LearningMapPrerequisiteViewModel.activityCompleted(
            activityId: 'activity-source-a',
            sourcePathElementId: 'source-a',
          ),
          LearningMapPrerequisiteViewModel.activityCompleted(
            activityId: 'activity-source-b',
            sourcePathElementId: 'source-b',
          ),
        ],
      ),
    );

    await _pumpMap(
      tester,
      _model(<LearningMapElementViewModel>[sourceA, sourceB, locked]),
    );

    expect(
      find.text('Completa 1 de 2 miss\u00f5es para desbloquear'),
      findsOneWidget,
    );
    expect(find.text('QUALQUER UMA'), findsNothing);
    expect(find.text('TODAS'), findsNothing);
  });

  testWidgets('route marker gives state a visual landmark', (tester) async {
    final completed = _activity(
      id: 'completed',
      state: LearningActivityState.completed,
    );
    final locked = _activity(id: 'locked', state: LearningActivityState.locked);

    await _pumpMap(
      tester,
      _model(<LearningMapElementViewModel>[completed, locked]),
    );

    expect(
      find.byKey(const Key('learning-map-route-marker-completed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('learning-map-route-marker-locked')),
      findsOneWidget,
    );
  });
}

Future<void> _pumpMap(
  WidgetTester tester,
  LearningMapViewModel model, {
  LearningMapActivityTap? onActivityTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 420,
          height: 1000,
          child: LearningMapView(model: model, onActivityTap: onActivityTap),
        ),
      ),
    ),
  );
}

LearningMapViewModel _model(List<LearningMapElementViewModel> elements) {
  return LearningMapViewModel(
    learningPathId: 'child-friendly-path',
    title: 'Primeiros dias em Fran\u00e7a',
    locale: 'pt-PT',
    packageVersion: 3,
    recoveredFromFallback: false,
    completedActivityCount: elements
        .where(
          (element) =>
              element.isActivity &&
              element.state == LearningActivityState.completed,
        )
        .length,
    totalActivityCount: elements.where((element) => element.isActivity).length,
    journeys: <LearningMapJourneyViewModel>[
      LearningMapJourneyViewModel(
        id: 'journey-1',
        title: 'Primeiros dias em Fran\u00e7a',
        stages: <LearningMapStageViewModel>[
          LearningMapStageViewModel(
            id: 'stage-1',
            title: 'Chegar e apresentar-se',
            elements: elements,
          ),
        ],
      ),
    ],
  );
}

LearningMapElementViewModel _activity({
  required String id,
  required LearningActivityState state,
  ProgressSyncState syncState = ProgressSyncState.clean,
  int? recommendationRank,
  LearningMapPrerequisiteViewModel? prerequisites,
}) {
  return LearningMapElementViewModel(
    pathElementId: id,
    elementType: PathElementType.activity,
    activityId: 'activity-$id',
    revisionId: 'revision-$id',
    activityType: LearningActivityType.vocabulary,
    title: 'Miss\u00e3o $id',
    instructions: 'Avan\u00e7a um passo na tua aventura.',
    competencyIds: const <String>{'communication'},
    state: state,
    reason: switch (state) {
      LearningActivityState.locked => ProgressionReason.prerequisitesNotMet,
      LearningActivityState.available => ProgressionReason.ready,
      LearningActivityState.inProgress => ProgressionReason.attemptStarted,
      LearningActivityState.completed => ProgressionReason.completed,
    },
    syncState: syncState,
    practicePreference: PracticePreference.balanced,
    recommendationRank: recommendationRank,
    prerequisites: prerequisites,
  );
}
