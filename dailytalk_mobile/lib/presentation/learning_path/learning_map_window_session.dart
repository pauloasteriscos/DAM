import '../../data/content/learning_content_catalog.dart';
import '../../data/repositories/learning_progress_read_repository.dart';
import '../../domain/learning/learning_models.dart';
import 'learning_map_read_service.dart';
import 'learning_map_stage_window.dart';
import 'learning_map_window_composer.dart';
import 'learning_map_window_read_service.dart';

typedef LearningMapWindowActiveContentLoader =
    Future<LearningMapActiveContentSnapshot> Function(String learningPathId);

/// Pedido puro de um segmento de stages.
///
/// A unidade de paginação é Stage porque Stage já é uma fronteira semântica
/// authored do domínio. Não introduzimos OFFSET/LIMIT pedagógico por elemento.
final class LearningMapStageWindowRequest {
  const LearningMapStageWindowRequest({
    required this.startStageIndex,
    required this.stageCount,
  }) : assert(startStageIndex >= 0),
       assert(stageCount > 0);

  final int startStageIndex;
  final int stageCount;
}

/// Política bounded de segmentação.
///
/// Não cresce a janela atual indefinidamente. Cada navegação produz outro
/// segmento limitado, mantendo custo de projection/sync proporcional ao
/// número de stages atualmente pedido.
final class LearningMapStageWindowPolicy {
  const LearningMapStageWindowPolicy({
    this.initialStageCount = 4,
    this.segmentStageCount = 4,
  }) : assert(initialStageCount > 0),
       assert(segmentStageCount > 0);

  final int initialStageCount;
  final int segmentStageCount;

  LearningMapStageWindowRequest initial() {
    return LearningMapStageWindowRequest(
      startStageIndex: 0,
      stageCount: initialStageCount,
    );
  }

  LearningMapStageWindowRequest? next(LearningMapStageWindow current) {
    if (!current.hasNext) {
      return null;
    }

    return LearningMapStageWindowRequest(
      startStageIndex: current.endStageIndexExclusive,
      stageCount: segmentStageCount,
    );
  }

  LearningMapStageWindowRequest? previous(LearningMapStageWindow current) {
    if (!current.hasPrevious) {
      return null;
    }

    final candidateStart = current.startStageIndex - segmentStageCount;

    final previousStart = candidateStart < 0 ? 0 : candidateStart;

    final previousCount = current.startStageIndex - previousStart;

    return LearningMapStageWindowRequest(
      startStageIndex: previousStart,
      stageCount: previousCount,
    );
  }

  /// Resolves the bounded segment that owns one authored stage index.
  LearningMapStageWindowRequest containingStageIndex({
    required int stageIndex,
    required int totalStageCount,
  }) {
    if (totalStageCount <= 0) {
      throw ArgumentError.value(totalStageCount, 'totalStageCount');
    }

    if (stageIndex < 0 || stageIndex >= totalStageCount) {
      throw RangeError.range(stageIndex, 0, totalStageCount - 1, 'stageIndex');
    }

    if (stageIndex < initialStageCount) {
      return initial();
    }

    final relativeIndex = stageIndex - initialStageCount;

    final segmentNumber = relativeIndex ~/ segmentStageCount;

    return LearningMapStageWindowRequest(
      startStageIndex: initialStageCount + (segmentNumber * segmentStageCount),
      stageCount: segmentStageCount,
    );
  }
}

/// Abre uma sessão de percurso.
///
/// O catálogo ativo é resolvido uma única vez em [open]. A sessão resultante
/// reutiliza esse snapshot authored para todas as mudanças de segmento.
///
/// Projection, sync, recommendation e aggregates continuam a ser relidos do
/// armazenamento local em cada load para refletir progresso recente.
final class LearningMapWindowCoordinator {
  const LearningMapWindowCoordinator({
    required LearningMapWindowActiveContentLoader loadActiveContent,
    required LearningMapWindowProjectionLoader loadWindowProjection,
    required LearningMapWindowSyncLoader loadWindowSync,
    required LearningMapWindowRecommendationLoader loadGlobalRecommendations,
    required LearningMapWindowCountsLoader loadGlobalCounts,
    LearningMapWindowComposer composer = const LearningMapWindowComposer(),
    LearningMapStageWindowPolicy policy = const LearningMapStageWindowPolicy(),
  }) : _loadActiveContent = loadActiveContent,
       _loadWindowProjection = loadWindowProjection,
       _loadWindowSync = loadWindowSync,
       _loadGlobalRecommendations = loadGlobalRecommendations,
       _loadGlobalCounts = loadGlobalCounts,
       _composer = composer,
       _policy = policy;

