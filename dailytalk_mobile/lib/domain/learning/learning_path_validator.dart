import 'dart:collection';

import 'domain_ids.dart';
import 'learning_models.dart';
import 'prerequisite_rule.dart';

/// Código estável de um problema estrutural do percurso.
enum LearningPathValidationCode {
  duplicatePathElementId,
  missingElementActivity,
  missingPrerequisiteActivity,
  missingPrerequisiteCompetency,
  missingRevisionCompetency,
  cyclicActivityPrerequisite,
}

/// Problema de validação independente de mensagens apresentadas ao utilizador.
final class LearningPathValidationIssue {
  const LearningPathValidationIssue({
    required this.code,
    required this.location,
    required this.reference,
  });

  final LearningPathValidationCode code;

  /// Localização lógica estável dentro do agregado.
  final String location;

  /// Identificador duplicado, inexistente ou participante num ciclo.
  final String reference;

  @override
  String toString() => '${code.name} em $location: $reference';
}

/// Resultado imutável que permite inspecionar todos os problemas encontrados.
final class LearningPathValidationResult {
  LearningPathValidationResult(
    Iterable<LearningPathValidationIssue> issues,
  ) : issues = UnmodifiableListView(
          List<LearningPathValidationIssue>.of(issues),
        );

  final List<LearningPathValidationIssue> issues;

  bool get isValid => issues.isEmpty;
}

/// Exceção lançada quando um consumidor exige um percurso válido.
///
/// Mantém compatibilidade com consumidores que já tratavam conteúdo estrutural
/// inválido como [ArgumentError].
final class LearningPathValidationException extends ArgumentError {
  LearningPathValidationException._(this.issues)
      : super(
          'Percurso inválido: ${issues.map((issue) => issue.toString()).join('; ')}',
        );

  factory LearningPathValidationException(
    Iterable<LearningPathValidationIssue> issues,
  ) {
    return LearningPathValidationException._(
      List<LearningPathValidationIssue>.unmodifiable(issues),
    );
  }

  final List<LearningPathValidationIssue> issues;
}

/// Valida referências e dependências globais antes do uso do percurso.
final class LearningPathValidator {
  const LearningPathValidator();

  LearningPathValidationResult inspect(LearningPath path) {
    final issues = <LearningPathValidationIssue>[];
    final activityIds = path.activities.map((activity) => activity.id).toSet();
    final competencyIds = path.competencies
        .map((competency) => competency.id)
        .toSet();
    final elementIds = <PathElementId>{};
    final dependencies = <ActivityId, Set<ActivityId>>{
      for (final id in activityIds) id: <ActivityId>{},
    };

    for (final activity in path.activities) {
      for (final revision in activity.revisions) {
        for (final competencyId in revision.competencies) {
          if (!competencyIds.contains(competencyId)) {
            issues.add(
              LearningPathValidationIssue(
                code: LearningPathValidationCode.missingRevisionCompetency,
                location:
                    'activity:${activity.id}/revision:${revision.id}',
                reference: competencyId.value,
              ),
            );
          }
        }
      }
    }

    for (final journey in path.journeys) {
      for (final stage in journey.stages) {
        for (final element in stage.elements) {
          final location =
              'journey:${journey.id}/stage:${stage.id}/element:${element.id}';

          if (!elementIds.add(element.id)) {
            issues.add(
              LearningPathValidationIssue(
                code: LearningPathValidationCode.duplicatePathElementId,
                location: location,
                reference: element.id.value,
              ),
            );
          }

          final activityId = element.activityId;
          if (activityId != null && !activityIds.contains(activityId)) {
            issues.add(
              LearningPathValidationIssue(
                code: LearningPathValidationCode.missingElementActivity,
                location: location,
                reference: activityId.value,
              ),
            );
          }

          final prerequisites = element.prerequisites;
          if (prerequisites != null) {
            _inspectRule(
              prerequisites,
              location: location,
              ownerActivityId: activityId,
              activityIds: activityIds,
              competencyIds: competencyIds,
              dependencies: dependencies,
              issues: issues,
            );
          }
        }
      }
    }

    final cycle = _findCycle(dependencies);
    if (cycle != null) {
      issues.add(
        LearningPathValidationIssue(
          code: LearningPathValidationCode.cyclicActivityPrerequisite,
          location: 'learningPath:${path.id}',
          reference: cycle.map((id) => id.value).join(' -> '),
        ),
      );
    }

    return LearningPathValidationResult(issues);
  }

  void validate(LearningPath path) {
    final result = inspect(path);
    if (!result.isValid) {
      throw LearningPathValidationException(result.issues);
    }
  }

  void _inspectRule(
    PrerequisiteRule rule, {
    required String location,
    required ActivityId? ownerActivityId,
    required Set<ActivityId> activityIds,
    required Set<CompetencyId> competencyIds,
    required Map<ActivityId, Set<ActivityId>> dependencies,
    required List<LearningPathValidationIssue> issues,
  }) {
    if (rule is ActivityCompletedRequirement) {
      final requiredId = rule.activityId;
      if (!activityIds.contains(requiredId)) {
        issues.add(
          LearningPathValidationIssue(
            code: LearningPathValidationCode.missingPrerequisiteActivity,
            location: location,
            reference: requiredId.value,
          ),
        );
      } else if (ownerActivityId != null &&
          activityIds.contains(ownerActivityId)) {
        dependencies[ownerActivityId]!.add(requiredId);
      }
      return;
    }

    if (rule is CompetencyAchievedRequirement) {
      final requiredId = rule.competencyId;
      if (!competencyIds.contains(requiredId)) {
        issues.add(
          LearningPathValidationIssue(
            code: LearningPathValidationCode.missingPrerequisiteCompetency,
            location: location,
            reference: requiredId.value,
          ),
        );
      }
      return;
    }

    if (rule is PrerequisiteGroup) {
      for (final child in rule.rules) {
        _inspectRule(
          child,
          location: location,
          ownerActivityId: ownerActivityId,
          activityIds: activityIds,
          competencyIds: competencyIds,
          dependencies: dependencies,
          issues: issues,
        );
      }
    }
  }

  List<ActivityId>? _findCycle(
    Map<ActivityId, Set<ActivityId>> dependencies,
  ) {
    final visited = <ActivityId>{};
    final active = <ActivityId>{};
    final stack = <ActivityId>[];
    List<ActivityId>? cycle;

    bool visit(ActivityId id) {
      if (active.contains(id)) {
        final start = stack.indexOf(id);
        cycle = [...stack.sublist(start), id];
        return true;
      }
      if (!visited.add(id)) return false;

      active.add(id);
      stack.add(id);
      for (final dependency in dependencies[id] ?? const <ActivityId>{}) {
        if (visit(dependency)) return true;
      }
      stack.removeLast();
      active.remove(id);
      return false;
    }

    for (final id in dependencies.keys) {
      if (visit(id)) break;
    }
    return cycle;
  }
}
