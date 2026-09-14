import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/progression_engine.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_view.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dependencia direta cria uma aresta visual autoral', (
    tester,
  ) async {
    final source = _activity(
      id: 'source',
      state: LearningActivityState.completed,
    );

    final target = _activity(
      id: 'target',
      state: LearningActivityState.available,
      prerequisites: LearningMapPrerequisiteViewModel.activityCompleted(
        activityId: 'activity-source',
        sourcePathElementId: 'source',
      ),
    );

    await _pumpMap(
      tester,
      _singleStageModel(<LearningMapElementViewModel>[source, target]),
    );

    expect(
      find.byKey(const Key('learning-map-topology-target')),
      findsOneWidget,
    );

    expect(
      find.byKey(const Key('learning-map-edge-source-target-root')),
      findsOneWidget,
    );

    expect(find.text('Miss\u00e3o necess\u00e1ria'), findsOneWidget);
  });

  testWidgets('ANY bifurca e ALL converge preservando grupo aninhado', (
    tester,
  ) async {
    final sourceA = _activity(
      id: 'source-a',
      state: LearningActivityState.completed,
    );

    final sourceB = _activity(
      id: 'source-b',
      state: LearningActivityState.completed,
    );

    final target = _activity(
      id: 'target',
      state: LearningActivityState.available,
      prerequisites: LearningMapPrerequisiteViewModel.group(
        operator: PrerequisiteOperator.all,
        rules: <LearningMapPrerequisiteViewModel>[
          LearningMapPrerequisiteViewModel.group(
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
          LearningMapPrerequisiteViewModel.competencyAchieved(
            competencyId: 'competency-pronunciation',
          ),
        ],
      ),
    );

    await _pumpMap(
      tester,
      _singleStageModel(<LearningMapElementViewModel>[
        sourceA,
        sourceB,
        target,
      ]),
    );

    expect(
      find.byKey(const Key('learning-map-group-all-target-root')),
      findsOneWidget,
    );

    expect(
      find.byKey(const Key('learning-map-group-any-target-root-0')),
      findsOneWidget,
    );

    expect(
      find.byKey(const Key('learning-map-edge-source-a-target-root-0-0')),
      findsOneWidget,
    );

    expect(
      find.byKey(const Key('learning-map-edge-source-b-target-root-0-1')),
      findsOneWidget,
    );

    expect(
      find.byKey(const Key('learning-map-competency-target-root-1')),
      findsOneWidget,
    );

    expect(find.text('TODAS'), findsOneWidget);
    expect(find.text('QUALQUER UMA'), findsOneWidget);

    expect(find.text('Compet\u00eancia necess\u00e1ria'), findsOneWidget);

    // Competency is semantic data, never a PathElement edge.
    expect(
      find.byKey(
        const Key(
          'learning-map-edge-'
          'competency-pronunciation-target-root-1',
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('atividade sem sourcePathElementId nao inventa aresta', (
    tester,
  ) async {
    final target = _activity(
      id: 'target',
      state: LearningActivityState.locked,
      prerequisites: LearningMapPrerequisiteViewModel.activityCompleted(
        activityId: 'activity-ambiguous',
      ),
    );

    await _pumpMap(
      tester,
      _singleStageModel(<LearningMapElementViewModel>[target]),
    );

    expect(
      find.byKey(const Key('learning-map-unresolved-activity-target-root')),
      findsOneWidget,
    );

    expect(find.text('Atividade necess\u00e1ria'), findsOneWidget);

    expect(
      find.byKey(
        const Key(
          'learning-map-edge-'
          'activity-ambiguous-target-root',
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('competencia isolada permanece requisito sem aresta', (
    tester,
  ) async {
    final target = _activity(
      id: 'target',
      state: LearningActivityState.locked,
      prerequisites: LearningMapPrerequisiteViewModel.competencyAchieved(
        competencyId: 'competency-cultural',
      ),
    );

    await _pumpMap(
      tester,
      _singleStageModel(<LearningMapElementViewModel>[target]),
    );

    expect(
      find.byKey(const Key('learning-map-competency-target-root')),
      findsOneWidget,
    );

    expect(find.text('Compet\u00eancia necess\u00e1ria'), findsOneWidget);

    expect(
      find.byKey(
        const Key(
          'learning-map-edge-'
          'competency-cultural-target-root',
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('elemento estrutural tambem pode receber topologia autoral', (
    tester,
  ) async {
    final source = _activity(
      id: 'source',
      state: LearningActivityState.completed,
    );

    final checkpoint = _structural(
      id: 'checkpoint-target',
      type: PathElementType.checkpoint,
      state: LearningActivityState.available,
      prerequisites: LearningMapPrerequisiteViewModel.activityCompleted(
        activityId: 'activity-source',
        sourcePathElementId: 'source',
      ),
    );

    await _pumpMap(
      tester,
      _singleStageModel(<LearningMapElementViewModel>[source, checkpoint]),
    );

    expect(
      find.byKey(
        const Key(
          'learning-map-special-'
          'checkpoint-checkpoint-target',
        ),
      ),
      findsOneWidget,
    );

    expect(
      find.byKey(
        const Key(
          'learning-map-edge-'
          'source-checkpoint-target-root',
        ),
      ),
      findsOneWidget,
    );
  });
}

Future<void> _pumpMap(WidgetTester tester, LearningMapViewModel model) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 420,
          height: 1000,
          child: LearningMapView(model: model),
        ),
      ),
    ),
  );
}

LearningMapViewModel _singleStageModel(
  List<LearningMapElementViewModel> elements,
) {
  final activityCount = elements.where((element) => element.isActivity).length;

  final completedActivityCount = elements
      .where(
        (element) =>
            element.isActivity &&
            element.state == LearningActivityState.completed,
      )
      .length;

  return LearningMapViewModel(
    learningPathId: 'student.fr-fr.phase1',
    title: 'Jornada Erasmus+',
    locale: 'pt-PT',
    packageVersion: 3,
    recoveredFromFallback: false,
    completedActivityCount: completedActivityCount,
    totalActivityCount: activityCount,
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
  required LearningActivityState state,
  LearningMapPrerequisiteViewModel? prerequisites,
}) {
  return LearningMapElementViewModel(
    pathElementId: id,
    elementType: PathElementType.activity,
    activityId: 'activity-$id',
    revisionId: 'revision-$id',
    activityType: LearningActivityType.dialogue,
    title: 'Miss\u00e3o de teste',
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
    prerequisites: prerequisites,
  );
}

LearningMapElementViewModel _structural({
  required String id,
  required PathElementType type,
  required LearningActivityState state,
  LearningMapPrerequisiteViewModel? prerequisites,
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
    prerequisites: prerequisites,
  );
}
