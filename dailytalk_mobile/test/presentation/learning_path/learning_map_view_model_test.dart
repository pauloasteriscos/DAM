import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/progression_engine.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('percurso calcula progresso apenas sobre atividades ativas', () {
    final model = LearningMapViewModel(
      learningPathId: 'path-1',
      title: 'Jornada Erasmus+',
      locale: 'pt-PT',
      packageVersion: 7,
      recoveredFromFallback: false,
      completedActivityCount: 3,
      totalActivityCount: 8,
      journeys: const <LearningMapJourneyViewModel>[],
    );

    expect(model.completedActivityCount, 3);
    expect(model.totalActivityCount, 8);
    expect(model.completionRatio, closeTo(0.375, 0.0001));
  });

  test('stage calcula progresso usando somente elementos de atividade', () {
    final stage = LearningMapStageViewModel(
      id: 'stage-1',
      title: 'Chegada à nova casa',
      elements: <LearningMapElementViewModel>[
        _activity(
          id: 'element-1',
          activityId: 'activity-1',
          state: LearningActivityState.completed,
        ),
        _activity(
          id: 'element-2',
          activityId: 'activity-2',
          state: LearningActivityState.available,
        ),
        _structural(id: 'checkpoint-1', type: PathElementType.checkpoint),
      ],
    );

    expect(stage.activityCount, 2);
    expect(stage.completedActivityCount, 1);
    expect(stage.completionRatio, 0.5);
  });

  test('menor recommendationRank define a próxima recomendação', () {
    final rankTwo = _activity(
      id: 'element-2',
      activityId: 'activity-2',
      state: LearningActivityState.available,
      recommendationRank: 2,
    );

    final rankZero = _activity(
      id: 'element-0',
      activityId: 'activity-0',
      state: LearningActivityState.inProgress,
      recommendationRank: 0,
    );

    final rankOne = _activity(
      id: 'element-1',
      activityId: 'activity-1',
      state: LearningActivityState.available,
      recommendationRank: 1,
    );

    final model = LearningMapViewModel(
      learningPathId: 'path-1',
      title: 'Jornada Erasmus+',
      locale: 'pt-PT',
      packageVersion: 7,
      recoveredFromFallback: false,
      completedActivityCount: 0,
      totalActivityCount: 3,
      journeys: <LearningMapJourneyViewModel>[
        LearningMapJourneyViewModel(
          id: 'journey-1',
          title: 'Jornada de Acolhimento',
          stages: <LearningMapStageViewModel>[
            LearningMapStageViewModel(
              id: 'stage-1',
              title: 'Chegada',
              elements: <LearningMapElementViewModel>[
                rankTwo,
                rankZero,
                rankOne,
              ],
            ),
          ],
        ),
      ],
    );

    expect(model.nextRecommendedElement?.pathElementId, 'element-0');
    expect(
      model.nextRecommendedElement?.state,
      LearningActivityState.inProgress,
    );
  });

  test('estado pedagógico e sync continuam independentes no ViewModel', () {
    final element = _activity(
      id: 'element-completed',
      activityId: 'activity-completed',
      state: LearningActivityState.completed,
      syncState: ProgressSyncState.pending,
    );

    expect(element.state, LearningActivityState.completed);
    expect(element.syncState, ProgressSyncState.pending);
    expect(element.canOpen, isTrue);
  });

  test('elemento locked não pode ser aberto', () {
    final element = _activity(
      id: 'element-locked',
      activityId: 'activity-locked',
      state: LearningActivityState.locked,
    );

    expect(element.isLocked, isTrue);
    expect(element.canOpen, isFalse);
  });
}

LearningMapElementViewModel _activity({
  required String id,
  required String activityId,
  required LearningActivityState state,
  ProgressSyncState syncState = ProgressSyncState.clean,
  int? recommendationRank,
}) {
  return LearningMapElementViewModel(
    pathElementId: id,
    elementType: PathElementType.activity,
    activityId: activityId,
    revisionId: '$activityId-r1',
    activityType: LearningActivityType.dialogue,
    title: 'Atividade',
    instructions: 'Instruções',
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
    origin: ContentOrigin.official,
    visibility: ContentVisibility.public,
    recommendationRank: recommendationRank,
  );
}

LearningMapElementViewModel _structural({
  required String id,
  required PathElementType type,
}) {
  return LearningMapElementViewModel(
    pathElementId: id,
    elementType: type,
    title: 'Checkpoint',
    competencyIds: const <String>{},
    state: LearningActivityState.available,
    reason: ProgressionReason.ready,
    syncState: ProgressSyncState.clean,
    practicePreference: PracticePreference.balanced,
  );
}
