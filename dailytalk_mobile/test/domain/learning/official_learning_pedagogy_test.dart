import 'dart:io';

import 'package:dailytalk_mobile/data/content/official_learning_path_resolver.dart';
import 'package:dailytalk_mobile/domain/learning/learning_content_codec.dart';
import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/learning_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = LearningContentCodec();

  test('baselines enriquecidas ensinam léxico antes de diálogo e fala', () {
    const expectedVocabulary01 = <String>{
      'hello',
      'good-morning',
      'thank-you',
      'please',
      'i-am',
      'my-name-is',
      'nice-to-meet-you',
      'yes',
      'thank-you-very-much',
    };
    const expectedVocabulary02 = <String>{
      'bedroom',
      'bathroom',
      'kitchen',
      'key',
      'help',
      'where-is-bathroom',
      'i-dont-understand',
      'very-nice',
    };

    for (final languageCode
        in OfficialLearningPathResolver.supportedLearningLanguageCodes) {
      final descriptor = OfficialLearningPathResolver.resolve(languageCode);
      final path = codec.decodeString(
        File(descriptor.baselineAssetPath).readAsStringSync(),
      );

      final vocabulary = {
        for (final activity in path.activities.where(
          (activity) => activity.type == LearningActivityType.vocabulary,
        ))
          activity.id.value:
              activity.currentRevision.execution as VocabularyActivityExecution,
      };

      expect(
        vocabulary['arrival.vocabulary-01']!.items
            .map((item) => item.id)
            .toSet(),
        expectedVocabulary01,
        reason: '$languageCode / vocabulary-01',
      );
      expect(
        vocabulary['arrival.vocabulary-02']!.items
            .map((item) => item.id)
            .toSet(),
        expectedVocabulary02,
        reason: '$languageCode / vocabulary-02',
      );
    }
  });

  test('novas baselines não reescrevem as versões históricas', () {
    const expectedVersions = <String, int>{
      'pt-PT': 8,
      'en-US': 8,
      'es-ES': 8,
      'fr-FR': 8,
      'it-IT': 8,
      'de-DE': 8,
    };

    for (final entry in expectedVersions.entries) {
      final descriptor = OfficialLearningPathResolver.resolve(entry.key);
      expect(descriptor.baselinePackageVersion, entry.value, reason: entry.key);

      final historicalName = entry.key.toLowerCase().replaceAll('-', '_');

      expect(
        File(
          'assets/content/official_${historicalName}_phase1.v7.json',
        ).existsSync(),
        isTrue,
        reason: 'release 7 history preserved ${entry.key}',
      );

      final historicalVersion = entry.key == 'fr-FR' ? 5 : 1;
      final previousVersion = entry.key == 'fr-FR' ? 6 : 2;
      expect(
        File(
          'assets/content/official_${historicalName}_phase1.v$historicalVersion.json',
        ).existsSync(),
        isTrue,
        reason: 'histórico ${entry.key} v$historicalVersion',
      );

      expect(
        File(
          'assets/content/official_${historicalName}_phase1.v$previousVersion.json',
        ).existsSync(),
        isTrue,
        reason: 'previous ${entry.key} v$previousVersion',
      );
    }
  });
}
