import 'package:dailytalk_mobile/domain/learning/learning_domain.dart';
import 'package:flutter_test/flutter_test.dart';

/// Implementação mínima apenas para provar que o contrato pode ser utilizado
/// sem Flutter, SQLite, rede ou mecanismos de notificação da interface.
final class _ContractProbeEngine implements ProgressionEngine {
  @override
  ProgressionResult evaluate(ProgressionRequest request) {
    final decisions = <PathElementId, PathElementDecision>{};

    for (final journey in request.learningPath.journeys) {
      for (final stage in journey.stages) {
        for (final element in stage.elements) {
          final activityId = element.activityId;
          final isCompleted =
              activityId != null &&
              request.facts.completedActivities.contains(activityId);
          final isInProgress =
              activityId != null &&
              request.activitiesInProgress.contains(activityId);
          final isAvailable =
              element.prerequisites?.isSatisfiedBy(request.facts) ?? true;

          final decision = switch ((isCompleted, isInProgress, isAvailable)) {
            (true, _, _) => const PathElementDecision(
              state: LearningActivityState.completed,
              reason: ProgressionReason.completed,
            ),
            (false, true, _) => const PathElementDecision(
              state: LearningActivityState.inProgress,
              reason: ProgressionReason.attemptStarted,
            ),
            (false, false, true) => const PathElementDecision(
              state: LearningActivityState.available,
              reason: ProgressionReason.ready,
            ),
            _ => const PathElementDecision(
              state: LearningActivityState.locked,
              reason: ProgressionReason.prerequisitesNotMet,
            ),
          };

          decisions[element.id] = decision;
        }
      }
    }

    return ProgressionResult(decisions: decisions);
  }
}

void main() {
  test('contrato representa os quatro estados pedagógicos', () {
    final completedId = ActivityId('activity.completed');
    final activeId = ActivityId('activity.active');
    final availableId = ActivityId('activity.available');
    final lockedId = ActivityId('activity.locked');
    final prerequisiteId = ActivityId('activity.prerequisite');

    Activity activity(ActivityId id) {
      final revision = ActivityRevision(
        id: RevisionId('${id.value}.revision-01'),
        activityId: id,
        revisionNumber: 1,
        title: LocalizedText({'pt-PT': id.value}),
        instructions: LocalizedText({'pt-PT': 'Executar atividade.'}),
        visibility: ContentVisibility.public,
      );
      return Activity(
        id: id,
        type: LearningActivityType.quiz,
        origin: ContentOrigin.official,
        currentRevisionId: revision.id,
        revisions: [revision],
      );
    }

    PathElement element(ActivityId id, {PrerequisiteRule? prerequisite}) {
      return PathElement(
        id: PathElementId('${id.value}.element'),
        type: PathElementType.activity,
        activityId: id,
        prerequisites: prerequisite,
      );
    }

    final path = LearningPath(
      id: LearningPathId('phase1.contract-probe'),
      schemaVersion: SchemaVersion(1),
      defaultLocale: 'pt-PT',
      title: LocalizedText({'pt-PT': 'Contrato'}),
      journeys: [
        Journey(
          id: JourneyId('journey-01'),
          title: LocalizedText({'pt-PT': 'Jornada'}),
          stages: [
            Stage(
              id: StageId('stage-01'),
              title: LocalizedText({'pt-PT': 'Etapa'}),
              elements: [
                element(completedId),
                element(activeId),
                element(availableId),
                element(
                  lockedId,
                  prerequisite: ActivityCompletedRequirement(prerequisiteId),
                ),
              ],
            ),
          ],
        ),
      ],
      activities: [
        activity(completedId),
        activity(activeId),
        activity(availableId),
        activity(lockedId),
        activity(prerequisiteId),
      ],
      competencies: const [],
    );
    final result = _ContractProbeEngine().evaluate(
      ProgressionRequest(
        learningPath: path,
        facts: ProgressionFacts(completedActivities: [completedId]),
        activitiesInProgress: [activeId],
      ),
    );

    expect(
      result.decisions[PathElementId('activity.completed.element')]?.state,
      LearningActivityState.completed,
    );
    expect(
      result.decisions[PathElementId('activity.active.element')]?.state,
      LearningActivityState.inProgress,
    );
    expect(
      result.decisions[PathElementId('activity.available.element')]?.state,
      LearningActivityState.available,
    );
    expect(
      result.decisions[PathElementId('activity.locked.element')]?.state,
      LearningActivityState.locked,
    );
  });

  test('recomendações não alteram a disponibilidade de outros caminhos', () {
    final preferred = PathElementId('dialogue.element');
    final alternative = PathElementId('vocabulary.element');
    final result = ProgressionResult(
      decisions: {
        preferred: const PathElementDecision(
          state: LearningActivityState.available,
          reason: ProgressionReason.ready,
        ),
        alternative: const PathElementDecision(
          state: LearningActivityState.available,
          reason: ProgressionReason.ready,
        ),
      },
      recommendations: [preferred],
    );

    expect(result.recommendations, [preferred]);
    expect(
      result.decisions[alternative]?.state,
      LearningActivityState.available,
    );
  });
}
