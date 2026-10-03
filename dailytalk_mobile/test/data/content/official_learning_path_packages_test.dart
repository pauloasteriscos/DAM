import 'dart:convert';
import 'dart:io';

import 'package:dailytalk_mobile/data/content/learning_content_import.dart';
import 'package:dailytalk_mobile/data/content/official_learning_path_resolver.dart';
import 'package:dailytalk_mobile/domain/learning/learning_content_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = LearningContentCodec();
  final importer = LearningContentImportService();

  test(
    'todas as baselines oficiais têm hash, schema e path coerentes',
    () async {
      for (final languageCode
          in OfficialLearningPathResolver.supportedLearningLanguageCodes) {
        final descriptor = OfficialLearningPathResolver.resolve(languageCode);
        final payload = File(descriptor.baselineAssetPath).readAsStringSync();

        expect(
          await importer.computeSha256(payload),
          descriptor.baselineSha256,
          reason: languageCode,
        );

        final path = codec.decodeString(payload);
        expect(path.id.value, descriptor.learningPathId, reason: languageCode);
        expect(path.schemaVersion.value, 2, reason: languageCode);
        expect(path.activities, isNotEmpty, reason: languageCode);
      }
    },
  );

  test('competências não colidem entre percursos de idiomas diferentes', () {
    final competencyIdsByLanguage = <String, Set<String>>{};

    for (final languageCode
        in OfficialLearningPathResolver.supportedLearningLanguageCodes) {
      final descriptor = OfficialLearningPathResolver.resolve(languageCode);
      final payload = File(descriptor.baselineAssetPath).readAsStringSync();
      final path = codec.decodeString(payload);

      competencyIdsByLanguage[languageCode] = path.competencies
          .map((competency) => competency.id.value)
          .toSet();
    }

    final entries = competencyIdsByLanguage.entries.toList(growable: false);
    for (var left = 0; left < entries.length; left++) {
      for (var right = left + 1; right < entries.length; right++) {
        expect(
          entries[left].value.intersection(entries[right].value),
          isEmpty,
          reason: '${entries[left].key} x ${entries[right].key}',
        );
      }
    }
  });

  test(
    'release 8 uniforme preserva baseline anterior e evolui Lição 3 por nova revisão',
    () {
      const codec = LearningContentCodec();

      const previousVersions = <String, int>{
        'pt-PT': 2,
        'en-US': 2,
        'es-ES': 2,
        'fr-FR': 6,
        'it-IT': 2,
        'de-DE': 2,
      };

      for (final entry in previousVersions.entries) {
        final descriptor = OfficialLearningPathResolver.resolve(entry.key);

        expect(descriptor.baselinePackageVersion, 8, reason: entry.key);

        final current = codec.decodeString(
          File(descriptor.baselineAssetPath).readAsStringSync(),
        );

        final historicalName = entry.key.toLowerCase().replaceAll('-', '_');
        final previous = codec.decodeString(
          File(
            'assets/content/official_${historicalName}_phase1.v${entry.value}.json',
          ).readAsStringSync(),
        );

        expect(
          current.id.value,
          previous.id.value,
          reason: '${entry.key} path id',
        );

        final languageNamespace = current.id.value.split('.')[1];

        expect(
          current.competencies.every(
            (competency) =>
                competency.id.value.startsWith('arrival.$languageNamespace.'),
          ),
          isTrue,
          reason: '${entry.key} competency namespace',
        );

        final previousRevisionByActivity = <String, String>{
          for (final activity in previous.activities)
            activity.id.value: activity.currentRevisionId.value,
        };

        for (final activity in current.activities) {
          final previousRevision =
              previousRevisionByActivity[activity.id.value];

          if (previousRevision == null) {
            continue;
          }

          expect(
            activity.currentRevisionId.value,
            previousRevision,
            reason:
                '${entry.key} published revision changed: ${activity.id.value}',
          );
        }

        expect(
          current.activities,
          hasLength(previous.activities.length + 1),
          reason: '${entry.key} activity count',
        );

        final lesson3 = current.activities.singleWhere(
          (activity) => activity.id.value == 'arrival.vocabulary-03',
        );

        expect(
          lesson3.currentRevisionId.value,
          'arrival.vocabulary-03.revision-02',
          reason: entry.key,
        );
        expect(lesson3.revisions, hasLength(2), reason: entry.key);
        expect(
          lesson3.revisions.map((revision) => revision.id.value),
          orderedEquals(<String>[
            'arrival.vocabulary-03.revision-01',
            'arrival.vocabulary-03.revision-02',
          ]),
          reason: entry.key,
        );
        expect(lesson3.revisions[0].revisionNumber, 1, reason: entry.key);
        expect(lesson3.revisions[1].revisionNumber, 2, reason: entry.key);
      }
    },
  );

  test('release 8 preserva revision-01 da Lição 3 e ativa revision-02', () {
    for (final languageCode
        in OfficialLearningPathResolver.supportedLearningLanguageCodes) {
      final descriptor = OfficialLearningPathResolver.resolve(languageCode);
      final historicalName = languageCode.toLowerCase().replaceAll('-', '_');

      final release7 =
          jsonDecode(
                File(
                  'assets/content/official_${historicalName}_phase1.v7.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final release8 =
          jsonDecode(File(descriptor.baselineAssetPath).readAsStringSync())
              as Map<String, dynamic>;

      final release7Activity = (release7['activities']! as List)
          .cast<Map<String, dynamic>>()
          .singleWhere((activity) => activity['id'] == 'arrival.vocabulary-03');
      final release8Activity = (release8['activities']! as List)
          .cast<Map<String, dynamic>>()
          .singleWhere((activity) => activity['id'] == 'arrival.vocabulary-03');

      expect(
        release7Activity['currentRevisionId'],
        'arrival.vocabulary-03.revision-01',
        reason: '$languageCode v7 current revision',
      );
      expect(
        release8Activity['currentRevisionId'],
        'arrival.vocabulary-03.revision-02',
        reason: '$languageCode v8 current revision',
      );

      final release7Revisions = (release7Activity['revisions']! as List)
          .cast<Map<String, dynamic>>();
      final release8Revisions = (release8Activity['revisions']! as List)
          .cast<Map<String, dynamic>>();

      expect(release7Revisions, hasLength(1), reason: languageCode);
      expect(release8Revisions, hasLength(2), reason: languageCode);

      final release7Revision01 = release7Revisions.singleWhere(
        (revision) => revision['id'] == 'arrival.vocabulary-03.revision-01',
      );
      final release8Revision01 = release8Revisions.singleWhere(
        (revision) => revision['id'] == 'arrival.vocabulary-03.revision-01',
      );
      final release8Revision02 = release8Revisions.singleWhere(
        (revision) => revision['id'] == 'arrival.vocabulary-03.revision-02',
      );

      expect(
        release8Revision01,
        equals(release7Revision01),
        reason: '$languageCode revision-01 immutable history',
      );
      expect(
        release8Revision02['revisionNumber'],
        2,
        reason: '$languageCode revision-02 number',
      );
      expect(
        release8Revision02['activityId'],
        'arrival.vocabulary-03',
        reason: '$languageCode revision-02 activity',
      );
    }
  });
}
