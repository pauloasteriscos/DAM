import '../../data/content/learning_content_catalog.dart';
import '../../data/repositories/learning_progress_read_repository.dart';
import '../../domain/learning/learning_enums.dart';
import '../../domain/learning/learning_models.dart';
import 'learning_map_assembler.dart';
import 'learning_map_view_model.dart';

/// Conteúdo mínimo necessário pelo percurso visual depois de o catálogo
/// local ter resolvido pacote ativo, validação e eventual fallback.
final class LearningMapActiveContentSnapshot {
  const LearningMapActiveContentSnapshot({
    required this.path,
    required this.packageVersion,
    required this.recoveredFromFallback,
  });

  final LearningPath path;
  final int packageVersion;
  final bool recoveredFromFallback;
}

typedef LearningMapActiveContentLoader =
    Future<LearningMapActiveContentSnapshot> Function(String learningPathId);

typedef LearningMapProjectionLoader =
    Future<List<LearningProgressProjectionEntry>> Function({
      required String accountId,
      required String learningPathId,
    });

typedef LearningMapSyncStateLoader =
    Future<Map<String, ProgressSyncState>> Function({
      required String accountId,
      required String learningPathId,
    });

/// Fronteira de leitura usada pela futura interface do percurso.
///
/// Toda a informação vem de fontes locais:
/// - catálogo oficial ativo;
/// - projeção pedagógica SQLite;
/// - estado técnico da outbox.
///
/// Esta classe não contacta a rede e não executa regras pedagógicas.
final class LearningMapReadService {
  const LearningMapReadService({
    required LearningMapActiveContentLoader loadActiveContent,
    required LearningMapProjectionLoader loadProjection,
    required LearningMapSyncStateLoader loadSyncStates,
    LearningMapAssembler assembler = const LearningMapAssembler(),
  }) : _loadActiveContent = loadActiveContent,
       _loadProjection = loadProjection,
       _loadSyncStates = loadSyncStates,
       _assembler = assembler;

  factory LearningMapReadService.fromRepositories({
    required LearningContentCatalogService catalogService,
    required LearningProgressReadRepository progressRepository,
    LearningMapAssembler assembler = const LearningMapAssembler(),
  }) {
    return LearningMapReadService(
      loadActiveContent: (learningPathId) async {
        final active = await catalogService.loadActive(learningPathId);

        return LearningMapActiveContentSnapshot(
          path: active.path,
          packageVersion: active.package.packageVersion,
          recoveredFromFallback: active.recoveredFromFallback,
        );
      },
      loadProjection: progressRepository.readProjection,
      loadSyncStates: progressRepository.readActivitySyncStates,
      assembler: assembler,
    );
  }

  final LearningMapActiveContentLoader _loadActiveContent;
  final LearningMapProjectionLoader _loadProjection;
  final LearningMapSyncStateLoader _loadSyncStates;
  final LearningMapAssembler _assembler;

  Future<LearningMapViewModel> load({
    required String accountId,
    required String learningPathId,
    required String locale,
  }) async {
    final normalizedAccountId = accountId.trim();
    final normalizedPathId = learningPathId.trim();
    final normalizedLocale = locale.trim();

    if (normalizedAccountId.isEmpty) {
      throw ArgumentError.value(accountId, 'accountId', 'não pode estar vazio');
    }

    if (normalizedPathId.isEmpty) {
      throw ArgumentError.value(
        learningPathId,
        'learningPathId',
        'não pode estar vazio',
      );
    }

    if (normalizedLocale.isEmpty) {
      throw ArgumentError.value(locale, 'locale', 'não pode estar vazio');
    }

    final active = await _loadActiveContent(normalizedPathId);

    if (active.path.id.value != normalizedPathId) {
      throw StateError(
        'O catálogo devolveu o percurso ${active.path.id.value} '
        'quando foi solicitado $normalizedPathId.',
      );
    }

    // As duas leituras são independentes e exclusivamente locais.
    // Iniciá-las antes dos awaits evita serialização desnecessária.
    final projectionFuture = _loadProjection(
      accountId: normalizedAccountId,
      learningPathId: normalizedPathId,
    );

    final syncStatesFuture = _loadSyncStates(
      accountId: normalizedAccountId,
      learningPathId: normalizedPathId,
    );

    final projection = await projectionFuture;
    final syncStates = await syncStatesFuture;

    return _assembler.build(
      learningPath: active.path,
      packageVersion: active.packageVersion,
      recoveredFromFallback: active.recoveredFromFallback,
      locale: normalizedLocale,
      projection: projection,
      syncStates: syncStates,
    );
  }
}
