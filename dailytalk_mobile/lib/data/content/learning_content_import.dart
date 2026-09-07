import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/learning/learning_domain.dart';
import '../database/app_database.dart';

/// Códigos estáveis para falhas da importação local de conteúdo oficial.
enum LearningContentImportErrorCode {
  invalidPackageVersion,
  invalidExpectedHash,
  hashMismatch,
  versionConflict,
  immutableRevisionConflict,
  storedPackageCorrupted,
  storedPackageMetadataMismatch,
}

/// Exceção estável da fronteira de persistência/importação.
///
/// Erros estruturais do JSON continuam a ser representados por
/// [LearningContentException], produzido pelo codec da Fase 1.
final class LearningContentImportException implements Exception {
  const LearningContentImportException({
    required this.code,
    required this.message,
    this.learningPathId,
    this.packageVersion,
    this.reference,
  });

  final LearningContentImportErrorCode code;
  final String message;
  final String? learningPathId;
  final int? packageVersion;
  final String? reference;

  @override
  String toString() => 'LearningContentImportException(${code.name}): $message';
}

/// Registo imutável de um pacote persistido no catálogo local.
final class LearningContentPackageRecord {
  const LearningContentPackageRecord({
    required this.id,
    required this.learningPathId,
    required this.packageVersion,
    required this.schemaVersion,
    required this.contentHash,
    required this.payloadJson,
    required this.source,
    required this.importedAt,
  });

  final int id;
  final String learningPathId;
  final int packageVersion;
  final int schemaVersion;
  final String contentHash;
  final String payloadJson;
  final String source;
  final DateTime importedAt;
}

/// Resultado de uma importação validada.
final class LearningContentImportResult {
  const LearningContentImportResult({
    required this.package,
    required this.path,
    required this.inserted,
  });

  final LearningContentPackageRecord package;
  final LearningPath path;

  /// `true` quando houve INSERT; `false` numa reimportação idempotente.
  final bool inserted;
}

/// Persistência SQLite dos pacotes já validados.
///
/// Não interpreta JSON, não calcula hash, não ativa conteúdo e não acede à rede.
final class LearningContentPackageRepository {
  LearningContentPackageRepository({
    Future<Database> Function()? databaseProvider,
  }) : _databaseProvider =
           databaseProvider ?? (() => AppDatabase.instance.database);

  final Future<Database> Function() _databaseProvider;

