/// Descritor leve de uma etapa na ordem authored do catálogo.
///
/// Esta estrutura não transporta estado pedagógico. Serve apenas para
/// traduzir uma janela de etapas nos identificadores que o read side deve
/// consultar.
final class LearningMapStageDescriptor {
  LearningMapStageDescriptor({
    required String journeyId,
    required String stageId,
    required Iterable<String> pathElementIds,
    required Iterable<String> activityIds,
  }) : journeyId = _requiredId(journeyId, 'journeyId'),
       stageId = _requiredId(stageId, 'stageId'),
       pathElementIds = _normalizedRequiredIds(
         pathElementIds,
         'pathElementIds',
       ),
       activityIds = _normalizedIds(activityIds, 'activityIds');

  final String journeyId;
  final String stageId;

  /// Ordem authored dos elementos da etapa.
  final List<String> pathElementIds;

  /// Atividades referenciadas pela etapa.
  ///
  /// Uma mesma atividade pode surgir noutro elemento do percurso; a
  /// deduplicação global da janela é responsabilidade do planner.
  final List<String> activityIds;
}

/// Resultado puro da seleção de uma janela de etapas.
///
/// Não contém availability, recommendation, prerequisites ou qualquer outra
/// decisão pedagógica.
final class LearningMapStageWindow {
  LearningMapStageWindow._({
    required this.startStageIndex,
    required this.requestedStageCount,
    required this.totalStageCount,
    required Iterable<LearningMapStageDescriptor> stages,
    required Iterable<String> pathElementIds,
    required Iterable<String> activityIds,
  }) : stages = List<LearningMapStageDescriptor>.unmodifiable(stages),
       pathElementIds = List<String>.unmodifiable(pathElementIds),
       activityIds = List<String>.unmodifiable(activityIds);

  final int startStageIndex;
  final int requestedStageCount;
  final int totalStageCount;

  final List<LearningMapStageDescriptor> stages;
  final List<String> pathElementIds;
  final List<String> activityIds;

  int get loadedStageCount => stages.length;

  int get endStageIndexExclusive => startStageIndex + loadedStageCount;

  bool get hasPrevious => startStageIndex > 0;

  bool get hasNext => endStageIndexExclusive < totalStageCount;
}

/// Seleciona uma janela na ordem authored sem reavaliar pedagogia.
///
/// O planner:
/// - não conhece SQLite;
/// - não conhece Progression Engine;
/// - não altera availability;
/// - não escolhe recommendation;
/// - não ordena por IDs;
/// - preserva integralmente a ordem recebida.
final class LearningMapStageWindowPlanner {
  const LearningMapStageWindowPlanner();

  LearningMapStageWindow plan({
    required Iterable<LearningMapStageDescriptor> stages,
    required int startStageIndex,
    required int stageCount,
  }) {
    if (startStageIndex < 0) {
      throw RangeError.range(startStageIndex, 0, null, 'startStageIndex');
    }

    if (stageCount <= 0) {
      throw RangeError.range(stageCount, 1, null, 'stageCount');
    }

    final authoredStages = List<LearningMapStageDescriptor>.unmodifiable(
      stages,
    );

    if (authoredStages.isEmpty) {
      throw ArgumentError.value(stages, 'stages', 'nao pode estar vazio');
    }

    if (startStageIndex >= authoredStages.length) {
      throw RangeError.range(
        startStageIndex,
        0,
        authoredStages.length - 1,
        'startStageIndex',
      );
    }

    final requestedEnd = startStageIndex + stageCount;

    final end = requestedEnd < authoredStages.length
        ? requestedEnd
        : authoredStages.length;

    final selectedStages = authoredStages.sublist(startStageIndex, end);

    final pathElementIds = <String>[];
    final activityIds = <String>[];
    final seenActivityIds = <String>{};

    for (final stage in selectedStages) {
      pathElementIds.addAll(stage.pathElementIds);

      for (final activityId in stage.activityIds) {
        if (seenActivityIds.add(activityId)) {
          activityIds.add(activityId);
        }
      }
    }

    return LearningMapStageWindow._(
      startStageIndex: startStageIndex,
      requestedStageCount: stageCount,
      totalStageCount: authoredStages.length,
      stages: selectedStages,
      pathElementIds: pathElementIds,
      activityIds: activityIds,
    );
  }
}

String _requiredId(String value, String argumentName) {
  final normalized = value.trim();

  if (normalized.isEmpty) {
    throw ArgumentError.value(value, argumentName, 'nao pode estar vazio');
  }

  return normalized;
}

List<String> _normalizedRequiredIds(
  Iterable<String> values,
  String argumentName,
) {
  final normalized = _normalizedIds(values, argumentName);

  if (normalized.isEmpty) {
    throw ArgumentError.value(
      values,
      argumentName,
      'deve conter pelo menos um identificador',
    );
  }

  return normalized;
}

List<String> _normalizedIds(Iterable<String> values, String argumentName) {
  final result = <String>[];
  final seen = <String>{};

  for (final rawValue in values) {
    final value = rawValue.trim();

    if (value.isEmpty) {
      throw ArgumentError.value(
        rawValue,
        argumentName,
        'nao pode conter identificadores vazios',
      );
    }

    if (seen.add(value)) {
      result.add(value);
    }
  }

  return List<String>.unmodifiable(result);
}
