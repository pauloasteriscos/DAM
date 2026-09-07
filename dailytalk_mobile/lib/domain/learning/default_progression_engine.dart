import 'domain_ids.dart';
import 'learning_enums.dart';
import 'learning_models.dart';
import 'progression_engine.dart';

/// Implementação determinística e local do motor de progressão.
///
/// Conclusões e tentativas em curso têm precedência sobre pré-requisitos.
/// Preferências afetam apenas a ordem das recomendações, nunca a
/// disponibilidade curricular.
final class DefaultProgressionEngine implements ProgressionEngine {
  const DefaultProgressionEngine();

  @override
  ProgressionResult evaluate(ProgressionRequest request) {
    final decisions = <PathElementId, PathElementDecision>{};
    final candidates = <PathElement>[];

    for (final journey in request.learningPath.journeys) {
      for (final stage in journey.stages) {
        for (final element in stage.elements) {
          if (decisions.containsKey(element.id)) {
            throw ArgumentError('PathElementId duplicado: ${element.id}.');
          }

          final decision = _decisionFor(element, request);
          decisions[element.id] = decision;

          if (element.activityId != null &&
              (decision.state == LearningActivityState.inProgress ||
                  decision.state == LearningActivityState.available)) {
            candidates.add(element);
          }
        }
      }
    }

    final inProgress = <PathElementId>[];
    final preferred = <PathElementId>[];
    final remaining = <PathElementId>[];
    for (final element in candidates) {
      if (decisions[element.id]?.state == LearningActivityState.inProgress) {
        inProgress.add(element.id);
      } else if (request.practicePreference != PracticePreference.balanced &&
          element.practicePreference == request.practicePreference) {
        preferred.add(element.id);
      } else {
        remaining.add(element.id);
      }
    }

    return ProgressionResult(
      decisions: decisions,
      recommendations: [...inProgress, ...preferred, ...remaining],
    );
  }

  PathElementDecision _decisionFor(
    PathElement element,
    ProgressionRequest request,
  ) {
    final activityId = element.activityId;

    if (activityId != null &&
        request.facts.completedActivities.contains(activityId)) {
      return const PathElementDecision(
        state: LearningActivityState.completed,
        reason: ProgressionReason.completed,
      );
    }

    if (activityId != null &&
        request.activitiesInProgress.contains(activityId)) {
      return const PathElementDecision(
        state: LearningActivityState.inProgress,
        reason: ProgressionReason.attemptStarted,
      );
    }

    final prerequisitesMet =
        element.prerequisites?.isSatisfiedBy(request.facts) ?? true;
    if (prerequisitesMet) {
      return const PathElementDecision(
        state: LearningActivityState.available,
        reason: ProgressionReason.ready,
      );
    }

    return const PathElementDecision(
      state: LearningActivityState.locked,
      reason: ProgressionReason.prerequisitesNotMet,
    );
  }
}
