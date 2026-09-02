import 'dart:collection';

import 'domain_ids.dart';
import 'learning_enums.dart';
import 'learning_models.dart';
import 'prerequisite_rule.dart';

/// Pedido imutável enviado ao motor de progressão.
final class ProgressionRequest {
  ProgressionRequest({
    required this.learningPath,
    required this.facts,
    this.practicePreference = PracticePreference.balanced,
    Iterable<ActivityId> activitiesInProgress = const <ActivityId>[],
  }) : activitiesInProgress = UnmodifiableSetView(
         Set<ActivityId>.of(activitiesInProgress),
       );

  final LearningPath learningPath;
  final ProgressionFacts facts;
  final PracticePreference practicePreference;
  final Set<ActivityId> activitiesInProgress;
}

/// Razão estável e testável associada a uma decisão de progressão.
enum ProgressionReason { prerequisitesNotMet, ready, attemptStarted, completed }

final class PathElementDecision {
  const PathElementDecision({required this.state, required this.reason});

  final LearningActivityState state;
  final ProgressionReason reason;
}

/// Resultado imutável produzido pelo motor.
final class ProgressionResult {
  ProgressionResult({
    required Map<PathElementId, PathElementDecision> decisions,
    Iterable<PathElementId> recommendations = const <PathElementId>[],
  }) : decisions = UnmodifiableMapView(
         Map<PathElementId, PathElementDecision>.of(decisions),
       ),
       recommendations = List<PathElementId>.unmodifiable(recommendations);

  final Map<PathElementId, PathElementDecision> decisions;

  /// Ordem recomendada, sem alterar a disponibilidade dos outros caminhos.
  final List<PathElementId> recommendations;
}

/// Contrato do motor de progressão da Fase 1.
///
/// A implementação concreta será Dart puro e permanecerá separada de Flutter,
/// SQLite, rede, Controller e ChangeNotifier.
abstract interface class ProgressionEngine {
  ProgressionResult evaluate(ProgressionRequest request);
}
