import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/progression_engine.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_view.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('360px mobile keeps the primary action clear without overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    expect(find.byKey(const Key('learning-map-header')), findsOneWidget);
    expect(find.byKey(const Key('learning-map-progress-count')), findsNothing);
    expect(find.byKey(const Key('learning-map-continue-next')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide layout centers learning content instead of stretching it', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    final heroSize = tester.getSize(
      find.byKey(const Key('learning-map-header')),
    );
    final stageSize = tester.getSize(
      find.byKey(const Key('learning-map-stage-stage-1')),
    );

    expect(heroSize.width, lessThanOrEqualTo(920));
    expect(stageSize.width, lessThanOrEqualTo(920));
    expect(
      find.byKey(const Key('learning-map-progress-count')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('integrated challenge has a stronger playful landmark', (
    tester,
  ) async {
    final challenge = _activity(
      id: 'challenge',
      state: LearningActivityState.locked,
      activityType: LearningActivityType.integratedChallenge,
    );

    await _pumpMap(tester, _model(<LearningMapElementViewModel>[challenge]));

    expect(find.text('Desafio'), findsOneWidget);
    expect(
      find.byKey(const Key('learning-map-challenge-spark-challenge')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('learning-map-type-icon-integratedChallenge-challenge'),
      ),
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
        body: LearningMapView(model: model, onActivityTap: onActivityTap),
      ),
    ),
  );
}

LearningMapViewModel _model(List<LearningMapElementViewModel> elements) {
  return LearningMapViewModel(
    learningPathId: 'responsive-polish-path',
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
  LearningActivityType activityType = LearningActivityType.vocabulary,
  int? recommendationRank,
}) {
  return LearningMapElementViewModel(
    pathElementId: id,
    elementType: PathElementType.activity,
    activityId: 'activity-$id',
    revisionId: 'revision-$id',
    activityType: activityType,
    title: activityType == LearningActivityType.integratedChallenge
        ? 'Miss\u00e3o: primeiro dia completo'
        : 'Cumprimentos essenciais',
    instructions: activityType == LearningActivityType.integratedChallenge
        ? 'Resolve uma sequ\u00eancia integrada da tua aventura.'
        : 'Associa as express\u00f5es essenciais ao significado correto.',
    competencyIds: const <String>{'communication'},
    state: state,
    reason: switch (state) {
      LearningActivityState.locked => ProgressionReason.prerequisitesNotMet,
      LearningActivityState.available => ProgressionReason.ready,
      LearningActivityState.inProgress => ProgressionReason.attemptStarted,
      LearningActivityState.completed => ProgressionReason.completed,
    },
    syncState: ProgressSyncState.clean,
    practicePreference: PracticePreference.balanced,
    recommendationRank: recommendationRank,
  );
}
