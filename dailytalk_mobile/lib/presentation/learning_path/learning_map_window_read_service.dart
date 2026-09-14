import '../../data/content/learning_content_catalog.dart';
import '../../data/repositories/learning_progress_read_repository.dart';
import '../../domain/learning/learning_enums.dart';
import 'learning_map_stage_window.dart';

typedef LearningMapWindowCatalogLoader =
    Future<LearningMapWindowCatalogSnapshot> Function(String learningPathId);

typedef LearningMapWindowProjectionLoader =
    Future<List<LearningProgressProjectionEntry>> Function({
      required String accountId,
      required String learningPathId,
      required Iterable<String> pathElementIds,
    });

typedef LearningMapWindowSyncLoader =
    Future<Map<String, ProgressSyncState>> Function({
      required String accountId,
      required String learningPathId,
      required Iterable<String> activityIds,
    });

typedef LearningMapWindowRecommendationLoader =
    Future<List<LearningProgressProjectionEntry>> Function({
      required String accountId,
      required String learningPathId,
    });

typedef LearningMapWindowCountsLoader =
    Future<LearningProgressProjectionCounts> Function({
      required String accountId,
      required String learningPathId,
    });

/// Índice leve do catálogo necessário para planear janelas.
///
/// Não contém projeção pedagógica e não toma decisões de progressão.
final class LearningMapWindowCatalogSnapshot {
  LearningMapWindowCatalogSnapshot({
    required String learningPathId,
    required this.packageVersion,
    required this.recoveredFromFallback,
    required Iterable<LearningMapStageDescriptor> stages,
  }) : learningPathId = _requiredId(learningPathId, 'learningPathId'),
       stages = List<LearningMapStageDescriptor>.unmodifiable(stages) {
    if (packageVersion <= 0) {
      throw ArgumentError.value(packageVersion, 'packageVersion');
    }

    if (this.stages.isEmpty) {
      throw ArgumentError.value(stages, 'stages', 'nao pode estar vazio');
    }
  }

  final String learningPathId;
  final int packageVersion;
  final bool recoveredFromFallback;
  final List<LearningMapStageDescriptor> stages;
}

/// Snapshot local necessário para a futura composição windowed.
///
/// A recomendação global permanece separada da janela. Este objeto não
/// transforma recommendation em availability e não escolhe next mission.
final class LearningMapWindowReadSnapshot {
  LearningMapWindowReadSnapshot({
    required this.learningPathId,
    required this.packageVersion,
    required this.recoveredFromFallback,
    required this.window,
    required Iterable<LearningProgressProjectionEntry> windowProjection,
    required Map<String, ProgressSyncState> windowSyncStates,
    required Iterable<LearningProgressProjectionEntry> globalRecommendations,
    required this.globalCounts,
  }) : windowProjection = List<LearningProgressProjectionEntry>.unmodifiable(
         windowProjection,
       ),
       windowSyncStates = Map<String, ProgressSyncState>.unmodifiable(
         windowSyncStates,
       ),
       globalRecommendations =
           List<LearningProgressProjectionEntry>.unmodifiable(
             globalRecommendations,
           );

  final String learningPathId;
  final int packageVersion;
  final bool recoveredFromFallback;

  final LearningMapStageWindow window;

  final List<LearningProgressProjectionEntry> windowProjection;

  final Map<String, ProgressSyncState> windowSyncStates;

  final List<LearningProgressProjectionEntry> globalRecommendations;

  final LearningProgressProjectionCounts globalCounts;
}

/// Read boundary windowed e exclusivamente local.
///
/// Responsabilidades:
/// - carregar o índice authored do catálogo;
/// - planear a janela de etapas;
/// - ler apenas projeção e sync da janela;
/// - transportar recommendation e contagens globais separadamente.
///
/// Não monta ViewModel, não executa regras pedagógicas e não contacta rede.
final class LearningMapWindowReadService {
  const LearningMapWindowReadService({
    required LearningMapWindowCatalogLoader loadCatalog,
    required LearningMapWindowProjectionLoader loadWindowProjection,
    required LearningMapWindowSyncLoader loadWindowSync,
    required LearningMapWindowRecommendationLoader loadGlobalRecommendations,
    required LearningMapWindowCountsLoader loadGlobalCounts,
    LearningMapStageWindowPlanner planner =
        const LearningMapStageWindowPlanner(),
  }) : _loadCatalog = loadCatalog,
       _loadWindowProjection = loadWindowProjection,
       _loadWindowSync = loadWindowSync,
       _loadGlobalRecommendations = loadGlobalRecommendations,
       _loadGlobalCounts = loadGlobalCounts,
       _planner = planner;

