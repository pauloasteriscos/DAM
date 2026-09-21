import 'dart:collection';

import 'domain_ids.dart';
import 'learning_enums.dart';
import 'learning_lexical_contract.dart';
import 'learning_models.dart';

enum LearningLexicalValidationCode {
  learningPathMismatch,
  duplicateActivityContract,
  unknownActivity,
  missingActivityContract,
  introductionOnNonVocabulary,
  missingVocabularyCoverage,
}

final class LearningLexicalValidationIssue {
  const LearningLexicalValidationIssue({
    required this.code,
    required this.location,
    required this.reference,
  });

  final LearningLexicalValidationCode code;
  final String location;
  final String reference;

  @override
  String toString() => '${code.name} em $location: $reference';
}

final class LearningLexicalValidationResult {
  LearningLexicalValidationResult(
    Iterable<LearningLexicalValidationIssue> issues,
  ) : issues = UnmodifiableListView(
        List<LearningLexicalValidationIssue>.of(issues),
      );

  final List<LearningLexicalValidationIssue> issues;

  bool get isValid => issues.isEmpty;
}

/// Valida coerência lexical sem alterar a liberdade de percurso.
///
/// A regra central é deliberadamente diferente de um pré-requisito:
/// atividades de vocabulário, diálogo e fala podem continuar disponíveis em
/// paralelo. Para cada etapa, porém, todo léxico praticado/reforçado deve estar
/// coberto por vocabulário da própria etapa ou de uma etapa anterior.
final class LearningLexicalCoverageValidator {
  const LearningLexicalCoverageValidator();

  static const Set<LearningActivityType> governedTypes = <LearningActivityType>{
    LearningActivityType.vocabulary,
    LearningActivityType.dialogue,
    LearningActivityType.speech,
  };

  LearningLexicalValidationResult inspect(
    LearningPath path,
    LearningLexicalContract contract,
  ) {
    final issues = <LearningLexicalValidationIssue>[];

    if (contract.learningPathId != path.id) {
      issues.add(
        LearningLexicalValidationIssue(
          code: LearningLexicalValidationCode.learningPathMismatch,
          location: 'learningPath:${path.id.value}',
          reference: contract.learningPathId.value,
        ),
      );
      return LearningLexicalValidationResult(issues);
    }

    final activitiesById = <ActivityId, Activity>{
      for (final activity in path.activities) activity.id: activity,
    };
    final contractsByActivity = <ActivityId, LearningLexicalActivityContract>{};

    for (final activityContract in contract.activities) {
      if (contractsByActivity.containsKey(activityContract.activityId)) {
        issues.add(
          LearningLexicalValidationIssue(
            code: LearningLexicalValidationCode.duplicateActivityContract,
            location: 'contract:${contract.learningPathId.value}',
            reference: activityContract.activityId.value,
          ),
        );
        continue;
      }
      contractsByActivity[activityContract.activityId] = activityContract;

      final activity = activitiesById[activityContract.activityId];
      if (activity == null) {
        issues.add(
          LearningLexicalValidationIssue(
            code: LearningLexicalValidationCode.unknownActivity,
            location: 'contract:${contract.learningPathId.value}',
            reference: activityContract.activityId.value,
          ),
        );
        continue;
      }

      if (activityContract.introduces.isNotEmpty &&
          activity.type != LearningActivityType.vocabulary) {
        issues.add(
          LearningLexicalValidationIssue(
            code: LearningLexicalValidationCode.introductionOnNonVocabulary,
            location: 'activity:${activity.id.value}',
            reference: activity.type.name,
          ),
        );
      }
    }

    for (final activity in path.activities) {
      if (governedTypes.contains(activity.type) &&
          !contractsByActivity.containsKey(activity.id)) {
        issues.add(
          LearningLexicalValidationIssue(
            code: LearningLexicalValidationCode.missingActivityContract,
            location: 'activity:${activity.id.value}',
            reference: activity.type.name,
          ),
        );
      }
    }

    final introducedBefore = <String>{};

    for (final journey in path.journeys) {
      for (final stage in journey.stages) {
        final stageActivityIds = stage.elements
            .where(
              (element) =>
                  element.type == PathElementType.activity &&
                  element.activityId != null,
            )
            .map((element) => element.activityId!)
            .toList(growable: false);

        // Atividades paralelas da mesma etapa partilham o léxico editorial.
        // Por isso a introdução de vocabulário da etapa conta como cobertura
        // mesmo que o aluno escolha diálogo/fala primeiro.
        final availableInStage = <String>{...introducedBefore};
        for (final activityId in stageActivityIds) {
          final activity = activitiesById[activityId];
          final activityContract = contractsByActivity[activityId];
          if (activity?.type == LearningActivityType.vocabulary &&
              activityContract != null) {
            availableInStage.addAll(activityContract.introduces);
          }
        }

        for (final activityId in stageActivityIds) {
          final activityContract = contractsByActivity[activityId];
          if (activityContract == null) continue;

          for (final lexicalId in activityContract.consumed) {
            if (!availableInStage.contains(lexicalId)) {
              issues.add(
                LearningLexicalValidationIssue(
                  code: LearningLexicalValidationCode.missingVocabularyCoverage,
                  location:
                      'journey:${journey.id.value}/stage:${stage.id.value}/activity:${activityId.value}',
                  reference: lexicalId,
                ),
              );
            }
          }
        }

        introducedBefore
          ..clear()
          ..addAll(availableInStage);
      }
    }

    return LearningLexicalValidationResult(issues);
  }

  void validate(LearningPath path, LearningLexicalContract contract) {
    final result = inspect(path, contract);
    if (!result.isValid) {
      throw LearningLexicalValidationException(result.issues);
    }
  }
}

final class LearningLexicalValidationException extends ArgumentError {
  LearningLexicalValidationException(
    Iterable<LearningLexicalValidationIssue> issues,
  ) : issues = List<LearningLexicalValidationIssue>.unmodifiable(issues),
      super(
        'Contrato lexical inválido: '
        '${issues.map((issue) => issue.toString()).join('; ')}',
      );

  final List<LearningLexicalValidationIssue> issues;
}
