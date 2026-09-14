import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/progression_engine.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_activity_navigation.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_view_model.dart';
import 'package:dailytalk_mobile/screens/dialogue_page.dart';
import 'package:dailytalk_mobile/screens/quiz_page.dart';
import 'package:dailytalk_mobile/screens/revision_page.dart';
import 'package:dailytalk_mobile/screens/vocabulary_pairs_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps the four existing activity types to concrete screens', () {
    final vocabulary = LearningMapActivityNavigation.resolve(
      _activity(
        type: LearningActivityType.vocabulary,
        state: LearningActivityState.available,
      ),
    );

    final dialogue = LearningMapActivityNavigation.resolve(
      _activity(
        type: LearningActivityType.dialogue,
        state: LearningActivityState.available,
      ),
    );

    final quiz = LearningMapActivityNavigation.resolve(
      _activity(
        type: LearningActivityType.quiz,
        state: LearningActivityState.available,
      ),
    );

    final review = LearningMapActivityNavigation.resolve(
      _activity(
        type: LearningActivityType.review,
        state: LearningActivityState.available,
      ),
    );

    expect(
      vocabulary.disposition,
      LearningMapActivityNavigationDisposition.ready,
    );
    expect(vocabulary.destination, isA<VocabularyPairsPage>());

    expect(
      dialogue.disposition,
      LearningMapActivityNavigationDisposition.ready,
    );
    expect(dialogue.destination, isA<DialoguePage>());

    expect(quiz.disposition, LearningMapActivityNavigationDisposition.ready);
    expect(quiz.destination, isA<QuizPage>());

    expect(review.disposition, LearningMapActivityNavigationDisposition.ready);
    expect(review.destination, isA<RevisionPage>());
  });

  test('speech remains fail closed without a concrete screen', () {
    final decision = LearningMapActivityNavigation.resolve(
      _activity(
        type: LearningActivityType.speech,
        state: LearningActivityState.available,
      ),
    );

    expect(
      decision.disposition,
      LearningMapActivityNavigationDisposition.unsupported,
    );
    expect(decision.destination, isNull);
    expect(decision.canNavigate, isFalse);
  });

  test(
    'integrated challenge remains fail closed without a concrete screen',
    () {
      final decision = LearningMapActivityNavigation.resolve(
        _activity(
          type: LearningActivityType.integratedChallenge,
          state: LearningActivityState.available,
        ),
      );

      expect(
        decision.disposition,
        LearningMapActivityNavigationDisposition.unsupported,
      );
      expect(decision.destination, isNull);
      expect(decision.canNavigate, isFalse);
    },
  );

  test('locked activity is blocked before screen resolution', () {
    final decision = LearningMapActivityNavigation.resolve(
      _activity(
        type: LearningActivityType.dialogue,
        state: LearningActivityState.locked,
      ),
    );

    expect(
      decision.disposition,
      LearningMapActivityNavigationDisposition.blocked,
    );
    expect(decision.destination, isNull);
    expect(decision.canNavigate, isFalse);
  });

  test('structural element is invalid navigation input', () {
    final decision = LearningMapActivityNavigation.resolve(
      LearningMapElementViewModel(
        pathElementId: 'checkpoint-1',
        elementType: PathElementType.checkpoint,
        title: null,
        state: LearningActivityState.available,
        reason: ProgressionReason.ready,
        syncState: ProgressSyncState.clean,
        practicePreference: PracticePreference.balanced,
        competencyIds: const <String>{},
      ),
    );

    expect(
      decision.disposition,
      LearningMapActivityNavigationDisposition.invalid,
    );
    expect(decision.destination, isNull);
    expect(decision.canNavigate, isFalse);
  });

  test('missing activity type is invalid rather than guessed', () {
    final decision = LearningMapActivityNavigation.resolve(
      LearningMapElementViewModel(
        pathElementId: 'activity-without-type',
        elementType: PathElementType.activity,
        activityId: 'activity-without-type',
        revisionId: 'revision-1',
        title: 'Activity',
        state: LearningActivityState.available,
        reason: ProgressionReason.ready,
        syncState: ProgressSyncState.clean,
        practicePreference: PracticePreference.balanced,
        competencyIds: const <String>{},
      ),
    );

    expect(
      decision.disposition,
      LearningMapActivityNavigationDisposition.invalid,
    );
    expect(decision.destination, isNull);
    expect(decision.canNavigate, isFalse);
  });

  test('completed supported activity remains reopenable', () {
    final decision = LearningMapActivityNavigation.resolve(
      _activity(
        type: LearningActivityType.quiz,
        state: LearningActivityState.completed,
      ),
    );

    expect(
      decision.disposition,
      LearningMapActivityNavigationDisposition.ready,
    );
    expect(decision.destination, isA<QuizPage>());
    expect(decision.canNavigate, isTrue);
  });
}

LearningMapElementViewModel _activity({
  required LearningActivityType type,
  required LearningActivityState state,
}) {
  return LearningMapElementViewModel(
    pathElementId: 'element-${type.name}-${state.name}',
    elementType: PathElementType.activity,
    activityId: 'activity-${type.name}',
    revisionId: 'revision-${type.name}',
    activityType: type,
    title: 'Activity ${type.name}',
    instructions: 'Test activity.',
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
  );
}
