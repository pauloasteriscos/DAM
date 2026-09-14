import '../../domain/learning/learning_enums.dart';
import '../../domain/learning/progression_engine.dart';

/// Read model completo utilizado pela apresentaÃƒÂ§ÃƒÂ£o do percurso.
///
/// NÃƒÂ£o contÃƒÂ©m SQLite, rede, ProgressionEngine nem dependÃƒÂªncias de Flutter.
/// Quando esta instÃƒÂ¢ncia chega ÃƒÂ  UI, todas as decisÃƒÂµes pedagÃƒÂ³gicas relevantes
/// jÃƒÂ¡ foram tomadas pelas camadas anteriores.
final class LearningMapViewModel {
  LearningMapViewModel({
    required this.learningPathId,
    required this.title,
    required this.locale,
    required this.packageVersion,
    required this.recoveredFromFallback,
    required this.completedActivityCount,
    required this.totalActivityCount,
    required Iterable<LearningMapJourneyViewModel> journeys,
  }) : journeys = List<LearningMapJourneyViewModel>.unmodifiable(journeys);

  final String learningPathId;
  final String title;
  final String locale;
  final int packageVersion;
  final bool recoveredFromFallback;

  /// Contagem relativa apenas ÃƒÂ s atividades existentes na projeÃƒÂ§ÃƒÂ£o ativa.
  final int completedActivityCount;
  final int totalActivityCount;

  final List<LearningMapJourneyViewModel> journeys;

  double get completionRatio {
    if (totalActivityCount == 0) {
      return 0;
    }

    return completedActivityCount / totalActivityCount;
  }

  Iterable<LearningMapElementViewModel> get elements sync* {
    for (final journey in journeys) {
      for (final stage in journey.stages) {
        yield* stage.elements;
      }
    }
  }

  /// Primeiro elemento da ordem recomendada pelo ProgressionEngine.
  ///
  /// recommendationRank == null significa que o elemento nÃƒÂ£o faz parte
  /// da lista de recomendaÃƒÂ§ÃƒÂµes atual.
  LearningMapElementViewModel? get nextRecommendedElement {
    LearningMapElementViewModel? selected;

    for (final element in elements) {
      final rank = element.recommendationRank;

      if (rank == null) {
        continue;
      }

      final selectedRank = selected?.recommendationRank;

      if (selected == null || selectedRank == null || rank < selectedRank) {
        selected = element;
      }
    }

    return selected;
  }
}

final class LearningMapJourneyViewModel {
  LearningMapJourneyViewModel({
    required this.id,
    required this.title,
    required Iterable<LearningMapStageViewModel> stages,
  }) : stages = List<LearningMapStageViewModel>.unmodifiable(stages);

  final String id;
  final String title;
  final List<LearningMapStageViewModel> stages;
}

final class LearningMapStageViewModel {
  LearningMapStageViewModel({
    required this.id,
    required this.title,
    required Iterable<LearningMapElementViewModel> elements,
  }) : elements = List<LearningMapElementViewModel>.unmodifiable(elements);

  final String id;
  final String title;
  final List<LearningMapElementViewModel> elements;

  int get activityCount =>
      elements.where((element) => element.activityId != null).length;

  int get completedActivityCount => elements
      .where(
        (element) =>
            element.activityId != null &&
            element.state == LearningActivityState.completed,
      )
      .length;

  double get completionRatio {
    if (activityCount == 0) {
      return 0;
    }

    return completedActivityCount / activityCount;
  }
}

/// Elemento jÃƒÂ¡ preparado para apresentaÃƒÂ§ÃƒÂ£o.
///
/// Atividades possuem metadados da sua revisÃƒÂ£o atual. Elementos estruturais
/// como checkpoint, scene e reward podem nÃƒÂ£o possuir activityId.
enum LearningMapPrerequisiteType {
  activityCompleted,
  competencyAchieved,
  group,
}

/// Presentation-safe representation of authored prerequisite topology.
///
/// This model preserves the source rule tree. It does not evaluate
/// prerequisites and does not make pedagogical decisions.
final class LearningMapPrerequisiteViewModel {
  factory LearningMapPrerequisiteViewModel.activityCompleted({
    required String activityId,
    String? sourcePathElementId,
  }) {
    return LearningMapPrerequisiteViewModel._(
      type: LearningMapPrerequisiteType.activityCompleted,
      activityId: activityId,
      sourcePathElementId: sourcePathElementId,
      rules: const <LearningMapPrerequisiteViewModel>[],
    );
  }

