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

  test('baseline francesa v5 usa namespace próprio e RevisionIds novos', () {
    final descriptor = OfficialLearningPathResolver.resolve('fr-FR');
    final payload = File(descriptor.baselineAssetPath).readAsStringSync();
    final path = codec.decodeString(payload);

    expect(descriptor.baselinePackageVersion, 5);
    expect(path.schemaVersion.value, 2);
    expect(path.activities, hasLength(6));
    expect(
      path.activities.every(
        (activity) =>
            activity.currentRevisionId.value.endsWith('.revision-05') &&
            activity.revisions.length == 1 &&
            activity.currentRevision.revisionNumber == 5,
      ),
      isTrue,
    );

    expect(
      path.competencies.map((competency) => competency.id.value),
      everyElement(startsWith('arrival.fr-fr.')),
    );
  });

  test('todos os idiomas ativos mantêm a mesma experiência estrutural', () {
    Map<String, Object?> experienceShape(String languageCode) {
      final descriptor = OfficialLearningPathResolver.resolve(languageCode);
      final json =
          jsonDecode(File(descriptor.baselineAssetPath).readAsStringSync())
              as Map<String, dynamic>;

      final journeys = (json['journeys'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final activities = (json['activities'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

      Map<String, Object?> normalizePrerequisite(dynamic value) {
        if (value == null) {
          return const <String, Object?>{};
        }

        final rule = value as Map<String, dynamic>;
        final type = rule['type'] as String;

        if (type == 'activityCompleted') {
          return <String, Object?>{
            'type': type,
            'activityId': rule['activityId'],
          };
        }

        if (type == 'competencyAchieved') {
          final competencyId = rule['competencyId'] as String;
          return <String, Object?>{
            'type': type,
            'competencySuffix': competencyId.split('.').last,
          };
        }

        final rules = (rule['rules'] as List<dynamic>)
            .map(normalizePrerequisite)
            .toList(growable: false);

        return <String, Object?>{
          'type': type,
          'operator': rule['operator'],
          'rules': rules,
        };
      }

      int payloadCount(Map<String, dynamic> execution) {
        for (final key in const <String>[
          'items',
          'turns',
          'prompts',
          'questions',
          'steps',
        ]) {
          final value = execution[key];
          if (value is List<dynamic>) {
            return value.length;
          }
        }
        return 0;
      }

      return <String, Object?>{
        'stages': <Object?>[
          for (final journey in journeys)
            for (final stage
                in (journey['stages'] as List<dynamic>)
                    .cast<Map<String, dynamic>>())
              <String, Object?>{
                'id': stage['id'],
                'elements': (stage['elements'] as List<dynamic>)
                    .cast<Map<String, dynamic>>()
                    .map(
                      (element) => <String, Object?>{
                        'id': element['id'],
                        'activityId': element['activityId'],
                        'practicePreference': element['practicePreference'],
                        'prerequisites': normalizePrerequisite(
                          element['prerequisites'],
                        ),
                      },
                    )
                    .toList(growable: false),
              },
        ],
        'activities': activities
            .map((activity) {
              final revision = (activity['revisions'] as List<dynamic>)
                  .cast<Map<String, dynamic>>()
                  .single;
              final execution = revision['execution'] as Map<String, dynamic>;

              return <String, Object?>{
                'id': activity['id'],
                'type': activity['type'],
                'executionKind': execution['kind'],
                'payloadCount': payloadCount(execution),
              };
            })
            .toList(growable: false),
      };
    }

    final reference = experienceShape('en-US');

    for (final languageCode
        in OfficialLearningPathResolver.supportedLearningLanguageCodes) {
      expect(experienceShape(languageCode), reference, reason: languageCode);
    }
  });
}
