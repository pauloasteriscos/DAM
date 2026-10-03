import 'dart:collection';

import 'domain_ids.dart';
import 'learning_enums.dart';
import 'learning_lexical_contract.dart';
import 'learning_lexical_validator.dart';
import 'learning_models.dart';

enum LearningLexicalPackageValidationCode {
  coverageViolation,
  missingVocabularyExecution,

  // Codigo historico preservado para compatibilidade.
  introducedItemMissingFromExecution,

  // Um item declarado como pratica deve existir na execucao.
  practisedItemMissingFromExecution,

  // Um item executado deve estar classificado em practises.
  vocabularyItemMissingFromContract,

  // Regras de papel lexical especificas de atividades vocabulary.
  introducedItemMissingFromPractice,
  reinforcedItemMissingFromPractice,
  conflictingVocabularyRoles,
}

final class LearningLexicalPackageValidationIssue {
  const LearningLexicalPackageValidationIssue({
    required this.code,
    required this.location,
    required this.reference,
  });

  final LearningLexicalPackageValidationCode code;
  final String location;
  final String reference;

  @override
  String toString() => '${code.name} em $location: $reference';
}

final class LearningLexicalPackageValidationResult {
  LearningLexicalPackageValidationResult(
    Iterable<LearningLexicalPackageValidationIssue> issues,
  ) : issues = UnmodifiableListView(
        List<LearningLexicalPackageValidationIssue>.of(issues),
      );

  final List<LearningLexicalPackageValidationIssue> issues;

  bool get isValid => issues.isEmpty;
}

/// Validação editorial sobre o pacote oficial já descodificado.
///
/// Complementa [LearningLexicalCoverageValidator] com regras editoriais
/// especificas para atividades de vocabulary:
///
/// - `execution.items` e `practises` representam o mesmo conjunto;
/// - `introduces` deve ser subconjunto de `practises`;
/// - `reinforces` deve ser subconjunto de `practises`;
/// - um item vocabulary nao pode ser simultaneamente novo e reforco.
///
/// A cobertura temporal/por etapa continua sob responsabilidade de
/// [LearningLexicalCoverageValidator].
final class LearningLexicalPackageValidator {
  const LearningLexicalPackageValidator({
    LearningLexicalCoverageValidator coverageValidator =
        const LearningLexicalCoverageValidator(),
  }) : _coverageValidator = coverageValidator;

  final LearningLexicalCoverageValidator _coverageValidator;

  LearningLexicalPackageValidationResult inspect(
    LearningPath path,
    LearningLexicalContract contract,
  ) {
    final issues = <LearningLexicalPackageValidationIssue>[];

    final coverage = _coverageValidator.inspect(path, contract);
    for (final issue in coverage.issues) {
      issues.add(
        LearningLexicalPackageValidationIssue(
          code: LearningLexicalPackageValidationCode.coverageViolation,
          location: issue.location,
          reference: '${issue.code.name}:${issue.reference}',
        ),
      );
    }

    final contractsByActivity = <ActivityId, LearningLexicalActivityContract>{
      for (final activityContract in contract.activities)
        activityContract.activityId: activityContract,
    };

    for (final activity in path.activities) {
      if (activity.type != LearningActivityType.vocabulary) continue;

      final activityContract = contractsByActivity[activity.id];
      if (activityContract == null) {
        // A ausência já é reportada pelo coverage validator.
        continue;
      }

      final execution = activity.currentRevision.execution;
      if (execution is! VocabularyActivityExecution) {
        issues.add(
          LearningLexicalPackageValidationIssue(
            code:
                LearningLexicalPackageValidationCode.missingVocabularyExecution,
            location: 'activity:${activity.id.value}',
            reference: activity.currentRevision.id.value,
          ),
        );
        continue;
      }

      final executionIds = execution.items.map((item) => item.id).toSet();

      // Mantem o codigo de erro historico para itens explicitamente
      // introduzidos que deixem de existir na execucao.
      for (final lexicalId in activityContract.introduces) {
        if (!executionIds.contains(lexicalId)) {
          issues.add(
            LearningLexicalPackageValidationIssue(
              code: LearningLexicalPackageValidationCode
                  .introducedItemMissingFromExecution,
              location: 'activity:${activity.id.value}',
              reference: lexicalId,
            ),
          );
        }
      }

      // Em vocabulary, practises e a lista canonica do que e executado.
      // Itens praticados que nao sao introduces continuam validos quando
      // sao revisao/reforco de lexico previamente coberto.
      for (final lexicalId in activityContract.practises) {
        if (!executionIds.contains(lexicalId) &&
            !activityContract.introduces.contains(lexicalId)) {
          issues.add(
            LearningLexicalPackageValidationIssue(
              code: LearningLexicalPackageValidationCode
                  .practisedItemMissingFromExecution,
              location: 'activity:${activity.id.value}',
              reference: lexicalId,
            ),
          );
        }
      }

      for (final executionId in executionIds) {
        if (!activityContract.practises.contains(executionId)) {
          issues.add(
            LearningLexicalPackageValidationIssue(
              code: LearningLexicalPackageValidationCode
                  .vocabularyItemMissingFromContract,
              location: 'activity:${activity.id.value}',
              reference: executionId,
            ),
          );
        }
      }

      for (final lexicalId in activityContract.introduces) {
        if (!activityContract.practises.contains(lexicalId)) {
          issues.add(
            LearningLexicalPackageValidationIssue(
              code: LearningLexicalPackageValidationCode
                  .introducedItemMissingFromPractice,
              location: 'activity:${activity.id.value}',
              reference: lexicalId,
            ),
          );
        }
      }

      for (final lexicalId in activityContract.reinforces) {
        if (!activityContract.practises.contains(lexicalId)) {
          issues.add(
            LearningLexicalPackageValidationIssue(
              code: LearningLexicalPackageValidationCode
                  .reinforcedItemMissingFromPractice,
              location: 'activity:${activity.id.value}',
              reference: lexicalId,
            ),
          );
        }

        if (activityContract.introduces.contains(lexicalId)) {
          issues.add(
            LearningLexicalPackageValidationIssue(
              code: LearningLexicalPackageValidationCode
                  .conflictingVocabularyRoles,
              location: 'activity:${activity.id.value}',
              reference: lexicalId,
            ),
          );
        }
      }
    }

    return LearningLexicalPackageValidationResult(issues);
  }

  void validate(LearningPath path, LearningLexicalContract contract) {
    final result = inspect(path, contract);
    if (!result.isValid) {
      throw LearningLexicalPackageValidationException(result.issues);
    }
  }
}

final class LearningLexicalPackageValidationException extends ArgumentError {
  LearningLexicalPackageValidationException(
    Iterable<LearningLexicalPackageValidationIssue> issues,
  ) : issues = List<LearningLexicalPackageValidationIssue>.unmodifiable(issues),
      super(
        'Contrato lexical do pacote inválido: '
        '${issues.map((issue) => issue.toString()).join('; ')}',
      );

  final List<LearningLexicalPackageValidationIssue> issues;
}
