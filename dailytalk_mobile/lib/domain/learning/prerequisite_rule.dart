import 'dart:collection';

import 'domain_ids.dart';
import 'learning_enums.dart';

/// Factos pedagógicos monotónicos usados para avaliar pré-requisitos.
final class ProgressionFacts {
  ProgressionFacts({
    Iterable<ActivityId> completedActivities = const <ActivityId>[],
    Iterable<CompetencyId> achievedCompetencies = const <CompetencyId>[],
  }) : completedActivities = UnmodifiableSetView(
         Set<ActivityId>.of(completedActivities),
       ),
       achievedCompetencies = UnmodifiableSetView(
         Set<CompetencyId>.of(achievedCompetencies),
       );

  final Set<ActivityId> completedActivities;
  final Set<CompetencyId> achievedCompetencies;
}

/// Regra de pré-requisito independente da camada de apresentação.
sealed class PrerequisiteRule {
  const PrerequisiteRule();

  bool isSatisfiedBy(ProgressionFacts facts);
}

/// Exige a conclusão de uma atividade identificada de forma estável.
final class ActivityCompletedRequirement extends PrerequisiteRule {
  const ActivityCompletedRequirement(this.activityId);

  final ActivityId activityId;

  @override
  bool isSatisfiedBy(ProgressionFacts facts) =>
      facts.completedActivities.contains(activityId);
}

/// Exige que uma competência já tenha sido demonstrada.
final class CompetencyAchievedRequirement extends PrerequisiteRule {
  const CompetencyAchievedRequirement(this.competencyId);

  final CompetencyId competencyId;

  @override
  bool isSatisfiedBy(ProgressionFacts facts) =>
      facts.achievedCompetencies.contains(competencyId);
}

/// Grupo lógico de pré-requisitos com semântica ALL ou ANY.
///
/// Grupos vazios são rejeitados. Uma atividade sem pré-requisitos deve usar
/// `null` no respetivo elemento do percurso, evitando semântica ambígua.
final class PrerequisiteGroup extends PrerequisiteRule {
  PrerequisiteGroup({
    required this.operator,
    required Iterable<PrerequisiteRule> rules,
  }) : rules = List<PrerequisiteRule>.unmodifiable(rules) {
    if (this.rules.isEmpty) {
      throw ArgumentError.value(
        rules,
        'rules',
        'um grupo ALL/ANY deve conter pelo menos uma regra',
      );
    }
  }

  factory PrerequisiteGroup.all(Iterable<PrerequisiteRule> rules) =>
      PrerequisiteGroup(operator: PrerequisiteOperator.all, rules: rules);

  factory PrerequisiteGroup.any(Iterable<PrerequisiteRule> rules) =>
      PrerequisiteGroup(operator: PrerequisiteOperator.any, rules: rules);

  final PrerequisiteOperator operator;
  final List<PrerequisiteRule> rules;

  @override
  bool isSatisfiedBy(ProgressionFacts facts) {
    return switch (operator) {
      PrerequisiteOperator.all => rules.every(
        (rule) => rule.isSatisfiedBy(facts),
      ),
      PrerequisiteOperator.any => rules.any(
        (rule) => rule.isSatisfiedBy(facts),
      ),
    };
  }
}