  factory LearningMapWindowCoordinator.fromRepositories({
    required LearningContentCatalogService catalogService,
    required LearningProgressReadRepository progressRepository,
    LearningMapWindowComposer composer = const LearningMapWindowComposer(),
    LearningMapStageWindowPolicy policy = const LearningMapStageWindowPolicy(),
  }) {
    return LearningMapWindowCoordinator(
      loadActiveContent: (learningPathId) async {
        final active = await catalogService.loadActive(learningPathId);

        return LearningMapActiveContentSnapshot(
          path: active.path,
          packageVersion: active.package.packageVersion,
          recoveredFromFallback: active.recoveredFromFallback,
        );
      },
      loadWindowProjection: progressRepository.readProjectionForPathElements,
      loadWindowSync: progressRepository.readActivitySyncStatesForActivities,
      loadGlobalRecommendations: progressRepository.readRecommendedProjection,
      loadGlobalCounts: progressRepository.readProjectionCounts,
      composer: composer,
      policy: policy,
    );
  }

  final LearningMapWindowActiveContentLoader _loadActiveContent;

  final LearningMapWindowProjectionLoader _loadWindowProjection;

  final LearningMapWindowSyncLoader _loadWindowSync;

  final LearningMapWindowRecommendationLoader _loadGlobalRecommendations;

  final LearningMapWindowCountsLoader _loadGlobalCounts;

  final LearningMapWindowComposer _composer;
  final LearningMapStageWindowPolicy _policy;

  Future<LearningMapWindowSession> open({
    required String accountId,
    required String learningPathId,
    required String locale,
    String? scaffoldingLocale,
  }) async {
    final normalizedAccountId = _requiredValue(accountId, 'accountId');

    final normalizedPathId = _requiredValue(learningPathId, 'learningPathId');

    final normalizedLocale = _requiredValue(locale, 'locale');
    final normalizedScaffoldingLocale = _requiredValue(
      scaffoldingLocale ?? locale,
      'scaffoldingLocale',
    );

    // ÚNICA leitura externa do catálogo desta sessão.
    final active = await _loadActiveContent(normalizedPathId);

    if (active.path.id.value != normalizedPathId) {
      throw StateError(
        'O catalogo ativo devolveu '
        '${active.path.id.value} quando foi '
        'solicitado $normalizedPathId.',
      );
    }

    final descriptors = _stageDescriptors(active.path);

    final stageIndexByPathElementId = <String, int>{};

    for (var stageIndex = 0; stageIndex < descriptors.length; stageIndex++) {
      for (final pathElementId in descriptors[stageIndex].pathElementIds) {
        final previous = stageIndexByPathElementId[pathElementId];

        if (previous != null) {
          throw StateError(
            'Duplicate PathElementId in authored index: '
            '$pathElementId.',
          );
        }

        stageIndexByPathElementId[pathElementId] = stageIndex;
      }
    }
    final catalogSnapshot = LearningMapWindowCatalogSnapshot(
      learningPathId: active.path.id.value,
      packageVersion: active.packageVersion,
      recoveredFromFallback: active.recoveredFromFallback,
      stages: descriptors,
    );

    // WindowReadService continua intacto. A sua fronteira de catálogo passa
    // a apontar para o snapshot imutável já resolvido acima.
    final readService = LearningMapWindowReadService(
      loadCatalog: (requestedPathId) async {
        final normalizedRequested = _requiredValue(
          requestedPathId,
          'learningPathId',
        );

        if (normalizedRequested != normalizedPathId) {
          throw StateError(
            'A sessao nao pode trocar de '
            'LearningPath.',
          );
        }

        return catalogSnapshot;
      },
      loadWindowProjection: _loadWindowProjection,
      loadWindowSync: _loadWindowSync,
      loadGlobalRecommendations: _loadGlobalRecommendations,
      loadGlobalCounts: _loadGlobalCounts,
    );

    return LearningMapWindowSession._(
      accountId: normalizedAccountId,
      learningPathId: normalizedPathId,
      locale: normalizedLocale,
      scaffoldingLocale: normalizedScaffoldingLocale,
      activePath: active.path,
      totalStageCount: descriptors.length,
      stageIndexByPathElementId: stageIndexByPathElementId,
      readService: readService,
      composer: _composer,
      policy: _policy,
    );
  }
}

