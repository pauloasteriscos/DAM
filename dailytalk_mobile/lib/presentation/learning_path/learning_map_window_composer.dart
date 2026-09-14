import '../../data/repositories/learning_progress_read_repository.dart';
import '../../domain/learning/learning_models.dart';
import 'learning_map_assembler.dart';
import 'learning_map_stage_window.dart';
import 'learning_map_view_model.dart';
import 'learning_map_window_read_service.dart';

/// Resultado da composição visual de uma janela.
///
/// [model] contém apenas as journeys/stages carregadas na janela, mas as
/// métricas de progresso do topo continuam globais.
///
/// [globalRecommendations] permanece separado do modelo windowed para que uma
/// recomendação fora da viewport não seja transformada artificialmente numa
/// atividade local ou descartada.
final class LearningMapWindowComposition {
  LearningMapWindowComposition({
    required this.model,
    required this.window,
    required Iterable<LearningProgressProjectionEntry> globalRecommendations,
  }) : globalRecommendations =
           List<LearningProgressProjectionEntry>.unmodifiable(
             globalRecommendations,
           );

  final LearningMapViewModel model;
  final LearningMapStageWindow window;

  /// Ordenado por recommendationRank e, nos empates, pela ordem authored do
  /// percurso completo.
  final List<LearningProgressProjectionEntry> globalRecommendations;

  LearningProgressProjectionEntry? get primaryGlobalRecommendation =>
      globalRecommendations.isEmpty ? null : globalRecommendations.first;

  bool get primaryGlobalRecommendationIsLoaded {
    final primary = primaryGlobalRecommendation;

    if (primary == null) {
      return false;
    }

    return model.elements.any(
      (element) => element.pathElementId == primary.pathElementId,
    );
  }
}

/// Compõe um read model de janela sem enfraquecer o assembler existente.
///
/// O assembler continua a receber um LearningPath completo relativamente à
/// janela escolhida: todas as stages selecionadas e exatamente uma projeção
/// para cada PathElement desse subset.
///
/// Esta classe não lê SQLite, não contacta rede e não executa
/// ProgressionEngine.
final class LearningMapWindowComposer {
  const LearningMapWindowComposer({
    LearningMapAssembler assembler = const LearningMapAssembler(),
  }) : _assembler = assembler;

  final LearningMapAssembler _assembler;

  LearningMapWindowComposition compose({
    required LearningPath activePath,
    required LearningMapWindowReadSnapshot snapshot,
    required String locale,
  }) {
    final normalizedLocale = locale.trim();

    if (normalizedLocale.isEmpty) {
      throw ArgumentError.value(locale, 'locale', 'nao pode estar vazio');
    }

    if (activePath.id.value != snapshot.learningPathId) {
      throw StateError(
        'O LearningPath ativo nao corresponde '
        'ao snapshot windowed.',
      );
    }

    final authoredStages = _flattenStages(activePath);

    _validateGlobalCoverage(
      activePath: activePath,
      authoredStages: authoredStages,
      snapshot: snapshot,
    );

    final selectedRefs = _selectAndValidateWindowStages(
      authoredStages: authoredStages,
      window: snapshot.window,
    );

    final subsetPath = _buildSubsetPath(
      activePath: activePath,
      selectedRefs: selectedRefs,
    );

    final orderedRecommendations = _validateAndOrderRecommendations(
      activePath: activePath,
      snapshot: snapshot,
    );

    _validateWindowRecommendationConsistency(
      windowProjection: snapshot.windowProjection,
      globalRecommendations: orderedRecommendations,
    );

    // LearningMapAssembler permanece estrito:
    // - projection completa para o subset;
    // - nenhuma projection exterior ao subset;
    // - package/activity IDs coerentes.
    final localModel = _assembler.build(
      learningPath: subsetPath,
      packageVersion: snapshot.packageVersion,
      recoveredFromFallback: snapshot.recoveredFromFallback,
      locale: normalizedLocale,
      projection: snapshot.windowProjection,
      syncStates: snapshot.windowSyncStates,
    );

    final globalCounts = snapshot.globalCounts;

    if (globalCounts.totalActivityCount < localModel.totalActivityCount) {
      throw StateError(
        'O total global de atividades nao pode '
        'ser inferior ao total da janela.',
      );
    }

    if (globalCounts.completedActivityCount <
        localModel.completedActivityCount) {
      throw StateError(
        'O total global de atividades concluidas '
        'nao pode ser inferior ao total da janela.',
      );
    }

    // Substitui apenas as métricas de topo. A estrutura e os estados locais
    // continuam exatamente os produzidos pelo assembler para a janela.
    final model = LearningMapViewModel(
      learningPathId: localModel.learningPathId,
      title: localModel.title,
      locale: localModel.locale,
      packageVersion: localModel.packageVersion,
      recoveredFromFallback: localModel.recoveredFromFallback,
      completedActivityCount: globalCounts.completedActivityCount,
      totalActivityCount: globalCounts.totalActivityCount,
      journeys: localModel.journeys,
    );

    return LearningMapWindowComposition(
      model: model,
      window: snapshot.window,
      globalRecommendations: orderedRecommendations,
    );
  }

