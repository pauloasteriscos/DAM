import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/progression_engine.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_view.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_view_model.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('composes Journey Stage and Mission in authored order', (
    tester,
  ) async {
    final completed = _activity(
      id: 'mission-1',
      title: 'Primeiro contacto',
      state: LearningActivityState.completed,
    );

    final available = _activity(
      id: 'mission-2',
      title: 'Conhecer a fam\u00edlia',
      state: LearningActivityState.available,
      recommendationRank: 0,
    );

    final model = _model(
      stageElements: <LearningMapElementViewModel>[completed, available],
      completedActivityCount: 1,
    );

    await _pumpMap(tester, model);

    expect(find.byKey(const Key('learning-map-scroll-view')), findsOneWidget);
    expect(
      find.byKey(const Key('learning-map-journey-journey-1')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('learning-map-stage-stage-1')), findsOneWidget);
    expect(find.text('JORNADA 1'), findsOneWidget);
    expect(find.text('ETAPA 1'), findsOneWidget);
    expect(find.text('Jornada de Acolhimento'), findsWidgets);
    expect(find.text('Chegada'), findsWidgets);

    final rendered = tester
        .widgetList<LearningMapActivityNode>(
          find.byType(LearningMapActivityNode),
        )
        .map((node) => node.element.pathElementId)
        .toList(growable: false);

    expect(rendered, <String>['mission-1', 'mission-2']);
  });

  testWidgets('stage progress is derived only from Stage ViewModel', (
    tester,
  ) async {
    final model = _model(
      stageElements: <LearningMapElementViewModel>[
        _activity(id: 'done', state: LearningActivityState.completed),
        _activity(id: 'open', state: LearningActivityState.available),
      ],
      completedActivityCount: 1,
    );

    await _pumpMap(tester, model);

    expect(
      find.byKey(const Key('learning-map-stage-count-stage-1')),
      findsOneWidget,
    );
    expect(find.text('1 / 2'), findsWidgets);

    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('learning-map-stage-progress-stage-1')),
    );

    expect(progress.value, 0.5);
  });

  testWidgets('available mission forwards the exact ViewModel element', (
    tester,
  ) async {
    LearningMapElementViewModel? tapped;

    final mission = _activity(
      id: 'open-mission',
      state: LearningActivityState.available,
    );

    await _pumpMap(
      tester,
      _model(stageElements: <LearningMapElementViewModel>[mission]),
      onActivityTap: (element) => tapped = element,
    );

    await tester.tap(find.byKey(const Key('learning-map-node-open-mission')));
    await tester.pump();

    expect(tapped, same(mission));
  });

  testWidgets('locked mission remains non-interactive through composition', (
    tester,
  ) async {
    var taps = 0;

    final mission = _activity(
      id: 'locked-mission',
      state: LearningActivityState.locked,
    );

    await _pumpMap(
      tester,
      _model(stageElements: <LearningMapElementViewModel>[mission]),
      onActivityTap: (_) => taps += 1,
    );

    await tester.tap(find.byKey(const Key('learning-map-node-locked-mission')));
    await tester.pump();

    expect(taps, 0);
  });

  testWidgets(
    'structural element keeps authored position without becoming activity',
    (tester) async {
      final before = _activity(
        id: 'before',
        state: LearningActivityState.completed,
      );

      final checkpoint = _structural(
        id: 'checkpoint-1',
        type: PathElementType.checkpoint,
      );

      final after = _activity(
        id: 'after',
        state: LearningActivityState.available,
      );

      await _pumpMap(
        tester,
        _model(
          stageElements: <LearningMapElementViewModel>[
            before,
            checkpoint,
            after,
          ],
          completedActivityCount: 1,
        ),
      );

      expect(
        find.byKey(const Key('learning-map-route-before')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('learning-map-route-checkpoint-1')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('learning-map-route-after')), findsOneWidget);
      expect(
        find.byKey(const Key('learning-map-structural-checkpoint-1')),
        findsOneWidget,
      );
      expect(find.text('Checkpoint'), findsOneWidget);

      expect(find.byType(LearningMapActivityNode), findsNWidgets(2));

      final beforeY = tester
          .getTopLeft(find.byKey(const Key('learning-map-route-before')))
          .dy;

      final checkpointY = tester
          .getTopLeft(find.byKey(const Key('learning-map-route-checkpoint-1')))
          .dy;

      final afterY = tester
          .getTopLeft(find.byKey(const Key('learning-map-route-after')))
          .dy;

      expect(beforeY, lessThan(checkpointY));
      expect(checkpointY, lessThan(afterY));
    },
  );

  testWidgets('checkpoint scene and reward have distinct visual identities', (
    tester,
  ) async {
    await _pumpMap(
      tester,
      _model(
        stageElements: <LearningMapElementViewModel>[
          _structural(
            id: 'checkpoint-special',
            type: PathElementType.checkpoint,
          ),
          _structural(id: 'scene-special', type: PathElementType.scene),
          _structural(id: 'reward-special', type: PathElementType.reward),
        ],
      ),
    );

    expect(
      find.byKey(
        const Key('learning-map-special-checkpoint-checkpoint-special'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('learning-map-special-scene-scene-special')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('learning-map-special-reward-reward-special')),
      findsOneWidget,
    );

    expect(find.text('Checkpoint'), findsOneWidget);
    expect(find.text('Cena'), findsOneWidget);
    expect(find.text('Recompensa'), findsOneWidget);
    expect(find.byType(LearningMapActivityNode), findsNothing);
  });

  testWidgets(
    'structural state is rendered without converting it to activity',
    (tester) async {
      await _pumpMap(
        tester,
        _model(
          stageElements: <LearningMapElementViewModel>[
            _structural(
              id: 'reward-completed',
              type: PathElementType.reward,
              state: LearningActivityState.completed,
            ),
          ],
        ),
      );

      expect(
        find.byKey(const Key('learning-map-structural-state-reward-completed')),
        findsOneWidget,
      );
      expect(find.text('Conclu\u00eddo'), findsOneWidget);
      expect(find.byType(LearningMapActivityNode), findsNothing);
    },
  );
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
          height: 900,
          child: LearningMapView(model: model, onActivityTap: onActivityTap),
        ),
      ),
    ),
  );
}

