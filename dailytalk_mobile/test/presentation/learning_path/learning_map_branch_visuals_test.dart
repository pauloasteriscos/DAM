import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/progression_engine.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_view.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'dependencia direta vira uma instrucao simples para desbloquear',
    (tester) async {
      final source = _activity(
        id: 'source',
        state: LearningActivityState.completed,
      );

      final target = _activity(
        id: 'target',
        state: LearningActivityState.locked,
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
        find.byKey(const Key('learning-map-prerequisite-summary-target')),
        findsOneWidget,
      );
      expect(
        find.text('Completa a miss\u00e3o anterior para desbloquear'),
        findsOneWidget,
      );
      expect(find.text('Miss\u00e3o necess\u00e1ria'), findsNothing);
    },
  );

  testWidgets('ANY de duas missoes vira escolha simples 1 de 2', (
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
    final target = _activity(
      id: 'target',
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
      _singleStageModel(<LearningMapElementViewModel>[
        sourceA,
        sourceB,
        target,
      ]),
    );

    expect(
      find.text('Completa 1 de 2 miss\u00f5es para desbloquear'),
      findsOneWidget,
    );
    expect(find.text('QUALQUER UMA'), findsNothing);
  });

  testWidgets(
    'ALL aninhado vira uma mensagem unica sem expor a arvore tecnica',
    (tester) async {
      final sourceA = _activity(
        id: 'source-a',
        state: LearningActivityState.completed,
      );
      final sourceB = _activity(
        id: 'source-b',
        state: LearningActivityState.available,
      );
      final target = _activity(
        id: 'target',
        state: LearningActivityState.locked,
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
        find.text('Completa todas as condi\u00e7\u00f5es para desbloquear'),
        findsOneWidget,
      );
      expect(find.text('TODAS'), findsNothing);
      expect(find.text('QUALQUER UMA'), findsNothing);
      expect(find.text('Compet\u00eancia necess\u00e1ria'), findsNothing);
    },
  );

  testWidgets('competencia isolada usa linguagem de objetivo', (tester) async {
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
      find.text('Ganha a compet\u00eancia necess\u00e1ria para desbloquear'),
      findsOneWidget,
    );
  });

  testWidgets('elemento estrutural tambem recebe resumo amigavel', (
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
        const Key('learning-map-special-checkpoint-checkpoint-target'),
      ),
      findsOneWidget,
    );
    expect(
      find.text('Completa a miss\u00e3o anterior para desbloquear'),
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
