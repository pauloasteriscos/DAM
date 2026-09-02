import 'package:dailytalk_mobile/domain/learning/learning_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final vocabulary = ActivityId('arrival.vocabulary-01');
  final dialogue = ActivityId('arrival.dialogue-01');
  final greeting = CompetencyId('arrival.greeting');

  group('PrerequisiteGroup ALL', () {
    test('exige que todas as regras estejam satisfeitas', () {
      final rule = PrerequisiteGroup.all([
        ActivityCompletedRequirement(vocabulary),
        CompetencyAchievedRequirement(greeting),
      ]);

      expect(
        rule.isSatisfiedBy(
          ProgressionFacts(
            completedActivities: [vocabulary],
            achievedCompetencies: [greeting],
          ),
        ),
        isTrue,
      );

      expect(
        rule.isSatisfiedBy(ProgressionFacts(completedActivities: [vocabulary])),
        isFalse,
      );
    });
  });

  group('PrerequisiteGroup ANY', () {
    test('aceita qualquer caminho concluído', () {
      final rule = PrerequisiteGroup.any([
        ActivityCompletedRequirement(vocabulary),
        ActivityCompletedRequirement(dialogue),
      ]);

      expect(
        rule.isSatisfiedBy(ProgressionFacts(completedActivities: [dialogue])),
        isTrue,
      );
      expect(rule.isSatisfiedBy(ProgressionFacts()), isFalse);
    });

    test('pode ser combinado dentro de um gate ALL', () {
      final practicePath = PrerequisiteGroup.any([
        ActivityCompletedRequirement(vocabulary),
        ActivityCompletedRequirement(dialogue),
      ]);
      final integratedGate = PrerequisiteGroup.all([
        practicePath,
        CompetencyAchievedRequirement(greeting),
      ]);

      expect(
        integratedGate.isSatisfiedBy(
          ProgressionFacts(
            completedActivities: [vocabulary],
            achievedCompetencies: [greeting],
          ),
        ),
        isTrue,
      );
    });
  });

  test('grupo vazio é inválido', () {
    expect(
      () => PrerequisiteGroup.all(const <PrerequisiteRule>[]),
      throwsArgumentError,
    );
  });

  test('factos são expostos como coleções imutáveis', () {
    final facts = ProgressionFacts(completedActivities: [vocabulary]);

    expect(
      () => facts.completedActivities.add(dialogue),
      throwsUnsupportedError,
    );
  });
}