  factory LearningMapWindowReadService.fromRepositories({
    required LearningContentCatalogService catalogService,
    required LearningProgressReadRepository progressRepository,
    LearningMapStageWindowPlanner planner =
        const LearningMapStageWindowPlanner(),
  }) {
    return LearningMapWindowReadService(
      loadCatalog: (learningPathId) async {
        final active = await catalogService.loadActive(learningPathId);

        final descriptors = <LearningMapStageDescriptor>[];

        for (final journey in active.path.journeys) {
          for (final stage in journey.stages) {
            descriptors.add(
              LearningMapStageDescriptor(
                journeyId: journey.id.value,
                stageId: stage.id.value,
                pathElementIds: stage.elements.map(
                  (element) => element.id.value,
                ),
                activityIds: stage.elements
                    .map((element) => element.activityId?.value)
                    .whereType<String>(),
              ),
            );
          }
        }

        return LearningMapWindowCatalogSnapshot(
          learningPathId: active.path.id.value,
          packageVersion: active.package.packageVersion,
          recoveredFromFallback: active.recoveredFromFallback,
          stages: descriptors,
        );
      },
      loadWindowProjection: progressRepository.readProjectionForPathElements,
      loadWindowSync: progressRepository.readActivitySyncStatesForActivities,
      loadGlobalRecommendations: progressRepository.readRecommendedProjection,
      loadGlobalCounts: progressRepository.readProjectionCounts,
      planner: planner,
    );
  }

  final LearningMapWindowCatalogLoader _loadCatalog;
  final LearningMapWindowProjectionLoader _loadWindowProjection;
  final LearningMapWindowSyncLoader _loadWindowSync;
  final LearningMapWindowRecommendationLoader _loadGlobalRecommendations;
  final LearningMapWindowCountsLoader _loadGlobalCounts;
  final LearningMapStageWindowPlanner _planner;

  Future<LearningMapWindowReadSnapshot> load({
    required String accountId,
    required String learningPathId,
    required int startStageIndex,
    required int stageCount,
  }) async {
    final normalizedAccountId = _requiredId(accountId, 'accountId');

    final normalizedPathId = _requiredId(learningPathId, 'learningPathId');

    final catalog = await _loadCatalog(normalizedPathId);

    if (catalog.learningPathId != normalizedPathId) {
      throw StateError(
        'O catalogo devolveu ${catalog.learningPathId} '
        'quando foi solicitado $normalizedPathId.',
      );
    }

    final window = _planner.plan(
      stages: catalog.stages,
      startStageIndex: startStageIndex,
      stageCount: stageCount,
    );

    // Todas as leituras abaixo são independentes e locais.
    final projectionFuture = _loadWindowProjection(
      accountId: normalizedAccountId,
      learningPathId: normalizedPathId,
      pathElementIds: window.pathElementIds,
    );

    final syncFuture = _loadWindowSync(
      accountId: normalizedAccountId,
      learningPathId: normalizedPathId,
      activityIds: window.activityIds,
    );

    final recommendationsFuture = _loadGlobalRecommendations(
      accountId: normalizedAccountId,
      learningPathId: normalizedPathId,
    );

    final countsFuture = _loadGlobalCounts(
      accountId: normalizedAccountId,
      learningPathId: normalizedPathId,
    );

    final projection = await projectionFuture;
    final syncStates = await syncFuture;
    final recommendations = await recommendationsFuture;
    final counts = await countsFuture;

    _validateWindowProjection(
      projection: projection,
      expectedPathElementIds: window.pathElementIds,
      packageVersion: catalog.packageVersion,
    );

    _validateWindowSync(
      syncStates: syncStates,
      expectedActivityIds: window.activityIds,
    );

    _validateGlobalRecommendations(
      recommendations: recommendations,
      catalogStages: catalog.stages,
      packageVersion: catalog.packageVersion,
    );

    _validateGlobalCounts(
      counts: counts,
      packageVersion: catalog.packageVersion,
    );

    return LearningMapWindowReadSnapshot(
      learningPathId: normalizedPathId,
      packageVersion: catalog.packageVersion,
      recoveredFromFallback: catalog.recoveredFromFallback,
      window: window,
      windowProjection: projection,
      windowSyncStates: syncStates,
      globalRecommendations: recommendations,
      globalCounts: counts,
    );
  }

