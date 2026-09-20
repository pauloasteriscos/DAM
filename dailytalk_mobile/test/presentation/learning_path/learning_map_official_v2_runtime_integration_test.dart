import 'package:dailytalk_mobile/data/repositories/learning_progress_read_repository.dart';
import 'package:dailytalk_mobile/domain/learning/learning_content_codec.dart';
import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/learning_models.dart';
import 'package:dailytalk_mobile/domain/learning/progression_engine.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_activity_navigation.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_assembler.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_view_model.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_mission_detail_page.dart';
import 'package:dailytalk_mobile/screens/dialogue_page.dart';
import 'package:dailytalk_mobile/screens/speech_practice_page.dart';
import 'package:dailytalk_mobile/screens/vocabulary_pairs_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _assetPath = 'assets/content/phase1_example_path.v2.json';
const _packageVersion = 2001;

Future<LearningPath> _loadOfficialV2Path() async {
  final source = await rootBundle.loadString(_assetPath);
  return const LearningContentCodec().decodeString(source);
}

List<LearningProgressProjectionEntry> _projectionFor(LearningPath path) {
  final now = DateTime.utc(2026, 9, 16);
  var recommendationRank = 0;

  return <LearningProgressProjectionEntry>[
    for (final journey in path.journeys)
      for (final stage in journey.stages)
        for (final element in stage.elements)
          LearningProgressProjectionEntry(
            pathElementId: element.id.value,
            activityId: element.activityId?.value,
            state: LearningActivityState.available,
            reason: ProgressionReason.ready,
            recommendationRank: element.activityId == null
                ? null
                : recommendationRank++,
            packageVersion: _packageVersion,
            updatedAt: now,
          ),
  ];
}

LearningMapViewModel _assemble(LearningPath path) {
  return const LearningMapAssembler().build(
    learningPath: path,
    packageVersion: _packageVersion,
    recoveredFromFallback: false,
    locale: 'pt-PT',
    projection: _projectionFor(path),
    syncStates: const <String, ProgressSyncState>{},
  );
}

LearningMapElementViewModel _activity(
  LearningMapViewModel model,
  String activityId,
) {
  return model.elements.firstWhere(
    (element) => element.activityId == activityId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'official schema-v2 asset decodes into executable current revisions',
    () async {
      final path = await _loadOfficialV2Path();

      expect(path.id.value, 'student.fr-fr.phase1');
      expect(path.schemaVersion.value, 2);
      expect(path.defaultLocale, 'pt-PT');

      final vocabulary = path.activities.firstWhere(
        (activity) => activity.id.value == 'arrival.vocabulary-01',
      );
      final dialogue = path.activities.firstWhere(
        (activity) => activity.id.value == 'arrival.dialogue-01',
      );
      final speech = path.activities.firstWhere(
        (activity) => activity.id.value == 'arrival.speech-01',
      );

      expect(
        vocabulary.currentRevision.execution,
        isA<VocabularyActivityExecution>(),
      );
      expect(
        dialogue.currentRevision.execution,
        isA<DialogueActivityExecution>(),
      );
      expect(speech.currentRevision.execution, isA<SpeechActivityExecution>());
    },
  );

  test(
    'official asset reaches real runtime constructors without revision drift',
    () async {
      final path = await _loadOfficialV2Path();
      final model = _assemble(path);

      final vocabulary = _activity(model, 'arrival.vocabulary-01');
      final dialogue = _activity(model, 'arrival.dialogue-01');
      final speech = _activity(model, 'arrival.speech-01');

      expect(vocabulary.revisionId, 'arrival.vocabulary-01.revision-01');
      expect(dialogue.revisionId, 'arrival.dialogue-01.revision-01');
      expect(speech.revisionId, 'arrival.speech-01.revision-01');

      final vocabularyDecision = LearningMapActivityNavigation.resolve(
        vocabulary,
      );
      expect(
        vocabularyDecision.disposition,
        LearningMapActivityNavigationDisposition.ready,
      );
      expect(vocabularyDecision.destination, isA<LearningMissionDetailPage>());

      final vocabularyDetail =
          vocabularyDecision.destination! as LearningMissionDetailPage;
      expect(vocabularyDetail.mission.revisionId, vocabulary.revisionId);
      expect(vocabularyDetail.runtimeDestination, isA<VocabularyPairsPage>());

      final vocabularyPage =
          vocabularyDetail.runtimeDestination as VocabularyPairsPage;
      expect(vocabularyPage.execution, same(vocabulary.execution));
      expect(vocabularyPage.contentDefaultLocale, 'pt-PT');

      final vocabularyExecution = vocabularyPage.execution!;
      expect(vocabularyExecution.items.first.id, 'hello');
      expect(
        vocabularyExecution.items.first.text.resolve(
          'fr-FR',
          fallbackLocale: 'pt-PT',
        ),
        'Bonjour',
      );

      final dialogueDecision = LearningMapActivityNavigation.resolve(dialogue);
      expect(
        dialogueDecision.disposition,
        LearningMapActivityNavigationDisposition.ready,
      );
      expect(dialogueDecision.destination, isA<LearningMissionDetailPage>());

      final dialogueDetail =
          dialogueDecision.destination! as LearningMissionDetailPage;
      expect(dialogueDetail.mission.revisionId, dialogue.revisionId);
      expect(dialogueDetail.runtimeDestination, isA<DialoguePage>());

      final dialoguePage = dialogueDetail.runtimeDestination as DialoguePage;
      expect(dialoguePage.execution, same(dialogue.execution));
      expect(dialoguePage.contentDefaultLocale, 'pt-PT');

      final dialogueExecution = dialoguePage.execution!;
      expect(dialogueExecution.turns.first.id, 'turn-01');
      expect(
        dialogueExecution.scenarioTitle.resolve(
          'pt-PT',
          fallbackLocale: 'pt-PT',
        ),
        'Primeira apresentação',
      );

      final speechDecision = LearningMapActivityNavigation.resolve(speech);
      expect(
        speechDecision.disposition,
        LearningMapActivityNavigationDisposition.ready,
      );
      expect(speechDecision.destination, isA<LearningMissionDetailPage>());

      final speechDetail =
          speechDecision.destination! as LearningMissionDetailPage;
      expect(speechDetail.mission.revisionId, speech.revisionId);
      expect(speechDetail.runtimeDestination, isA<SpeechPracticePage>());

      final speechPage = speechDetail.runtimeDestination as SpeechPracticePage;
      expect(speechPage.execution, same(speech.execution));
      expect(speechPage.contentDefaultLocale, 'pt-PT');

      final speechExecution = speechPage.execution!;
      expect(speechExecution.prompts.first.id, 'speech-hello');
      expect(
        speechExecution.prompts.first.text.resolve(
          'fr-FR',
          fallbackLocale: 'pt-PT',
        ),
        'Bonjour !',
      );
    },
  );
}
