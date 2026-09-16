import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/progression_engine.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_view_model.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('header uses LearningMapViewModel context and progress', (
    tester,
  ) async {
    final next = _activity(
      id: 'mission-next',
      state: LearningActivityState.available,
      recommendationRank: 0,
      title: 'Cumprimentar a fam\u00edlia anfitri\u00e3',
    );

    final model = LearningMapViewModel(
      learningPathId: 'student.fr-fr.phase1',
      title: 'Jornada Erasmus+',
      locale: 'pt-PT',
      packageVersion: 3,
      recoveredFromFallback: false,
      completedActivityCount: 1,
      totalActivityCount: 4,
      journeys: <LearningMapJourneyViewModel>[
        LearningMapJourneyViewModel(
          id: 'journey-1',
          title: 'Jornada de Acolhimento',
          stages: <LearningMapStageViewModel>[
            LearningMapStageViewModel(
              id: 'stage-1',
              title: 'Chegada',
              elements: <LearningMapElementViewModel>[next],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: LearningMapVisualTokens.background,
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: LearningMapContextHeader(model: model),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('learning-map-header')), findsOneWidget);
    expect(find.text('Jornada Erasmus+'), findsOneWidget);
    expect(find.text('Jornada de Acolhimento \u2022 Chegada'), findsOneWidget);
    expect(find.text('1 de 4 miss\u00f5es conclu\u00eddas'), findsOneWidget);
    expect(find.text('Pr\u00f3xima miss\u00e3o'), findsOneWidget);
    expect(find.text('Tudo guardado'), findsOneWidget);
    expect(
      find.text('Cumprimentar a fam\u00edlia anfitri\u00e3'),
      findsOneWidget,
    );
  });

  const stateLabels = <LearningActivityState, String>{
    LearningActivityState.locked: 'Bloqueada',
    LearningActivityState.available: 'Dispon\u00edvel',
    LearningActivityState.inProgress: 'Em progresso',
    LearningActivityState.completed: 'Conclu\u00edda',
  };

  for (final entry in stateLabels.entries) {
    testWidgets('renders visual state ${entry.key.name}', (tester) async {
      final element = _activity(id: 'state-node', state: entry.key);

      await _pumpNode(tester, element);

      expect(
        find.byKey(const Key('learning-map-state-state-node')),
        findsOneWidget,
      );
      expect(find.text(entry.value), findsOneWidget);
    });
  }

  testWidgets(
    'pedagogical state remains on the mission while sync stays global',
    (tester) async {
      final element = _activity(
        id: 'completed-pending',
        state: LearningActivityState.completed,
        syncState: ProgressSyncState.pending,
      );

      await _pumpNode(tester, element);

      expect(find.text('Conclu\u00edda'), findsOneWidget);
      expect(
        find.byKey(const Key('learning-map-state-completed-pending')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('learning-map-sync-completed-pending')),
        findsNothing,
      );
      expect(find.text('Por sincronizar'), findsNothing);
    },
  );

  testWidgets('primary recommendation shows A seguir badge', (tester) async {
    final element = _activity(
      id: 'recommended',
      state: LearningActivityState.available,
      recommendationRank: 0,
    );

    await _pumpNode(tester, element);

    expect(
      find.byKey(const Key('learning-map-primary-recommendation')),
      findsOneWidget,
    );
    expect(find.text('A seguir'), findsOneWidget);
  });

  testWidgets('locked node cannot trigger navigation callback', (tester) async {
    var taps = 0;

    final element = _activity(
      id: 'locked-node',
      state: LearningActivityState.locked,
    );

    await _pumpNode(tester, element, onTap: () => taps += 1);

    await tester.tap(find.byKey(const Key('learning-map-node-locked-node')));
    await tester.pump();

    expect(taps, 0);
  });

  testWidgets('available node can trigger navigation callback', (tester) async {
    var taps = 0;

    final element = _activity(
      id: 'available-node',
      state: LearningActivityState.available,
    );

    await _pumpNode(tester, element, onTap: () => taps += 1);

    await tester.tap(find.byKey(const Key('learning-map-node-available-node')));
    await tester.pump();

    expect(taps, 1);
  });
}

Future<void> _pumpNode(
  WidgetTester tester,
  LearningMapElementViewModel element, {
  VoidCallback? onTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: LearningMapVisualTokens.background,
        body: Center(
          child: SizedBox(
            width: 360,
            child: LearningMapActivityNode(element: element, onTap: onTap),
          ),
        ),
      ),
    ),
  );
}

LearningMapElementViewModel _activity({
  required String id,
  required LearningActivityState state,
  ProgressSyncState syncState = ProgressSyncState.clean,
  int? recommendationRank,
  String title = 'Miss\u00e3o de teste',
}) {
  return LearningMapElementViewModel(
    pathElementId: id,
    elementType: PathElementType.activity,
    activityId: 'activity-$id',
    revisionId: 'revision-$id',
    activityType: LearningActivityType.dialogue,
    title: title,
    instructions: 'Pratica uma conversa do quotidiano.',
    competencyIds: const <String>{'communication'},
    state: state,
    reason: switch (state) {
      LearningActivityState.locked => ProgressionReason.prerequisitesNotMet,
      LearningActivityState.available => ProgressionReason.ready,
      LearningActivityState.inProgress => ProgressionReason.attemptStarted,
      LearningActivityState.completed => ProgressionReason.completed,
    },
    syncState: syncState,
    practicePreference: PracticePreference.dialogue,
    recommendationRank: recommendationRank,
  );
}