  factory LearningMapPrerequisiteViewModel.competencyAchieved({
    required String competencyId,
  }) {
    return LearningMapPrerequisiteViewModel._(
      type: LearningMapPrerequisiteType.competencyAchieved,
      competencyId: competencyId,
      rules: const <LearningMapPrerequisiteViewModel>[],
    );
  }

  factory LearningMapPrerequisiteViewModel.group({
    required PrerequisiteOperator operator,
    required Iterable<LearningMapPrerequisiteViewModel> rules,
  }) {
    final normalizedRules = List<LearningMapPrerequisiteViewModel>.unmodifiable(
      rules,
    );

    if (normalizedRules.isEmpty) {
      throw ArgumentError.value(
        rules,
        'rules',
        'a prerequisite group must contain at least one rule',
      );
    }

    return LearningMapPrerequisiteViewModel._(
      type: LearningMapPrerequisiteType.group,
      operator: operator,
      rules: normalizedRules,
    );
  }

  const LearningMapPrerequisiteViewModel._({
    required this.type,
    this.activityId,
    this.sourcePathElementId,
    this.competencyId,
    this.operator,
    required this.rules,
  });
  final LearningMapPrerequisiteType type;

  /// Stable domain reference authored by the content package.
  final String? activityId;

  /// Presentation locator when the activity maps unambiguously to one
  /// PathElement in the active LearningPath.
  ///
  /// Null deliberately means "do not invent an edge".
  final String? sourcePathElementId;

  /// Stable competency reference. A competency is never converted into
  /// an artificial PathElement edge.
  final String? competencyId;

  final PrerequisiteOperator? operator;

  /// Authored child order for ALL / ANY groups.
  final List<LearningMapPrerequisiteViewModel> rules;

  Iterable<String> get activitySourcePathElementIds sync* {
    final source = sourcePathElementId;

    if (source != null) {
      yield source;
    }

    for (final rule in rules) {
      yield* rule.activitySourcePathElementIds;
    }
  }

  Iterable<String> get requiredCompetencyIds sync* {
    final competency = competencyId;

    if (competency != null) {
      yield competency;
    }

    for (final rule in rules) {
      yield* rule.requiredCompetencyIds;
    }
  }
}

final class LearningMapElementViewModel {
  LearningMapElementViewModel({
    required this.pathElementId,
    required this.elementType,
    this.title,
    required this.state,
    required this.reason,
    required this.syncState,
    required this.practicePreference,
    required Iterable<String> competencyIds,
    this.activityId,
    this.revisionId,
    this.activityType,
    this.instructions,
    this.origin,
    this.visibility,
    this.recommendationRank,
    this.prerequisites,
  }) : competencyIds = Set<String>.unmodifiable(competencyIds);

  final String pathElementId;
  final PathElementType elementType;

  final String? activityId;
  final String? revisionId;
  final LearningActivityType? activityType;

  final String? title;
  final String? instructions;

  final Set<String> competencyIds;

  final LearningActivityState state;
  final ProgressionReason reason;

  /// Sempre independente de [state].
  final ProgressSyncState syncState;

  final PracticePreference practicePreference;
  final ContentOrigin? origin;
  final ContentVisibility? visibility;

  final int? recommendationRank;

  /// Authored prerequisite tree copied from the active content package.
  ///
  /// Null means this element has no authored prerequisites.
  final LearningMapPrerequisiteViewModel? prerequisites;

  bool get hasPrerequisites => prerequisites != null;

  Iterable<String> get authoredPredecessorPathElementIds sync* {
    final rule = prerequisites;

    if (rule == null) {
      return;
    }

    yield* rule.activitySourcePathElementIds;
  }

  Iterable<String> get requiredCompetencyIds sync* {
    final rule = prerequisites;

    if (rule == null) {
      return;
    }

    yield* rule.requiredCompetencyIds;
  }

  bool get isActivity => activityId != null;

  bool get isRecommended => recommendationRank != null;

  bool get isPrimaryRecommendation => recommendationRank == 0;

  bool get isLocked => state == LearningActivityState.locked;

  bool get canOpen => !isLocked;
}