  List<_AuthoredStageRef> _flattenStages(LearningPath path) {
    final result = <_AuthoredStageRef>[];
    final seenElementIds = <String>{};

    for (final journey in path.journeys) {
      for (final stage in journey.stages) {
        for (final element in stage.elements) {
          if (!seenElementIds.add(element.id.value)) {
            throw StateError(
              'PathElementId duplicado no percurso ativo: '
              '${element.id.value}.',
            );
          }
        }

        result.add(_AuthoredStageRef(journey: journey, stage: stage));
      }
    }

    return List<_AuthoredStageRef>.unmodifiable(result);
  }

  void _validateGlobalCoverage({
    required LearningPath activePath,
    required List<_AuthoredStageRef> authoredStages,
    required LearningMapWindowReadSnapshot snapshot,
  }) {
    var expectedProjectionRows = 0;
    var expectedActivityElements = 0;

    for (final ref in authoredStages) {
      for (final element in ref.stage.elements) {
        expectedProjectionRows++;

        if (element.activityId != null) {
          expectedActivityElements++;
        }
      }
    }

    final counts = snapshot.globalCounts;

    if (counts.projectionRowCount != expectedProjectionRows) {
      throw StateError(
        'A projection global nao cobre exatamente '
        'o LearningPath ativo. '
        'expected=$expectedProjectionRows '
        'actual=${counts.projectionRowCount}.',
      );
    }

    if (counts.totalActivityCount != expectedActivityElements) {
      throw StateError(
        'A contagem global de activity elements '
        'nao corresponde ao LearningPath ativo. '
        'expected=$expectedActivityElements '
        'actual=${counts.totalActivityCount}.',
      );
    }

    if (counts.minPackageVersion != snapshot.packageVersion ||
        counts.maxPackageVersion != snapshot.packageVersion) {
      throw StateError(
        'As metricas globais nao correspondem '
        'ao packageVersion do snapshot.',
      );
    }

    if (activePath.id.value != snapshot.learningPathId) {
      throw StateError('LearningPath global inconsistente.');
    }
  }

  List<_AuthoredStageRef> _selectAndValidateWindowStages({
    required List<_AuthoredStageRef> authoredStages,
    required LearningMapStageWindow window,
  }) {
    if (window.totalStageCount != authoredStages.length) {
      throw StateError(
        'O StageWindow nao corresponde ao numero '
        'de stages do percurso ativo.',
      );
    }

    if (window.endStageIndexExclusive > authoredStages.length) {
      throw StateError('O StageWindow excede o percurso ativo.');
    }

    if (window.loadedStageCount != window.stages.length) {
      throw StateError('StageWindow internamente inconsistente.');
    }

    final selected = <_AuthoredStageRef>[];

    for (var offset = 0; offset < window.stages.length; offset++) {
      final authoredIndex = window.startStageIndex + offset;

      final ref = authoredStages[authoredIndex];

      final descriptor = window.stages[offset];

      if (descriptor.journeyId != ref.journey.id.value ||
          descriptor.stageId != ref.stage.id.value) {
        throw StateError(
          'O StageWindow nao preserva a ordem '
          'authored do percurso ativo.',
        );
      }

      final authoredElementIds = ref.stage.elements
          .map((element) => element.id.value)
          .toList(growable: false);

      if (!_sameStrings(descriptor.pathElementIds, authoredElementIds)) {
        throw StateError(
          'Os PathElementIds do StageWindow '
          'nao correspondem a stage oficial '
          '${ref.stage.id.value}.',
        );
      }

      final authoredActivityIds = _activityIdsForStage(ref.stage);

      if (!_sameStrings(descriptor.activityIds, authoredActivityIds)) {
        throw StateError(
          'Os ActivityIds do StageWindow '
          'nao correspondem a stage oficial '
          '${ref.stage.id.value}.',
        );
      }

      selected.add(ref);
    }

    return List<_AuthoredStageRef>.unmodifiable(selected);
  }