  Future<LearningContentPackageRecord?> findPackage({
    required String learningPathId,
    required int packageVersion,
  }) async {
    final db = await _databaseProvider();
    final rows = await db.query(
      'learning_content_packages',
      where: 'learning_path_id = ? AND package_version = ?',
      whereArgs: [learningPathId, packageVersion],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _packageFromRow(rows.single);
  }

  Future<LearningContentPackageRecord?> findPackageById({
    required int id,
    required String learningPathId,
  }) async {
    final db = await _databaseProvider();
    final rows = await db.query(
      'learning_content_packages',
      where: 'id = ? AND learning_path_id = ?',
      whereArgs: [id, learningPathId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _packageFromRow(rows.single);
  }

  Future<List<LearningContentPackageRecord>> listPackages(
    String learningPathId,
  ) async {
    final db = await _databaseProvider();
    final rows = await db.query(
      'learning_content_packages',
      where: 'learning_path_id = ?',
      whereArgs: [learningPathId],
      orderBy: 'package_version ASC',
    );
    return rows.map(_packageFromRow).toList(growable: false);
  }

  /// Persiste conteúdo que já passou por hash + codec + validação global.
  ///
  /// A combinação learningPathId/packageVersion é imutável. Repetir o mesmo
  /// pacote é idempotente; reutilizar a mesma versão com outro hash é erro.
  Future<({LearningContentPackageRecord package, bool inserted})>
  storeValidatedPackage({
    required String learningPathId,
    required int packageVersion,
    required int schemaVersion,
    required String contentHash,
    required String payloadJson,
    required String source,
    required DateTime importedAt,
  }) async {
    final db = await _databaseProvider();

    return db.transaction((txn) async {
      final existingRows = await txn.query(
        'learning_content_packages',
        where: 'learning_path_id = ? AND package_version = ?',
        whereArgs: [learningPathId, packageVersion],
        limit: 1,
      );

      if (existingRows.isNotEmpty) {
        final existing = _packageFromRow(existingRows.single);
        if (existing.contentHash != contentHash) {
          throw LearningContentImportException(
            code: LearningContentImportErrorCode.versionConflict,
            learningPathId: learningPathId,
            packageVersion: packageVersion,
            reference: existing.contentHash,
            message:
                'A versão $packageVersion já existe com outro hash e não pode ser sobrescrita.',
          );
        }
        return (package: existing, inserted: false);
      }

      final id = await txn.insert('learning_content_packages', {
        'learning_path_id': learningPathId,
        'package_version': packageVersion,
        'schema_version': schemaVersion,
        'content_hash': contentHash,
        'payload_json': payloadJson,
        'source': source,
        'imported_at': importedAt.toUtc().toIso8601String(),
      });

      return (
        package: LearningContentPackageRecord(
          id: id,
          learningPathId: learningPathId,
          packageVersion: packageVersion,
          schemaVersion: schemaVersion,
          contentHash: contentHash,
          payloadJson: payloadJson,
          source: source,
          importedAt: importedAt.toUtc(),
        ),
        inserted: true,
      );
    });
  }

  LearningContentPackageRecord _packageFromRow(Map<String, Object?> row) {
    return LearningContentPackageRecord(
      id: row['id']! as int,
      learningPathId: row['learning_path_id']! as String,
      packageVersion: row['package_version']! as int,
      schemaVersion: row['schema_version']! as int,
      contentHash: row['content_hash']! as String,
      payloadJson: row['payload_json']! as String,
      source: row['source']! as String,
      importedAt: DateTime.parse(row['imported_at']! as String).toUtc(),
    );
  }
}

/// Orquestra a fronteira de entrada do conteúdo oficial para o SQLite.
///
/// Ordem deliberada: versão -> SHA-256 -> codec/validação -> invariantes de
/// imutabilidade -> persistência. Nenhuma ativação ocorre nesta subfase.
final class LearningContentImportService {
  LearningContentImportService({
    LearningContentPackageRepository? repository,
    LearningContentCodec codec = const LearningContentCodec(),
    Sha256? sha256,
  }) : repository = repository ?? LearningContentPackageRepository(),
       _codec = codec,
       _sha256 = sha256 ?? Sha256();

  final LearningContentPackageRepository repository;
  final LearningContentCodec _codec;
  final Sha256 _sha256;

  Future<LearningContentImportResult> importPackage({
    required String payloadJson,
    required int packageVersion,
    required String source,
    required String expectedSha256,
    DateTime? importedAt,
  }) async {
    if (packageVersion < 1) {
      throw LearningContentImportException(
        code: LearningContentImportErrorCode.invalidPackageVersion,
        packageVersion: packageVersion,
        message: 'packageVersion deve ser igual ou superior a 1.',
      );
    }

    final expected = expectedSha256.trim().toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(expected)) {
      throw LearningContentImportException(
        code: LearningContentImportErrorCode.invalidExpectedHash,
        packageVersion: packageVersion,
        reference: expectedSha256,
        message:
            'O hash esperado deve ser SHA-256 hexadecimal com 64 caracteres.',
      );
    }

    final contentHash = await computeSha256(payloadJson);
    if (contentHash != expected) {
      throw LearningContentImportException(
        code: LearningContentImportErrorCode.hashMismatch,
        packageVersion: packageVersion,
        reference: contentHash,
        message:
            'O pacote foi rejeitado porque o SHA-256 não corresponde ao esperado.',
      );
    }

    // O codec da Fase 1 valida schema, campos, enums, IDs, referências e ciclos.
    final path = _codec.decodeString(payloadJson);

    // Fast-path de idempotência. Também confirma que a linha existente ainda
    // contém exatamente os bytes associados ao hash imutável persistido.
    final existing = await repository.findPackage(
      learningPathId: path.id.value,
      packageVersion: packageVersion,
    );
    if (existing != null) {
      if (existing.contentHash != contentHash) {
        throw LearningContentImportException(
          code: LearningContentImportErrorCode.versionConflict,
          learningPathId: path.id.value,
          packageVersion: packageVersion,
          reference: existing.contentHash,
          message:
              'A versão $packageVersion já existe com outro hash e não pode ser sobrescrita.',
        );
      }

      final storedHash = await computeSha256(existing.payloadJson);
      if (storedHash != existing.contentHash) {
        throw LearningContentImportException(
          code: LearningContentImportErrorCode.storedPackageCorrupted,
          learningPathId: path.id.value,
          packageVersion: packageVersion,
          reference: storedHash,
          message:
              'A cópia SQLite do pacote existente não corresponde ao hash persistido.',
        );
      }

      return LearningContentImportResult(
        package: existing,
        path: path,
        inserted: false,
      );
    }

    await _assertRevisionImmutability(path);

    final stored = await repository.storeValidatedPackage(
      learningPathId: path.id.value,
      packageVersion: packageVersion,
      schemaVersion: path.schemaVersion.value,
      contentHash: contentHash,
      payloadJson: payloadJson,
      source: source,
      importedAt: (importedAt ?? DateTime.now()).toUtc(),
    );

    return LearningContentImportResult(
      package: stored.package,
      path: path,
      inserted: stored.inserted,
    );
  }

  /// Confirma que uma linha já persistida continua íntegra e semanticamente
  /// coerente com os seus metadados antes de poder ser ativada/lida.
  Future<LearningPath> validateStoredPackage(
    LearningContentPackageRecord package,
  ) async {
    final storedHash = await computeSha256(package.payloadJson);
    if (storedHash != package.contentHash) {
      throw LearningContentImportException(
        code: LearningContentImportErrorCode.storedPackageCorrupted,
        learningPathId: package.learningPathId,
        packageVersion: package.packageVersion,
        reference: storedHash,
        message: 'A cópia SQLite do pacote não corresponde ao hash persistido.',
      );
    }

    final path = _codec.decodeString(package.payloadJson);
    if (path.id.value != package.learningPathId ||
        path.schemaVersion.value != package.schemaVersion) {
      throw LearningContentImportException(
        code: LearningContentImportErrorCode.storedPackageMetadataMismatch,
        learningPathId: package.learningPathId,
        packageVersion: package.packageVersion,
        reference: path.id.value,
        message:
            'Os metadados SQLite do pacote não correspondem ao conteúdo validado.',
      );
    }

    return path;
  }

  Future<String> computeSha256(String payloadJson) async {
    final digest = await _sha256.hash(utf8.encode(payloadJson));
    return digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// RevisionId já publicado não pode ganhar novo significado noutro pacote.
  /// Conteúdo alterado exige um novo RevisionId.
  Future<void> _assertRevisionImmutability(LearningPath candidate) async {
    final existingPackages = await repository.listPackages(candidate.id.value);
    if (existingPackages.isEmpty) return;

    final candidateRevisions = _canonicalRevisions(candidate);

    for (final package in existingPackages) {
      final storedHash = await computeSha256(package.payloadJson);
      if (storedHash != package.contentHash) {
        throw LearningContentImportException(
          code: LearningContentImportErrorCode.storedPackageCorrupted,
          learningPathId: package.learningPathId,
          packageVersion: package.packageVersion,
          reference: storedHash,
          message:
              'Um pacote previamente importado está corrompido; a comparação de revisões foi recusada.',
        );
      }

      final stored = _codec.decodeString(package.payloadJson);
      final storedRevisions = _canonicalRevisions(stored);

      for (final entry in candidateRevisions.entries) {
        final previous = storedRevisions[entry.key];
        if (previous != null && previous != entry.value) {
          throw LearningContentImportException(
            code: LearningContentImportErrorCode.immutableRevisionConflict,
            learningPathId: candidate.id.value,
            packageVersion: package.packageVersion,
            reference: entry.key,
            message:
                'RevisionId ${entry.key} já foi publicado com outro conteúdo. Crie uma nova revisão.',
          );
        }
      }
    }
  }

  Map<String, String> _canonicalRevisions(LearningPath path) {
    final result = <String, String>{};

    for (final activity in path.activities) {
      for (final revision in activity.revisions) {
        final competencies =
            revision.competencies
                .map((competency) => competency.value)
                .toList(growable: false)
              ..sort();

        result[revision.id.value] = jsonEncode(<String, dynamic>{
          'id': revision.id.value,
          'activityId': revision.activityId.value,
          'revisionNumber': revision.revisionNumber,
          'title': _canonicalLocalizedText(revision.title),
          'instructions': _canonicalLocalizedText(revision.instructions),
          'visibility': revision.visibility.name,
          'competencies': competencies,
        });
      }
    }

    return result;
  }

  Map<String, String> _canonicalLocalizedText(LocalizedText text) {
    final keys = text.values.keys.toList(growable: false)..sort();
    return <String, String>{for (final key in keys) key: text.values[key]!};
  }
}
