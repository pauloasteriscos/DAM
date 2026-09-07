import 'package:sqflite/sqflite.dart';

import '../../domain/learning/learning_domain.dart';
import '../database/app_database.dart';
import 'learning_content_import.dart';

/// Códigos estáveis da fronteira de ativação/leitura do catálogo local.
enum LearningContentCatalogErrorCode {
  packageNotFound,
  noActivePackage,
  activePackageInvalid,
  noValidFallback,
  catalogChanged,
}

final class LearningContentCatalogException implements Exception {
  const LearningContentCatalogException({
    required this.code,
    required this.message,
    this.learningPathId,
    this.packageVersion,
    this.reference,
    this.cause,
  });

  final LearningContentCatalogErrorCode code;
  final String message;
  final String? learningPathId;
  final int? packageVersion;
  final String? reference;
  final Object? cause;

  @override
  String toString() =>
      'LearningContentCatalogException(${code.name}): $message';
}

/// Ponteiros persistidos para a versão ativa e para a última versão válida.
final class LearningContentCatalogRecord {
  const LearningContentCatalogRecord({
    required this.learningPathId,
    required this.activePackageId,
    required this.previousPackageId,
    required this.activatedAt,
  });

  final String learningPathId;
  final int activePackageId;
  final int? previousPackageId;
  final DateTime activatedAt;
}

final class LearningContentActivationResult {
  const LearningContentActivationResult({
    required this.catalog,
    required this.package,
    required this.path,
    required this.changed,
  });

  final LearningContentCatalogRecord catalog;
  final LearningContentPackageRecord package;
  final LearningPath path;
  final bool changed;
}

final class ActiveLearningContent {
  const ActiveLearningContent({
    required this.catalog,
    required this.package,
    required this.path,
    required this.recoveredFromFallback,
  });

  final LearningContentCatalogRecord catalog;
  final LearningContentPackageRecord package;
  final LearningPath path;
  final bool recoveredFromFallback;
}

/// Operações SQLite do catálogo. A troca de ponteiros é sempre transacional.
final class LearningContentCatalogRepository {
  LearningContentCatalogRepository({
    Future<Database> Function()? databaseProvider,
  }) : _databaseProvider =
           databaseProvider ?? (() => AppDatabase.instance.database);

  final Future<Database> Function() _databaseProvider;