  LearningPath _buildSubsetPath({
    required LearningPath activePath,
    required List<_AuthoredStageRef> selectedRefs,
  }) {
    if (selectedRefs.isEmpty) {
      throw StateError('Nao e possivel compor uma janela sem stages.');
    }

    final journeyOrder = <Journey>[];
    final stagesByJourney = <String, List<Stage>>{};

    for (final ref in selectedRefs) {
      final journeyId = ref.journey.id.value;

      final stages = stagesByJourney.putIfAbsent(journeyId, () {
        journeyOrder.add(ref.journey);
        return <Stage>[];
      });

      stages.add(ref.stage);
    }

    final subsetJourneys = <Journey>[
      for (final journey in journeyOrder)
        Journey(
          id: journey.id,
          title: journey.title,
          stages: stagesByJourney[journey.id.value]!,
        ),
    ];

    return LearningPath(
      id: activePath.id,
      schemaVersion: activePath.schemaVersion,
      defaultLocale: activePath.defaultLocale,
      title: activePath.title,
      journeys: subsetJourneys,

      // Activities e competências são objetos oficiais imutáveis.
      // Mantê-los evita inventar um segundo mecanismo de closure para
      // revisions/competencies/prerequisites.
      activities: activePath.activities,
      competencies: activePath.competencies,
    );
  }

  List<LearningProgressProjectionEntry> _validateAndOrderRecommendations({
    required LearningPath activePath,
    required LearningMapWindowReadSnapshot snapshot,
  }) {
    final authoredOrder = <String, int>{};

    var index = 0;

    for (final journey in activePath.journeys) {
      for (final stage in journey.stages) {
        for (final element in stage.elements) {
          final id = element.id.value;

          if (authoredOrder.containsKey(id)) {
            throw StateError('PathElementId duplicado no percurso ativo: $id.');
          }

          authoredOrder[id] = index++;
        }
      }
    }

    final seen = <String>{};
    final result = <LearningProgressProjectionEntry>[];

    for (final entry in snapshot.globalRecommendations) {
      final rank = entry.recommendationRank;

      if (rank == null) {
        throw StateError('Recommendation global sem rank.');
      }

      if (entry.packageVersion != snapshot.packageVersion) {
        throw StateError(
          'Recommendation global pertence '
          'a outro packageVersion.',
        );
      }

      if (!authoredOrder.containsKey(entry.pathElementId)) {
        throw StateError(
          'Recommendation global referencia '
          'elemento fora do LearningPath ativo: '
          '${entry.pathElementId}.',
        );
      }

      if (!seen.add(entry.pathElementId)) {
        throw StateError(
          'Recommendation global duplicada: '
          '${entry.pathElementId}.',
        );
      }

      result.add(entry);
    }

    result.sort((left, right) {
      final rankComparison = left.recommendationRank!.compareTo(
        right.recommendationRank!,
      );

      if (rankComparison != 0) {
        return rankComparison;
      }

      return authoredOrder[left.pathElementId]!.compareTo(
        authoredOrder[right.pathElementId]!,
      );
    });

    return List<LearningProgressProjectionEntry>.unmodifiable(result);
  }

  void _validateWindowRecommendationConsistency({
    required Iterable<LearningProgressProjectionEntry> windowProjection,
    required Iterable<LearningProgressProjectionEntry> globalRecommendations,
  }) {
    final globalByElement = <String, LearningProgressProjectionEntry>{
      for (final entry in globalRecommendations) entry.pathElementId: entry,
    };

    for (final windowEntry in windowProjection) {
      final global = globalByElement[windowEntry.pathElementId];

      final windowRank = windowEntry.recommendationRank;

      if (windowRank == null) {
        if (global != null) {
          throw StateError(
            'Recommendation inconsistente entre '
            'a projection windowed e a global para '
            '${windowEntry.pathElementId}.',
          );
        }

        continue;
      }

      if (global == null) {
        throw StateError(
          'A projection windowed marca recommendation '
          'que nao existe na leitura global: '
          '${windowEntry.pathElementId}.',
        );
      }

      if (global.recommendationRank != windowRank ||
          global.activityId != windowEntry.activityId ||
          global.packageVersion != windowEntry.packageVersion ||
          global.state != windowEntry.state ||
          global.reason != windowEntry.reason) {
        throw StateError(
          'Recommendation global/windowed '
          'inconsistente para '
          '${windowEntry.pathElementId}.',
        );
      }
    }
  }

  List<String> _activityIdsForStage(Stage stage) {
    final result = <String>[];
    final seen = <String>{};

    for (final element in stage.elements) {
      final activityId = element.activityId?.value;

      if (activityId != null && seen.add(activityId)) {
        result.add(activityId);
      }
    }

    return result;
  }

  bool _sameStrings(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }

    return true;
  }
}

final class _AuthoredStageRef {
  const _AuthoredStageRef({required this.journey, required this.stage});

  final Journey journey;
  final Stage stage;
}
