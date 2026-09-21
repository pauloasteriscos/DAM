import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dailytalk_mobile/domain/learning/learning_content_codec.dart';
import 'package:dailytalk_mobile/domain/learning/learning_lexical_contract_codec.dart';
import 'package:dailytalk_mobile/domain/learning/learning_lexical_package_validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cases =
      <({String contentAsset, String lexicalAsset, String expectedPathId})>[
        (
          contentAsset: 'assets/content/official_pt_pt_phase1.v2.json',
          lexicalAsset: 'assets/content/official_pt_pt_phase1.lexical.v1.json',
          expectedPathId: 'student.pt-pt.phase1',
        ),
        (
          contentAsset: 'assets/content/official_en_us_phase1.v2.json',
          lexicalAsset: 'assets/content/official_en_us_phase1.lexical.v1.json',
          expectedPathId: 'student.en-us.phase1',
        ),
        (
          contentAsset: 'assets/content/official_es_es_phase1.v2.json',
          lexicalAsset: 'assets/content/official_es_es_phase1.lexical.v1.json',
          expectedPathId: 'student.es-es.phase1',
        ),
        (
          contentAsset: 'assets/content/official_fr_fr_phase1.v6.json',
          lexicalAsset: 'assets/content/official_fr_fr_phase1.lexical.v1.json',
          expectedPathId: 'student.fr-fr.phase1',
        ),
        (
          contentAsset: 'assets/content/official_it_it_phase1.v2.json',
          lexicalAsset: 'assets/content/official_it_it_phase1.lexical.v1.json',
          expectedPathId: 'student.it-it.phase1',
        ),
        (
          contentAsset: 'assets/content/official_de_de_phase1.v2.json',
          lexicalAsset: 'assets/content/official_de_de_phase1.lexical.v1.json',
          expectedPathId: 'student.de-de.phase1',
        ),
      ];

  test('os seis percursos oficiais satisfazem o contrato lexical real', () async {
    const contentCodec = LearningContentCodec();
    const lexicalCodec = LearningLexicalContractCodec();
    const validator = LearningLexicalPackageValidator();

    for (final item in cases) {
      final path = contentCodec.decodeString(
        await rootBundle.loadString(item.contentAsset),
      );
      final contract = lexicalCodec.decodeString(
        await rootBundle.loadString(item.lexicalAsset),
      );

      expect(path.id.value, item.expectedPathId);
      expect(contract.learningPathId.value, item.expectedPathId);

      final result = validator.inspect(path, contract);
      expect(
        result.isValid,
        isTrue,
        reason:
            '${item.expectedPathId}: ${result.issues.map((issue) => issue.toString()).join(' | ')}',
      );
    }
  });

  test(
    'o contrato cobre integralmente os itens de vocabulário existentes',
    () async {
      const contentCodec = LearningContentCodec();
      const lexicalCodec = LearningLexicalContractCodec();

      for (final item in cases) {
        final path = contentCodec.decodeString(
          await rootBundle.loadString(item.contentAsset),
        );
        final contract = lexicalCodec.decodeString(
          await rootBundle.loadString(item.lexicalAsset),
        );

        final contractsById = {
          for (final activity in contract.activities)
            activity.activityId: activity,
        };

        for (final activity in path.activities.where(
          (activity) => activity.type.name == 'vocabulary',
        )) {
          final execution = activity.currentRevision.execution;
          final introduced = contractsById[activity.id]!.introduces;
          final executionIds = (execution as dynamic).items
              .map<String>((item) => item.id as String)
              .toSet();

          expect(
            introduced,
            executionIds,
            reason: '${item.expectedPathId}/${activity.id.value}',
          );
        }
      }
    },
  );

  test('as missões reutilizam o léxico ensinado nos vocabulários', () async {
    const lexicalCodec = LearningLexicalContractCodec();

    for (final item in cases) {
      final contract = lexicalCodec.decodeString(
        await rootBundle.loadString(item.lexicalAsset),
      );

      final byId = {
        for (final activity in contract.activities)
          activity.activityId.value: activity,
      };

      expect(
        byId['arrival.vocabulary-01']!.introduces,
        containsAll(<String>[
          'hello',
          'good-morning',
          'thank-you',
          'please',
          'i-am',
          'my-name-is',
          'nice-to-meet-you',
          'yes',
          'thank-you-very-much',
        ]),
      );
      expect(
        byId['arrival.dialogue-01']!.practises,
        containsAll(<String>[
          'hello',
          'i-am',
          'nice-to-meet-you',
          'yes',
          'thank-you',
        ]),
      );
      expect(
        byId['arrival.speech-01']!.practises,
        containsAll(<String>['hello', 'my-name-is', 'thank-you-very-much']),
      );

      expect(
        byId['arrival.vocabulary-02']!.introduces,
        containsAll(<String>[
          'bedroom',
          'bathroom',
          'kitchen',
          'key',
          'help',
          'where-is-bathroom',
          'i-dont-understand',
          'very-nice',
        ]),
      );
      expect(
        byId['arrival.dialogue-02']!.practises,
        containsAll(<String>[
          'thank-you',
          'very-nice',
          'yes',
          'please',
          'where-is-bathroom',
        ]),
      );
      expect(
        byId['arrival.speech-02']!.practises,
        containsAll(<String>[
          'help',
          'please',
          'where-is-bathroom',
          'i-dont-understand',
        ]),
      );
    }
  });
}