  Future<LearningContentCatalogRecord?> findCatalog(
    String learningPathId,
  ) async {
    final db = await _databaseProvider();
    final rows = await db.query(
      'learning_content_catalog',
      where: 'learning_path_id = ?',
      whereArgs: [learningPathId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _catalogFromRow(rows.single);
  }

  /// Ativa [packageId] e desloca o ativo anterior para previous_package_id.
  ///
  /// A operação é idempotente quando o pacote já está ativo.
  Future<({LearningContentCatalogRecord catalog, bool changed})>
  activatePackage({
    required String learningPathId,
    required int packageId,
    required DateTime activatedAt,
  }) async {
    final db = await _databaseProvider();
    return db.transaction((txn) async {
      final packageRows = await txn.query(
        'learning_content_packages',
        columns: ['id'],
        where: 'id = ? AND learning_path_id = ?',
        whereArgs: [packageId, learningPathId],
        limit: 1,
      );
      if (packageRows.isEmpty) {
        throw LearningContentCatalogException(
          code: LearningContentCatalogErrorCode.packageNotFound,
          learningPathId: learningPathId,
          reference: packageId.toString(),
          message: 'O pacote a ativar não existe no percurso indicado.',
        );
      }

      final currentRows = await txn.query(
        'learning_content_catalog',
        where: 'learning_path_id = ?',
        whereArgs: [learningPathId],
        limit: 1,
      );

      if (currentRows.isNotEmpty) {
        final current = _catalogFromRow(currentRows.single);
        if (current.activePackageId == packageId) {
          return (catalog: current, changed: false);
        }

        await txn.update(
          'learning_content_catalog',
          {
            'active_package_id': packageId,
            'previous_package_id': current.activePackageId,
            'activated_at': activatedAt.toUtc().toIso8601String(),
          },
          where: 'learning_path_id = ?',
          whereArgs: [learningPathId],
        );
      } else {
        await txn.insert('learning_content_catalog', {
          'learning_path_id': learningPathId,
          'active_package_id': packageId,
          'previous_package_id': null,
          'activated_at': activatedAt.toUtc().toIso8601String(),
        });
      }

      final updatedRows = await txn.query(
        'learning_content_catalog',
        where: 'learning_path_id = ?',
        whereArgs: [learningPathId],
        limit: 1,
      );
      return (catalog: _catalogFromRow(updatedRows.single), changed: true);
    });
  }

  /// Reverte o ponteiro ativo para o previous_package_id apenas se o catálogo
  /// ainda estiver exatamente no estado que foi validado pelo chamador.
  Future<LearningContentCatalogRecord> recoverToPrevious({
    required String learningPathId,
    required int expectedActivePackageId,
    required int expectedPreviousPackageId,
    required DateTime activatedAt,
  }) async {
    final db = await _databaseProvider();
    return db.transaction((txn) async {
      final rows = await txn.query(
        'learning_content_catalog',
        where: 'learning_path_id = ?',
        whereArgs: [learningPathId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw LearningContentCatalogException(
          code: LearningContentCatalogErrorCode.catalogChanged,
          learningPathId: learningPathId,
          message: 'O catálogo desapareceu durante a recuperação.',
        );
      }

      final current = _catalogFromRow(rows.single);
      if (current.activePackageId != expectedActivePackageId ||
          current.previousPackageId != expectedPreviousPackageId) {
        throw LearningContentCatalogException(
          code: LearningContentCatalogErrorCode.catalogChanged,
          learningPathId: learningPathId,
          reference:
              '${current.activePackageId}/${current.previousPackageId ?? '-'}',
          message:
              'O catálogo mudou durante a recuperação; o fallback foi recusado.',
        );
      }

      await txn.update(
        'learning_content_catalog',
        {
          'active_package_id': expectedPreviousPackageId,
          // O pacote falhado continua armazenado para diagnóstico, mas não é
          // mantido como fallback para evitar oscilações automáticas.
          'previous_package_id': null,
          'activated_at': activatedAt.toUtc().toIso8601String(),
        },
        where: 'learning_path_id = ?',
        whereArgs: [learningPathId],
      );

      final updated = await txn.query(
        'learning_content_catalog',
        where: 'learning_path_id = ?',
        whereArgs: [learningPathId],
        limit: 1,
      );
      return _catalogFromRow(updated.single);
    });
  }

  LearningContentCatalogRecord _catalogFromRow(Map<String, Object?> row) {
    return LearningContentCatalogRecord(
      learningPathId: row['learning_path_id']! as String,
      activePackageId: row['active_package_id']! as int,
      previousPackageId: row['previous_package_id'] as int?,
      activatedAt: DateTime.parse(row['activated_at']! as String).toUtc(),
    );
  }
}

/// Ativa e lê conteúdo oficial sem colocar rede no caminho crítico.
///
/// Um pacote só pode tornar-se ativo depois de ter sido importado e de a sua
/// cópia SQLite voltar a passar por hash + codec. Se o ativo ficar inválido,
/// a última versão válida é verificada e promovida atomicamente.
final class LearningContentCatalogService {
  LearningContentCatalogService({
    LearningContentCatalogRepository? catalogRepository,
    LearningContentPackageRepository? packageRepository,
    LearningContentImportService? importService,
  }) : catalogRepository =
           catalogRepository ?? LearningContentCatalogRepository(),
       packageRepository =
           packageRepository ?? LearningContentPackageRepository(),
       importService = importService ?? LearningContentImportService();

  final LearningContentCatalogRepository catalogRepository;
  final LearningContentPackageRepository packageRepository;
  final LearningContentImportService importService;

  Future<LearningContentActivationResult> activate({
    required String learningPathId,
    required int packageVersion,
    DateTime? activatedAt,
  }) async {
    final package = await packageRepository.findPackage(
      learningPathId: learningPathId,
      packageVersion: packageVersion,
    );
    if (package == null) {
      throw LearningContentCatalogException(
        code: LearningContentCatalogErrorCode.packageNotFound,
        learningPathId: learningPathId,
        packageVersion: packageVersion,
        message: 'A versão solicitada ainda não foi importada.',
      );
    }

    final path = await importService.validateStoredPackage(package);
    final switched = await catalogRepository.activatePackage(
      learningPathId: learningPathId,
      packageId: package.id,
      activatedAt: (activatedAt ?? DateTime.now()).toUtc(),
    );

    return LearningContentActivationResult(
      catalog: switched.catalog,
      package: package,
      path: path,
      changed: switched.changed,
    );
  }

  Future<ActiveLearningContent> loadActive(
    String learningPathId, {
    DateTime? recoveredAt,
  }) async {
    final catalog = await catalogRepository.findCatalog(learningPathId);
    if (catalog == null) {
      throw LearningContentCatalogException(
        code: LearningContentCatalogErrorCode.noActivePackage,
        learningPathId: learningPathId,
        message: 'Ainda não existe conteúdo ativo para este percurso.',
      );
    }

    final active = await packageRepository.findPackageById(
      id: catalog.activePackageId,
      learningPathId: learningPathId,
    );
    if (active == null) {
      // A FK deveria tornar este estado impossível numa base íntegra.
      throw LearningContentCatalogException(
        code: LearningContentCatalogErrorCode.activePackageInvalid,
        learningPathId: learningPathId,
        reference: catalog.activePackageId.toString(),
        message: 'O ponteiro ativo referencia um pacote inexistente.',
      );
    }

    try {
      final path = await importService.validateStoredPackage(active);
      return ActiveLearningContent(
        catalog: catalog,
        package: active,
        path: path,
        recoveredFromFallback: false,
      );
    } on Object catch (activeError) {
      if (!_isStoredContentFailure(activeError)) rethrow;

      final previousId = catalog.previousPackageId;
      if (previousId == null) {
        throw LearningContentCatalogException(
          code: LearningContentCatalogErrorCode.noValidFallback,
          learningPathId: learningPathId,
          packageVersion: active.packageVersion,
          cause: activeError,
          message:
              'O pacote ativo é inválido e não existe uma versão anterior disponível.',
        );
      }

      final previous = await packageRepository.findPackageById(
        id: previousId,
        learningPathId: learningPathId,
      );
      if (previous == null) {
        throw LearningContentCatalogException(
          code: LearningContentCatalogErrorCode.noValidFallback,
          learningPathId: learningPathId,
          reference: previousId.toString(),
          cause: activeError,
          message: 'A versão anterior indicada pelo catálogo não existe.',
        );
      }

      LearningPath previousPath;
      try {
        previousPath = await importService.validateStoredPackage(previous);
      } on Object catch (previousError) {
        if (!_isStoredContentFailure(previousError)) rethrow;
        throw LearningContentCatalogException(
          code: LearningContentCatalogErrorCode.noValidFallback,
          learningPathId: learningPathId,
          packageVersion: previous.packageVersion,
          cause: previousError,
          message:
              'Nem o pacote ativo nem a última versão anterior são válidos.',
        );
      }

      final recoveredCatalog = await catalogRepository.recoverToPrevious(
        learningPathId: learningPathId,
        expectedActivePackageId: active.id,
        expectedPreviousPackageId: previous.id,
        activatedAt: (recoveredAt ?? DateTime.now()).toUtc(),
      );

      return ActiveLearningContent(
        catalog: recoveredCatalog,
        package: previous,
        path: previousPath,
        recoveredFromFallback: true,
      );
    }
  }

  bool _isStoredContentFailure(Object error) {
    return error is LearningContentImportException ||
        error is LearningContentException;
  }
}