/// Sessão authored estável de um percurso.
///
/// Pode trocar de segmento sem reler/reparsear o catálogo. Os factos locais
/// continuam frescos porque WindowReadService é chamado em cada mudança.
final class LearningMapWindowSession {
  LearningMapWindowSession._({
    required this.accountId,
    required this.learningPathId,
    required this.locale,
    required this.scaffoldingLocale,
    required LearningPath activePath,
    required this.totalStageCount,
    required Map<String, int> stageIndexByPathElementId,
    required LearningMapWindowReadService readService,
    required LearningMapWindowComposer composer,
    required LearningMapStageWindowPolicy policy,
  }) : _activePath = activePath,
       _stageIndexByPathElementId = Map<String, int>.unmodifiable(
         stageIndexByPathElementId,
       ),
       _readService = readService,
       _composer = composer,
       _policy = policy;

  final String accountId;
  final String learningPathId;
  final String locale;
  final String scaffoldingLocale;
  final int totalStageCount;

  final LearningPath _activePath;

  final Map<String, int> _stageIndexByPathElementId;
  final LearningMapWindowReadService _readService;
  final LearningMapWindowComposer _composer;
  final LearningMapStageWindowPolicy _policy;

  LearningMapStageWindowPolicy get policy => _policy;

  /// Resolves the bounded segment containing one authored PathElement.
  LearningMapStageWindowRequest? requestContainingPathElement(
    String pathElementId,
  ) {
    final normalized = pathElementId.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(
        pathElementId,
        'pathElementId',
        'must not be empty',
      );
    }

    final stageIndex = _stageIndexByPathElementId[normalized];

    if (stageIndex == null) {
      return null;
    }

    return _policy.containingStageIndex(
      stageIndex: stageIndex,
      totalStageCount: totalStageCount,
    );
  }

  Future<LearningMapWindowComposition> loadInitial() {
    return load(_policy.initial());
  }

  Future<LearningMapWindowComposition> load(
    LearningMapStageWindowRequest request,
  ) async {
    final snapshot = await _readService.load(
      accountId: accountId,
      learningPathId: learningPathId,
      startStageIndex: request.startStageIndex,
      stageCount: request.stageCount,
    );

    return _composer.compose(
      activePath: _activePath,
      snapshot: snapshot,
      locale: locale,
      scaffoldingLocale: scaffoldingLocale,
    );
  }

  Future<LearningMapWindowComposition?> loadNext(
    LearningMapStageWindow current,
  ) async {
    _validateWindowOwnership(current);

    final request = _policy.next(current);

    if (request == null) {
      return null;
    }

    return load(request);
  }

  Future<LearningMapWindowComposition?> loadPrevious(
    LearningMapStageWindow current,
  ) async {
    _validateWindowOwnership(current);

    final request = _policy.previous(current);

    if (request == null) {
      return null;
    }

    return load(request);
  }

  void _validateWindowOwnership(LearningMapStageWindow window) {
    if (window.totalStageCount != totalStageCount) {
      throw StateError('A janela nao pertence a esta sessao.');
    }
  }
}

List<LearningMapStageDescriptor> _stageDescriptors(LearningPath path) {
  final descriptors = <LearningMapStageDescriptor>[];

  for (final journey in path.journeys) {
    for (final stage in journey.stages) {
      final activityIds = <String>[];

      final seenActivityIds = <String>{};

      for (final element in stage.elements) {
        final activityId = element.activityId?.value;

        if (activityId != null && seenActivityIds.add(activityId)) {
          activityIds.add(activityId);
        }
      }

      descriptors.add(
        LearningMapStageDescriptor(
          journeyId: journey.id.value,
          stageId: stage.id.value,
          pathElementIds: stage.elements.map((element) => element.id.value),
          activityIds: activityIds,
        ),
      );
    }
  }

  return List<LearningMapStageDescriptor>.unmodifiable(descriptors);
}

String _requiredValue(String value, String argumentName) {
  final normalized = value.trim();

  if (normalized.isEmpty) {
    throw ArgumentError.value(value, argumentName, 'nao pode estar vazio');
  }

  return normalized;
}
