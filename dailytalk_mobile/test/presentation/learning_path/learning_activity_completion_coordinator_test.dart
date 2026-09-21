import 'package:flutter_test/flutter_test.dart';

import 'package:dailytalk_mobile/data/repositories/learning_progress_repository.dart';
import 'package:dailytalk_mobile/domain/learning/domain_ids.dart';
import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/learning_models.dart';
import 'package:dailytalk_mobile/domain/learning/progression_engine.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_activity_completion_coordinator.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_view_model.dart';

void main() {
  test('mapeia missão para completeActivity com id estável em retry', () async {
    final captured = <CompleteLearningActivityWrite>[];
    var attempts = 0;

    final coordinator = LearningActivityCompletionCoordinator(
      accountId: 'account-1',
      learningPath: _path(),
      packageVersion: 7,
      clock: () => DateTime.utc(2026, 9, 21, 18, 30),
      clientCompletionIdFactory: () => 'completion-fixed-1',
      completeActivity: (command) async {
        captured.add(command);
        attempts++;

        if (attempts == 1) {
          throw StateError('simulated write failure');
        }

        return const CompleteLearningActivityResult(
          completionId: 41,
          alreadyCompleted: false,
        );
      },
    );

    final action = coordinator.actionFor(_element());

    expect(action, isNotNull);

    await expectLater(action!(), throwsStateError);
    await action();

    expect(captured, hasLength(2));
    expect(captured[0].clientCompletionId, 'completion-fixed-1');
    expect(captured[1].clientCompletionId, 'completion-fixed-1');
    expect(captured[1].accountId, 'account-1');
    expect(captured[1].activityId.value, 'arrival.vocabulary-01');
    expect(captured[1].revisionId.value, 'arrival.vocabulary-01.revision-01');
    expect(captured[1].packageVersion, 7);
    expect(captured[1].practicePreference, PracticePreference.vocabulary);

    await action();

    expect(captured, hasLength(2));
  });

  test('elemento estrutural não recebe action de conclusão', () {
    final coordinator = LearningActivityCompletionCoordinator(
      accountId: 'account-1',
      learningPath: _path(),
      packageVersion: 1,
      completeActivity: (_) async => const CompleteLearningActivityResult(
        completionId: 1,
        alreadyCompleted: false,
      ),
    );

    final action = coordinator.actionFor(
      LearningMapElementViewModel(
        pathElementId: 'checkpoint-01',
        elementType: PathElementType.checkpoint,
        state: LearningActivityState.available,
        reason: ProgressionReason.ready,
        syncState: ProgressSyncState.clean,
        practicePreference: PracticePreference.balanced,
        competencyIds: const <String>{},
      ),
    );

    expect(action, isNull);
  });
}

LearningMapElementViewModel _element() {
  return LearningMapElementViewModel(
    pathElementId: 'arrival.vocabulary-01.element',
    elementType: PathElementType.activity,
    activityId: 'arrival.vocabulary-01',
    revisionId: 'arrival.vocabulary-01.revision-01',
    activityType: LearningActivityType.vocabulary,
    state: LearningActivityState.available,
    reason: ProgressionReason.ready,
    syncState: ProgressSyncState.clean,
    practicePreference: PracticePreference.vocabulary,
    competencyIds: const <String>{'arrival.greetings'},
  );
}

LearningPath _path() {
  final activityId = ActivityId('arrival.vocabulary-01');
  final revisionId = RevisionId('arrival.vocabulary-01.revision-01');

  return LearningPath(
    id: LearningPathId('student.en-us.phase1'),
    schemaVersion: SchemaVersion(2),
    defaultLocale: 'en-US',
    title: _text('Arrival'),
    competencies: <Competency>[
      Competency(
        id: CompetencyId('arrival.greetings'),
        title: _text('Greetings'),
        description: _text('Useful greetings for first contact'),
      ),
    ],
    activities: <Activity>[
      Activity(
        id: activityId,
        type: LearningActivityType.vocabulary,
        origin: ContentOrigin.official,
        currentRevisionId: revisionId,
        revisions: <ActivityRevision>[
          ActivityRevision(
            id: revisionId,
            activityId: activityId,
            revisionNumber: 1,
            title: _text('Welcome words'),
            instructions: _text('Match the pairs.'),
            visibility: ContentVisibility.public,
            competencies: <CompetencyId>{CompetencyId('arrival.greetings')},
            execution: VocabularyActivityExecution(
              items: <VocabularyExecutionItem>[
                VocabularyExecutionItem(id: 'hello', text: _text('Hello')),
              ],
            ),
          ),
        ],
      ),
    ],
    journeys: <Journey>[
      Journey(
        id: JourneyId('journey-01'),
        title: _text('Arrival'),
        stages: <Stage>[
          Stage(
            id: StageId('stage-01'),
            title: _text('First contact'),
            elements: <PathElement>[
              PathElement(
                id: PathElementId('arrival.vocabulary-01.element'),
                type: PathElementType.activity,
                activityId: activityId,
                practicePreference: PracticePreference.vocabulary,
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

LocalizedText _text(String value) {
  return LocalizedText(<String, String>{'en-US': value, 'pt-PT': value});
}
