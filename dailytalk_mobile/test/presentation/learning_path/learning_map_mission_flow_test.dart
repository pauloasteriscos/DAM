import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/progression_engine.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_activity_navigation.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_mission_flow.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('refreshes only after an opened activity returns', () async {
    final events = <String>[];

    final refreshed = _model(<LearningMapElementViewModel>[
      _activity(id: 'next', type: LearningActivityType.quiz, rank: 0),
    ]);

    final flow = LearningMapMissionFlow(
      openActivity: (element) async {
        events.add('open:${element.pathElementId}');
        return LearningMapActivityNavigationOutcome.opened;
      },
      reloadModel: () async {
        events.add('reload');
        return refreshed;
      },
    );

    final result = await flow.openAndRefreshAfterReturn(
      _activity(id: 'current', type: LearningActivityType.vocabulary, rank: 0),
    );

    expect(events, <String>['open:current', 'reload']);

    expect(result.returnedFromActivity, isTrue);
    expect(result.refreshedModel, same(refreshed));
    expect(result.nextMission?.pathElementId, 'next');
  });

  test(
    'next mission comes from refreshed model rather than previous mission',
    () async {
      final refreshed = _model(<LearningMapElementViewModel>[
        _activity(
          id: 'new-primary',
          type: LearningActivityType.dialogue,
          rank: 0,
        ),
        _activity(
          id: 'old-primary',
          type: LearningActivityType.vocabulary,
          rank: 2,
        ),
      ]);

      final flow = LearningMapMissionFlow(
        openActivity: (_) async => LearningMapActivityNavigationOutcome.opened,
        reloadModel: () async => refreshed,
      );

      final result = await flow.openAndRefreshAfterReturn(
        _activity(
          id: 'old-primary',
          type: LearningActivityType.vocabulary,
          rank: 0,
        ),
      );

      expect(result.nextMission?.pathElementId, 'new-primary');
    },
  );

  test('blocked navigation does not reload the map', () async {
    var reloadCount = 0;

    final flow = LearningMapMissionFlow(
      openActivity: (_) async => LearningMapActivityNavigationOutcome.blocked,
      reloadModel: () async {
        reloadCount++;
        return _model(const <LearningMapElementViewModel>[]);
      },
    );

    final result = await flow.openAndRefreshAfterReturn(
      _activity(
        id: 'blocked',
        type: LearningActivityType.quiz,
        rank: 0,
        state: LearningActivityState.locked,
      ),
    );

    expect(reloadCount, 0);
    expect(result.returnedFromActivity, isFalse);
    expect(result.refreshedModel, isNull);
    expect(result.nextMission, isNull);
  });

  test('unsupported navigation does not reload the map', () async {
    var reloadCount = 0;

    final flow = LearningMapMissionFlow(
      openActivity: (_) async =>
          LearningMapActivityNavigationOutcome.unsupported,
      reloadModel: () async {
        reloadCount++;
        return _model(const <LearningMapElementViewModel>[]);
      },
    );

    final result = await flow.openAndRefreshAfterReturn(
      _activity(
        id: 'challenge',
        type: LearningActivityType.integratedChallenge,
        rank: 0,
      ),
    );

    expect(reloadCount, 0);
    expect(result.refreshedModel, isNull);
    expect(result.nextMission, isNull);
  });

  test('invalid navigation does not reload the map', () async {
    var reloadCount = 0;

    final flow = LearningMapMissionFlow(
      openActivity: (_) async => LearningMapActivityNavigationOutcome.invalid,
      reloadModel: () async {
        reloadCount++;
        return _model(const <LearningMapElementViewModel>[]);
      },
    );

    final structural = LearningMapElementViewModel(
      pathElementId: 'checkpoint',
      elementType: PathElementType.checkpoint,
      title: null,
      state: LearningActivityState.available,
      reason: ProgressionReason.ready,
      syncState: ProgressSyncState.clean,
      practicePreference: PracticePreference.balanced,
      competencyIds: const <String>{},
    );

    final result = await flow.openAndRefreshAfterReturn(structural);

    expect(reloadCount, 0);
    expect(result.refreshedModel, isNull);
    expect(result.nextMission, isNull);
  });

  test(
    'opened activity may return with no next navigable recommendation',
    () async {
      final refreshed = _model(<LearningMapElementViewModel>[
        _activity(
          id: 'unsupported',
          type: LearningActivityType.integratedChallenge,
          rank: 0,
        ),
      ]);

      final flow = LearningMapMissionFlow(
        openActivity: (_) async => LearningMapActivityNavigationOutcome.opened,
        reloadModel: () async => refreshed,
      );

      final result = await flow.openAndRefreshAfterReturn(
        _activity(id: 'current', type: LearningActivityType.review, rank: 0),
      );

      expect(result.returnedFromActivity, isTrue);
      expect(result.refreshedModel, same(refreshed));
      expect(result.nextMission, isNull);
    },
  );
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