LearningMapViewModel _model({
  required List<LearningMapElementViewModel> stageElements,
  int completedActivityCount = 0,
}) {
  final totalActivityCount = stageElements
      .where((element) => element.isActivity)
      .length;

  return LearningMapViewModel(
    learningPathId: 'student.fr-fr.phase1',
    title: 'Jornada Erasmus+',
    locale: 'pt-PT',
    packageVersion: 3,
    recoveredFromFallback: false,
    completedActivityCount: completedActivityCount,
    totalActivityCount: totalActivityCount,
    journeys: <LearningMapJourneyViewModel>[
      LearningMapJourneyViewModel(
        id: 'journey-1',
        title: 'Jornada de Acolhimento',
        stages: <LearningMapStageViewModel>[
          LearningMapStageViewModel(
            id: 'stage-1',
            title: 'Chegada',
            elements: stageElements,
          ),
        ],
      ),
    ],
  );
}

LearningMapElementViewModel _activity({
  required String id,
  required LearningActivityState state,
  String title = 'Miss\u00e3o de teste',
  int? recommendationRank,
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
    syncState: ProgressSyncState.clean,
    practicePreference: PracticePreference.dialogue,
    recommendationRank: recommendationRank,
  );
}

LearningMapElementViewModel _structural({
  required String id,
  required PathElementType type,
  LearningActivityState state = LearningActivityState.available,
}) {
  return LearningMapElementViewModel(
    pathElementId: id,
    elementType: type,
    title: null,
    competencyIds: const <String>{},
    state: state,
    reason: switch (state) {
      LearningActivityState.locked => ProgressionReason.prerequisitesNotMet,
      LearningActivityState.available => ProgressionReason.ready,
      LearningActivityState.inProgress => ProgressionReason.attemptStarted,
      LearningActivityState.completed => ProgressionReason.completed,
    },
    syncState: ProgressSyncState.clean,
    practicePreference: PracticePreference.balanced,
  );
}
