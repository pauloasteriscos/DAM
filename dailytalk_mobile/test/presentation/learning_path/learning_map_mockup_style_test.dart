import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/progression_engine.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_view.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_view_model.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mockup hero exposes context progress sync and next mission', (
    tester,
  ) async {
    final model = _model(
      elements: <LearningMapElementViewModel>[
        _activity(
          id: 'next',
          type: LearningActivityType.vocabulary,
          state: LearningActivityState.available,
          recommendationRank: 0,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 430,
            height: 900,
            child: LearningMapView(model: model),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('learning-map-header')), findsOneWidget);
    expect(find.byKey(const Key('learning-map-progress-card')), findsOneWidget);
    expect(find.byKey(const Key('learning-map-hero-sync')), findsOneWidget);
    expect(find.byKey(const Key('learning-map-next-mission')), findsOneWidget);
    expect(find.text('Jornada de Acolhimento \u2022 Chegada'), findsOneWidget);
    expect(find.text('Tudo guardado'), findsOneWidget);
  });

  testWidgets('primary mission exposes a mockup-style continue CTA', (
    tester,
  ) async {
    final mission = _activity(
      id: 'recommended',
      type: LearningActivityType.dialogue,
      state: LearningActivityState.available,
      recommendationRank: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: LearningMapVisualTokens.background,
          body: Center(
            child: SizedBox(
              width: 380,
              child: LearningMapActivityNode(element: mission, onTap: () {}),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('learning-map-continue-recommended')),
      findsOneWidget,
    );
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('A seguir'), findsOneWidget);
  });

  test('mockup foundation uses a light learning canvas', () {
    expect(LearningMapVisualTokens.background, const Color(0xFFF3F8FC));
    expect(LearningMapVisualTokens.surface, const Color(0xFFFFFFFF));
    expect(LearningMapVisualTokens.heroStart, const Color(0xFF073965));
  });
}

LearningMapViewModel _model({
  required List<LearningMapElementViewModel> elements,
}) {
  return LearningMapViewModel(
    learningPathId: 'student.fr-fr.phase1',
    title: 'Primeiros dias em Fran\u00e7a',
    locale: 'pt-PT',
    packageVersion: 3,
    recoveredFromFallback: false,
    completedActivityCount: 0,
    totalActivityCount: elements.where((element) => element.isActivity).length,
    journeys: <LearningMapJourneyViewModel>[
      LearningMapJourneyViewModel(
        id: 'journey-1',
        title: 'Jornada de Acolhimento',
        stages: <LearningMapStageViewModel>[
          LearningMapStageViewModel(
            id: 'stage-1',
            title: 'Chegada',
            elements: elements,
          ),
        ],
      ),
    ],
  );
}

LearningMapElementViewModel _activity({
  required String id,
  required LearningActivityType type,
  required LearningActivityState state,
  int? recommendationRank,
}) {
  return LearningMapElementViewModel(
    pathElementId: id,
    elementType: PathElementType.activity,
    activityId: 'activity-$id',
    revisionId: 'revision-$id',
    activityType: type,
    title: 'Miss\u00e3o de teste',
    instructions: 'Pratica uma situa\u00e7\u00e3o do quotidiano.',
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