  void _validateWindowProjection({
    required Iterable<LearningProgressProjectionEntry> projection,
    required Iterable<String> expectedPathElementIds,
    required int packageVersion,
  }) {
    final expected = expectedPathElementIds.toSet();

    final seen = <String>{};

    for (final entry in projection) {
      if (entry.packageVersion != packageVersion) {
        throw StateError(
          'A projecao windowed nao corresponde '
          'ao packageVersion ativo.',
        );
      }

      if (!expected.contains(entry.pathElementId)) {
        throw StateError(
          'A projecao windowed devolveu elemento '
          'fora da janela: ${entry.pathElementId}.',
        );
      }

      if (!seen.add(entry.pathElementId)) {
        throw StateError(
          'A projecao windowed contem elemento '
          'duplicado: ${entry.pathElementId}.',
        );
      }
    }

    if (seen.length != expected.length) {
      final missing = expected.difference(seen);

      throw StateError(
        'A projecao windowed esta incompleta: '
        '${missing.join(', ')}.',
      );
    }
  }

  void _validateWindowSync({
    required Map<String, ProgressSyncState> syncStates,
    required Iterable<String> expectedActivityIds,
  }) {
    final expected = expectedActivityIds.toSet();

    final unexpected = syncStates.keys
        .where((activityId) => !expected.contains(activityId))
        .toList(growable: false);

    if (unexpected.isNotEmpty) {
      throw StateError(
        'O sync windowed devolveu atividade '
        'fora da janela: ${unexpected.first}.',
      );
    }
  }

  void _validateGlobalRecommendations({
    required Iterable<LearningProgressProjectionEntry> recommendations,
    required Iterable<LearningMapStageDescriptor> catalogStages,
    required int packageVersion,
  }) {
    final validElementIds = <String>{
      for (final stage in catalogStages) ...stage.pathElementIds,
    };

    final seen = <String>{};

    for (final entry in recommendations) {
      if (entry.recommendationRank == null) {
        throw StateError(
          'A leitura global de recommendation '
          'devolveu rank nulo.',
        );
      }

      if (entry.packageVersion != packageVersion) {
        throw StateError(
          'A recommendation global nao corresponde '
          'ao packageVersion ativo.',
        );
      }

      if (!validElementIds.contains(entry.pathElementId)) {
        throw StateError(
          'A recommendation global referencia elemento '
          'fora do catalogo ativo: '
          '${entry.pathElementId}.',
        );
      }

      if (!seen.add(entry.pathElementId)) {
        throw StateError(
          'A recommendation global contem elemento '
          'duplicado: ${entry.pathElementId}.',
        );
      }
    }
  }

  void _validateGlobalCounts({
    required LearningProgressProjectionCounts counts,
    required int packageVersion,
  }) {
    if (counts.projectionRowCount == 0) {
      throw StateError('A projecao global esta ausente.');
    }

    if (counts.minPackageVersion != packageVersion ||
        counts.maxPackageVersion != packageVersion) {
      throw StateError(
        'As contagens globais nao correspondem '
        'ao packageVersion ativo.',
      );
    }
  }
}

String _requiredId(String value, String argumentName) {
  final normalized = value.trim();

  if (normalized.isEmpty) {
    throw ArgumentError.value(value, argumentName, 'nao pode estar vazio');
  }

  return normalized;
}
