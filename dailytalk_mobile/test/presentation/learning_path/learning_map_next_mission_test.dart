import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/progression_engine.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_next_mission.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selects the navigable recommendation with the lowest rank', () {
    final model = _model(<LearningMapElementViewModel>[
      _activity(id: 'rank-2', type: LearningActivityType.quiz, rank: 2),
      _activity(id: 'rank-0', type: LearningActivityType.vocabulary, rank: 0),
      _activity(id: 'rank-1', type: LearningActivityType.dialogue, rank: 1),
    ]);

    expect(LearningMapNextMission.resolve(model)?.pathElementId, 'rank-0');
  });

  test('skips a locked recommendation without unlocking it', () {
    final locked = _activity(
      id: 'locked-primary',
      type: LearningActivityType.vocabulary,
      rank: 0,
      state: LearningActivityState.locked,
    );

    final fallback = _activity(
      id: 'open-secondary',
      type: LearningActivityType.dialogue,
      rank: 1,
    );

    final model = _model(<LearningMapElementViewModel>[locked, fallback]);

    final next = LearningMapNextMission.resolve(model);

    expect(next?.pathElementId, 'open-secondary');
    expect(locked.state, LearningActivityState.locked);
    expect(locked.canOpen, isFalse);
  });

  test('speech can now be the next navigable recommendation', () {
    final model = _model(<LearningMapElementViewModel>[
      _activity(
        id: 'speech-primary',
        type: LearningActivityType.speech,
        rank: 0,
      ),
      _activity(id: 'quiz-secondary', type: LearningActivityType.quiz, rank: 1),
    ]);

    expect(
      LearningMapNextMission.resolve(model)?.pathElementId,
      'speech-primary',
    );
  });

  test('skips integrated challenge while no concrete screen exists', () {
    final model = _model(<LearningMapElementViewModel>[
      _activity(
        id: 'challenge-primary',
        type: LearningActivityType.integratedChallenge,
        rank: 0,
      ),
      _activity(
        id: 'review-secondary',
        type: LearningActivityType.review,
        rank: 1,
      ),
    ]);

    expect(
      LearningMapNextMission.resolve(model)?.pathElementId,
      'review-secondary',
    );
  });

  test(
    'ignores structural elements even if they carry a recommendation rank',
    () {
      final structural = LearningMapElementViewModel(
        pathElementId: 'checkpoint',
        elementType: PathElementType.checkpoint,
        title: null,
        state: LearningActivityState.available,
        reason: ProgressionReason.ready,
        syncState: ProgressSyncState.clean,
        practicePreference: PracticePreference.balanced,
        competencyIds: const <String>{},
        recommendationRank: 0,
      );

      final activity = _activity(
        id: 'dialogue',
        type: LearningActivityType.dialogue,
        rank: 1,
      );

      final model = _model(<LearningMapElementViewModel>[structural, activity]);

      expect(LearningMapNextMission.resolve(model)?.pathElementId, 'dialogue');
    },
  );

  test('preserves authored order when recommendation ranks are equal', () {
    final model = _model(<LearningMapElementViewModel>[
      _activity(
        id: 'first-authored',
        type: LearningActivityType.vocabulary,
        rank: 0,
      ),
      _activity(
        id: 'second-authored',
        type: LearningActivityType.quiz,
        rank: 0,
      ),
    ]);

    expect(
      LearningMapNextMission.resolve(model)?.pathElementId,
      'first-authored',
    );
  });

  test('returns null when no recommended element is navigable', () {
    final model = _model(<LearningMapElementViewModel>[
      _activity(
        id: 'not-recommended',
        type: LearningActivityType.vocabulary,
        rank: null,
      ),
      _activity(
        id: 'locked',
        type: LearningActivityType.dialogue,
        rank: 0,
        state: LearningActivityState.locked,
      ),
      _activity(
        id: 'unsupported',
        type: LearningActivityType.integratedChallenge,
        rank: 1,
      ),
    ]);

    expect(LearningMapNextMission.resolve(model), isNull);
  });
}

LearningMapViewModel _model(List<LearningMapElementViewModel> elements) {
  return LearningMapViewModel(
    learningPathId: 'path',
    title: 'Path',
    locale: 'pt-PT',
    packageVersion: 1,
    recoveredFromFallback: false,
    completedActivityCount: 0,
    totalActivityCount: elements.where((element) => element.isActivity).length,
    journeys: <LearningMapJourneyViewModel>[
      LearningMapJourneyViewModel(
        id: 'journey',
        title: 'Journey',
        stages: <LearningMapStageViewModel>[
          LearningMapStageViewModel(
            id: 'stage',
            title: 'Stage',
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
  required int? rank,
  LearningActivityState state = LearningActivityState.available,
}) {
  return LearningMapElementViewModel(
    pathElementId: id,
    elementType: PathElementType.activity,
    activityId: 'activity-$id',
    revisionId: 'revision-$id',
    activityType: type,
    title: id,
    instructions: 'Test.',
    state: state,
    reason: switch (state) {
      LearningActivityState.locked => ProgressionReason.prerequisitesNotMet,
      LearningActivityState.available => ProgressionReason.ready,
      LearningActivityState.inProgress => ProgressionReason.attemptStarted,
      LearningActivityState.completed => ProgressionReason.completed,
    },
    syncState: ProgressSyncState.clean,
    practicePreference: PracticePreference.balanced,
    competencyIds: const <String>{'communication'},
    recommendationRank: rank,
  );
}
