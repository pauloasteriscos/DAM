import '../../data/repositories/learning_progress_read_repository.dart';
import '../../domain/learning/learning_enums.dart';
import '../../domain/learning/learning_models.dart';
import '../../domain/learning/prerequisite_rule.dart';
import 'learning_map_view_model.dart';

enum LearningMapAssemblyErrorCode {
  duplicateProjectionEntry,
  missingProjectionEntry,
  unexpectedProjectionEntry,
  projectionPackageMismatch,
  projectionActivityMismatch,
  activityNotFound,
}

final class LearningMapAssemblyException implements Exception {
  const LearningMapAssemblyException({
    required this.code,
    required this.message,
    this.reference,
  });

  final LearningMapAssemblyErrorCode code;
  final String message;
  final String? reference;

  @override
  String toString() => 'LearningMapAssemblyException(${code.name}): $message';
}

/// Converte conteúdo oficial + projeção local num read model para a UI.
///
/// Não acede a SQLite, rede ou ProgressionEngine.
/// Toda a decisão pedagógica já deve estar persistida na projeção recebida.
final class LearningMapAssembler {
  const LearningMapAssembler();

  LearningMapViewModel build({
    required LearningPath learningPath,
    required int packageVersion,
    required bool recoveredFromFallback,
    required String locale,
    String? scaffoldingLocale,
    required List<LearningProgressProjectionEntry> projection,
    required Map<String, ProgressSyncState> syncStates,
  }) {
    final normalizedLocale = locale.trim();
    final normalizedScaffoldingLocale = (scaffoldingLocale ?? locale).trim();

    if (normalizedLocale.isEmpty) {
      throw ArgumentError.value(locale, 'locale', 'não pode estar vazio');
    }

    if (normalizedScaffoldingLocale.isEmpty) {
      throw ArgumentError.value(
        scaffoldingLocale,
        'scaffoldingLocale',
        'não pode estar vazio',
      );
    }

    final projectionByElement = <String, LearningProgressProjectionEntry>{};

    for (final entry in projection) {
      if (projectionByElement.containsKey(entry.pathElementId)) {
        throw LearningMapAssemblyException(
          code: LearningMapAssemblyErrorCode.duplicateProjectionEntry,
          reference: entry.pathElementId,
          message: 'A projeção contém mais de uma linha para o mesmo elemento.',
        );
      }

      if (entry.packageVersion != packageVersion) {
        throw LearningMapAssemblyException(
          code: LearningMapAssemblyErrorCode.projectionPackageMismatch,
          reference: entry.pathElementId,
          message: 'A projeção não corresponde à versão ativa do pacote.',
        );
      }

      projectionByElement[entry.pathElementId] = entry;
    }

    final activitiesById = {
      for (final activity in learningPath.activities)
        activity.id.value: activity,
    };

    final pathElementIdsByActivityId = <String, List<String>>{};

    for (final journey in learningPath.journeys) {
      for (final stage in journey.stages) {
        for (final element in stage.elements) {
          final activityId = element.activityId?.value;

          if (activityId == null) {
            continue;
          }

          pathElementIdsByActivityId
              .putIfAbsent(activityId, () => <String>[])
              .add(element.id.value);
        }
      }
    }
    final consumedProjectionIds = <String>{};
    final journeys = <LearningMapJourneyViewModel>[];

    var totalActivityCount = 0;
    var completedActivityCount = 0;

    for (final journey in learningPath.journeys) {
      final stages = <LearningMapStageViewModel>[];

      for (final stage in journey.stages) {
        final elements = <LearningMapElementViewModel>[];

        for (final element in stage.elements) {
          final elementId = element.id.value;
          final projected = projectionByElement[elementId];

          if (projected == null) {
            throw LearningMapAssemblyException(
              code: LearningMapAssemblyErrorCode.missingProjectionEntry,
              reference: elementId,
              message:
                  'Não existe projeção pedagógica para um elemento do percurso ativo.',
            );
          }

          consumedProjectionIds.add(elementId);

          final expectedActivityId = element.activityId?.value;

          if (projected.activityId != expectedActivityId) {
            throw LearningMapAssemblyException(
              code: LearningMapAssemblyErrorCode.projectionActivityMismatch,
              reference: elementId,
              message:
                  'A atividade da projeção não corresponde ao elemento do percurso.',
            );
          }

          if (expectedActivityId == null) {
            elements.add(
              LearningMapElementViewModel(
                pathElementId: elementId,
                elementType: element.type,
                title: null,
                competencyIds: const <String>{},
                state: projected.state,
                reason: projected.reason,
                syncState: ProgressSyncState.clean,
                practicePreference: element.practicePreference,
                prerequisites: _mapPrerequisite(
                  element.prerequisites,
                  pathElementIdsByActivityId,
                ),
                recommendationRank: projected.recommendationRank,
              ),
            );

            continue;
          }

          final activity = activitiesById[expectedActivityId];

          if (activity == null) {
            throw LearningMapAssemblyException(
              code: LearningMapAssemblyErrorCode.activityNotFound,
              reference: expectedActivityId,
              message:
                  'O elemento referencia uma atividade inexistente no percurso ativo.',
            );
          }

          final revision = activity.currentRevision;

          totalActivityCount++;

          if (projected.state == LearningActivityState.completed) {
            completedActivityCount++;
          }

          elements.add(
            LearningMapElementViewModel(
              pathElementId: elementId,
              elementType: element.type,
              activityId: activity.id.value,
              revisionId: revision.id.value,
              activityType: activity.type,
              title: revision.title.resolve(
                normalizedLocale,
                fallbackLocale: learningPath.defaultLocale,
              ),
              instructions: revision.instructions.resolve(
                normalizedScaffoldingLocale,
                fallbackLocale: learningPath.defaultLocale,
              ),
              contentSchemaVersion: learningPath.schemaVersion.value,
              contentDefaultLocale: learningPath.defaultLocale,
              execution: revision.execution,
              competencyIds: {
                for (final competencyId in revision.competencies)
                  competencyId.value,
              },
              state: projected.state,
              reason: projected.reason,
              syncState:
                  syncStates[activity.id.value] ?? ProgressSyncState.clean,
              practicePreference: element.practicePreference,
              prerequisites: _mapPrerequisite(
                element.prerequisites,
                pathElementIdsByActivityId,
              ),
              origin: activity.origin,
              visibility: revision.visibility,
              recommendationRank: projected.recommendationRank,
            ),
          );
        }

        stages.add(
          LearningMapStageViewModel(
            id: stage.id.value,
            title: stage.title.resolve(
              normalizedLocale,
              fallbackLocale: learningPath.defaultLocale,
            ),
            elements: elements,
          ),
        );
      }

      journeys.add(
        LearningMapJourneyViewModel(
          id: journey.id.value,
          title: journey.title.resolve(
            normalizedLocale,
            fallbackLocale: learningPath.defaultLocale,
          ),
          stages: stages,
        ),
      );
    }

    final unexpectedProjectionIds = projectionByElement.keys
        .where((id) => !consumedProjectionIds.contains(id))
        .toList(growable: false);

    if (unexpectedProjectionIds.isNotEmpty) {
      throw LearningMapAssemblyException(
        code: LearningMapAssemblyErrorCode.unexpectedProjectionEntry,
        reference: unexpectedProjectionIds.first,
        message:
            'A projeção contém elementos que não pertencem ao percurso ativo.',
      );
    }

    return LearningMapViewModel(
      learningPathId: learningPath.id.value,
      title: learningPath.title.resolve(
        normalizedLocale,
        fallbackLocale: learningPath.defaultLocale,
      ),
      locale: normalizedLocale,
      packageVersion: packageVersion,
      recoveredFromFallback: recoveredFromFallback,
      completedActivityCount: completedActivityCount,
      totalActivityCount: totalActivityCount,
      journeys: journeys,
    );
  }

  LearningMapPrerequisiteViewModel? _mapPrerequisite(
    PrerequisiteRule? rule,
    Map<String, List<String>> pathElementIdsByActivityId,
  ) {
    if (rule == null) {
      return null;
    }

    if (rule is ActivityCompletedRequirement) {
      final activityId = rule.activityId.value;
      final candidateElementIds =
          pathElementIdsByActivityId[activityId] ?? const <String>[];

      return LearningMapPrerequisiteViewModel.activityCompleted(
        activityId: activityId,
        sourcePathElementId: candidateElementIds.length == 1
            ? candidateElementIds.single
            : null,
      );
    }

    if (rule is CompetencyAchievedRequirement) {
      return LearningMapPrerequisiteViewModel.competencyAchieved(
        competencyId: rule.competencyId.value,
      );
    }

    if (rule is PrerequisiteGroup) {
      return LearningMapPrerequisiteViewModel.group(
        operator: rule.operator,
        rules: rule.rules.map(
          (child) => _mapPrerequisite(child, pathElementIdsByActivityId)!,
        ),
      );
    }

    throw StateError('Unsupported prerequisite rule: ${rule.runtimeType}.');
  }
}
