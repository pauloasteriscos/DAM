import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../../config/app_config.dart';
import '../../domain/learning/learning_domain.dart';
import '../database/app_database.dart';
import 'learning_content_catalog.dart';
import 'learning_content_import.dart';

/// Códigos estáveis da fronteira de assets oficiais da Fase 2.3.
enum LearningContentAssetErrorCode {
  catalogHttpError,
  invalidCatalog,
  manifestNotPublished,
  manifestConflict,
  manifestHttpError,
  manifestHeaderMismatch,
  manifestSizeMismatch,
  manifestHashMismatch,
  invalidManifestUtf8,
  invalidManifest,
  manifestPackageMismatch,
  unknownRevision,
  unsupportedContentType,
  assetHttpError,
  assetHeaderMismatch,
  assetSizeMismatch,
  assetHashMismatch,
}

/// Falha estável na distribuição/persistência de assets oficiais.
final class LearningContentAssetException implements Exception {
  const LearningContentAssetException({
    required this.code,
    required this.message,
    this.learningPathId,
    this.packageVersion,
    this.reference,
    this.cause,
  });

  final LearningContentAssetErrorCode code;
  final String message;
  final String? learningPathId;
  final int? packageVersion;
  final String? reference;
  final Object? cause;

  @override
  String toString() => 'LearningContentAssetException(${code.name}): $message';
}

/// Metadata remota de um manifesto imutável de assets.
final class OfficialLearningAssetManifestMetadata {
  const OfficialLearningAssetManifestMetadata({
    required this.learningPathId,
    required this.packageVersion,
    required this.manifestVersion,
    required this.sha256,
    required this.sizeBytes,
    required this.contentType,
    required this.downloadPath,
  });

  final String learningPathId;
  final int packageVersion;
  final int manifestVersion;
  final String sha256;
  final int sizeBytes;
  final String contentType;
  final String downloadPath;
}

/// Asset lógico associado a uma revisão imutável.
final class LearningContentAssetDescriptor {
  const LearningContentAssetDescriptor({
    required this.assetId,
    required this.revisionId,
    required this.role,
    required this.contentType,
    required this.sha256,
    required this.sizeBytes,
    required this.downloadPath,
    required this.required,
    required this.sortOrder,
  });

  final String assetId;
  final String revisionId;
  final String role;
  final String contentType;
  final String sha256;
  final int sizeBytes;
  final String downloadPath;
  final bool required;
  final int sortOrder;
}

/// Manifesto validado e ligado a uma versão concreta do pacote de conteúdo.
final class LearningContentAssetManifest {
  const LearningContentAssetManifest({
    required this.manifestVersion,
    required this.learningPathId,
    required this.packageVersion,
    required this.assets,
  });

  final int manifestVersion;
  final String learningPathId;
  final int packageVersion;
  final List<LearningContentAssetDescriptor> assets;
}

/// Linha imutável do manifesto persistido em SQLite.
final class LearningContentAssetManifestRecord {
  const LearningContentAssetManifestRecord({
    required this.packageId,
    required this.manifestVersion,
    required this.manifestHash,
    required this.manifestJson,
    required this.importedAt,
  });

  final int packageId;
  final int manifestVersion;
  final String manifestHash;
  final String manifestJson;
  final DateTime importedAt;
}

/// Linha do cache binário content-addressed.
final class LearningContentAssetCacheRecord {
  const LearningContentAssetCacheRecord({
    required this.contentHash,
    required this.contentType,
    required this.sizeBytes,
    required this.bytes,
    required this.source,
    required this.downloadedAt,
    required this.lastVerifiedAt,
    required this.lastAccessedAt,
  });

  final String contentHash;
  final String contentType;
  final int sizeBytes;
  final Uint8List bytes;
  final String source;
  final DateTime downloadedAt;
  final DateTime lastVerifiedAt;
  final DateTime lastAccessedAt;
}

/// Resultado de uma atualização incremental dos assets do pacote ativo.
final class LearningContentAssetRefreshResult {
  const LearningContentAssetRefreshResult({
    required this.metadata,
    required this.manifest,
    required this.downloadedAssets,
    required this.reusedAssets,
    required this.manifestDownloaded,
  });

  final OfficialLearningAssetManifestMetadata metadata;
  final LearningContentAssetManifest manifest;
  final int downloadedAssets;
  final int reusedAssets;
  final bool manifestDownloaded;
}

/// Asset já resolvido a partir do cache local, sem rede.
final class LearningContentResolvedAsset {
  const LearningContentResolvedAsset({
    required this.descriptor,
    required this.bytes,
    required this.packageVersion,
    required this.fromPreviousPackage,
  });

  final LearningContentAssetDescriptor descriptor;
  final Uint8List bytes;
  final int packageVersion;
  final bool fromPreviousPackage;
}

final class LearningContentAssetPruneResult {
  const LearningContentAssetPruneResult({
    required this.removedManifests,
    required this.removedBlobs,
  });

  final int removedManifests;
  final int removedBlobs;
}

/// SQLite para manifestos, entradas e bytes já validados.
final class LearningContentAssetRepository {
  LearningContentAssetRepository({
    Future<Database> Function()? databaseProvider,
  }) : _databaseProvider =
           databaseProvider ?? (() => AppDatabase.instance.database);

  final Future<Database> Function() _databaseProvider;

  Future<LearningContentAssetManifestRecord?> findManifest(
    int packageId,
  ) async {
    final db = await _databaseProvider();
    final rows = await db.query(
      'learning_content_asset_manifests',
      where: 'package_id = ?',
      whereArgs: [packageId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _manifestFromRow(rows.single);
  }

  Future<LearningContentAssetCacheRecord?> findCachedAsset(
    String contentHash,
  ) async {
    final db = await _databaseProvider();
    final rows = await db.query(
      'learning_content_asset_cache',
      where: 'content_hash = ?',
      whereArgs: [contentHash],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _cacheFromRow(rows.single);
  }

  Future<void> storeVerifiedAsset({
    required LearningContentAssetDescriptor descriptor,
    required Uint8List bytes,
    required String source,
    required DateTime verifiedAt,
  }) async {
    final db = await _databaseProvider();
    final now = verifiedAt.toUtc().toIso8601String();

    await db.insert('learning_content_asset_cache', {
      'content_hash': descriptor.sha256,
      'content_type': descriptor.contentType,
      'size_bytes': descriptor.sizeBytes,
      'bytes': bytes,
      'source': source,
      'downloaded_at': now,
      'last_verified_at': now,
      'last_accessed_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Persiste o manifesto apenas depois de todos os assets obrigatórios terem
  /// sido verificados. A identidade packageId/manifestHash é imutável.
  Future<void> storeValidatedManifest({
    required int packageId,
    required String manifestHash,
    required String manifestJson,
    required LearningContentAssetManifest manifest,
    required DateTime importedAt,
  }) async {
    final db = await _databaseProvider();

    await db.transaction((txn) async {
      final existing = await txn.query(
        'learning_content_asset_manifests',
        where: 'package_id = ?',
        whereArgs: [packageId],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        final currentHash = existing.single['manifest_hash']! as String;
        if (currentHash != manifestHash) {
          throw LearningContentAssetException(
            code: LearningContentAssetErrorCode.manifestConflict,
            learningPathId: manifest.learningPathId,
            packageVersion: manifest.packageVersion,
            reference: currentHash,
            message: 'O pacote já possui outro manifesto imutável associado.',
          );
        }

        await txn.update(
          'learning_content_asset_manifests',
          {
            'manifest_version': manifest.manifestVersion,
            'manifest_json': manifestJson,
            'imported_at': importedAt.toUtc().toIso8601String(),
          },
          where: 'package_id = ?',
          whereArgs: [packageId],
        );
        await txn.delete(
          'learning_content_asset_entries',
          where: 'package_id = ?',
          whereArgs: [packageId],
        );
      } else {
        await txn.insert('learning_content_asset_manifests', {
          'package_id': packageId,
          'manifest_version': manifest.manifestVersion,
          'manifest_hash': manifestHash,
          'manifest_json': manifestJson,
          'imported_at': importedAt.toUtc().toIso8601String(),
        });
      }

      for (final asset in manifest.assets) {
        await txn.insert('learning_content_asset_entries', {
          'package_id': packageId,
          'asset_id': asset.assetId,
          'revision_id': asset.revisionId,
          'role': asset.role,
          'content_hash': asset.sha256,
          'size_bytes': asset.sizeBytes,
          'content_type': asset.contentType,
          'download_path': asset.downloadPath,
          'required': asset.required ? 1 : 0,
          'sort_order': asset.sortOrder,
        });
      }
    });
  }

  Future<void> touchCachedAsset(
    String contentHash, {
    required DateTime accessedAt,
    bool verified = false,
  }) async {
    final db = await _databaseProvider();
    final values = <String, Object?>{
      'last_accessed_at': accessedAt.toUtc().toIso8601String(),
    };
    if (verified) {
      values['last_verified_at'] = accessedAt.toUtc().toIso8601String();
    }
    await db.update(
      'learning_content_asset_cache',
      values,
      where: 'content_hash = ?',
      whereArgs: [contentHash],
    );
  }

  /// Retém somente manifestos/bytes pertencentes a pacotes active/previous.
  /// Pacotes de conteúdo históricos permanecem intactos e podem voltar a
  /// descarregar assets se forem explicitamente reativados no futuro.
  Future<LearningContentAssetPruneResult> pruneObsolete() async {
    final db = await _databaseProvider();

    return db.transaction((txn) async {
      final catalogRows = await txn.query(
        'learning_content_catalog',
        columns: ['active_package_id', 'previous_package_id'],
      );
      final protected = <int>{};
      for (final row in catalogRows) {
        protected.add(row['active_package_id']! as int);
        final previous = row['previous_package_id'] as int?;
        if (previous != null) protected.add(previous);
      }

      int removedManifests;
      if (protected.isEmpty) {
        removedManifests = await txn.delete('learning_content_asset_manifests');
      } else {
        final placeholders = List.filled(protected.length, '?').join(',');
        removedManifests = await txn.delete(
          'learning_content_asset_manifests',
          where: 'package_id NOT IN ($placeholders)',
          whereArgs: protected.toList(growable: false),
        );
      }

      final usedRows = await txn.rawQuery(
        'SELECT DISTINCT content_hash '
        'FROM learning_content_asset_entries',
      );
      final usedHashes = usedRows
          .map((row) => row['content_hash']! as String)
          .toSet();

      int removedBlobs;
      if (usedHashes.isEmpty) {
        removedBlobs = await txn.delete('learning_content_asset_cache');
      } else {
        final placeholders = List.filled(usedHashes.length, '?').join(',');
        removedBlobs = await txn.delete(
          'learning_content_asset_cache',
          where: 'content_hash NOT IN ($placeholders)',
          whereArgs: usedHashes.toList(growable: false),
        );
      }

      return LearningContentAssetPruneResult(
        removedManifests: removedManifests,
        removedBlobs: removedBlobs,
      );
    });
  }

  LearningContentAssetManifestRecord _manifestFromRow(
    Map<String, Object?> row,
  ) {
    return LearningContentAssetManifestRecord(
      packageId: row['package_id']! as int,
      manifestVersion: row['manifest_version']! as int,
      manifestHash: row['manifest_hash']! as String,
      manifestJson: row['manifest_json']! as String,
      importedAt: DateTime.parse(row['imported_at']! as String).toUtc(),
    );
  }

  LearningContentAssetCacheRecord _cacheFromRow(Map<String, Object?> row) {
    final rawBytes = row['bytes'];
    final bytes = rawBytes is Uint8List
        ? rawBytes
        : Uint8List.fromList((rawBytes! as List<int>));

    return LearningContentAssetCacheRecord(
      contentHash: row['content_hash']! as String,
      contentType: row['content_type']! as String,
      sizeBytes: row['size_bytes']! as int,
      bytes: bytes,
      source: row['source']! as String,
      downloadedAt: DateTime.parse(row['downloaded_at']! as String).toUtc(),
      lastVerifiedAt: DateTime.parse(
        row['last_verified_at']! as String,
      ).toUtc(),
      lastAccessedAt: DateTime.parse(
        row['last_accessed_at']! as String,
      ).toUtc(),
    );
  }
}

/// Distribui assets de forma incremental e mantém a aprendizagem independente
/// da rede. O conteúdo JSON continua a ser a autoridade para revisões.
final class LearningContentAssetService {
  LearningContentAssetService({
    http.Client? client,
    LearningContentAssetRepository? repository,
    LearningContentCatalogService? catalogService,
    LearningContentImportService? importService,
    HashAlgorithm? sha256,
  }) : _client = client ?? http.Client(),
       repository = repository ?? LearningContentAssetRepository(),
       catalogService = catalogService ?? LearningContentCatalogService(),
       importService = importService ?? LearningContentImportService(),
       _sha256 = sha256 ?? Sha256();

  static final LearningContentAssetService instance =
      LearningContentAssetService();

  static const int supportedAssetCatalogVersion = 1;
  static const int supportedManifestVersion = 1;
  static const int _maxManifestBytes = 1024 * 1024;
  static const int _maxAssetBytes = 50 * 1024 * 1024;
  static const Set<String> _supportedContentTypes = {
    'image/png',
    'image/jpeg',
    'image/webp',
    'audio/wav',
    'audio/mpeg',
    'audio/ogg',
  };

  final http.Client _client;
  final LearningContentAssetRepository repository;
  final LearningContentCatalogService catalogService;
  final LearningContentImportService importService;
  final HashAlgorithm _sha256;

  Future<List<OfficialLearningAssetManifestMetadata>>
  fetchManifestCatalog() async {
    final base = Uri.parse(AppConfig.apiBaseUrl);
    final uri = base.resolve('/api/content/assets/catalog');
    AppConfig.assertApiUri(uri);

    final response = await _client
        .get(uri, headers: AppConfig.environmentHeaders)
        .timeout(AppConfig.apiTimeout);

    AppConfig.assertResponseEnvironment(response.headers);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LearningContentAssetException(
        code: LearningContentAssetErrorCode.catalogHttpError,
        reference: response.statusCode.toString(),
        message: 'O catálogo de assets respondeu HTTP ${response.statusCode}.',
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on Object catch (error) {
      throw LearningContentAssetException(
        code: LearningContentAssetErrorCode.invalidCatalog,
        message: 'O catálogo de assets não contém JSON válido.',
        cause: error,
      );
    }

    if (decoded is! Map<String, dynamic> ||
        decoded['success'] != true ||
        decoded['assetCatalogVersion'] != supportedAssetCatalogVersion ||
        decoded['manifests'] is! List<dynamic>) {
      throw const LearningContentAssetException(
        code: LearningContentAssetErrorCode.invalidCatalog,
        message: 'O contrato do catálogo de assets não é suportado.',
      );
    }

    final result = <OfficialLearningAssetManifestMetadata>[];
    for (final item in decoded['manifests'] as List<dynamic>) {
      if (item is! Map<String, dynamic>) {
        throw const LearningContentAssetException(
          code: LearningContentAssetErrorCode.invalidCatalog,
          message: 'O catálogo contém metadata de manifesto inválida.',
        );
      }
      result.add(_manifestMetadataFromJson(item));
    }
    return List.unmodifiable(result);
  }

  /// Atualiza apenas os assets da versão atualmente ativa do percurso.
  Future<LearningContentAssetRefreshResult> refreshActiveAssets(
    String learningPathId, {
    DateTime? now,
  }) async {
    final active = await catalogService.loadActive(learningPathId);
    final catalog = await fetchManifestCatalog();
    final metadata = _firstWhereOrNull(
      catalog,
      (item) =>
          item.learningPathId == learningPathId &&
          item.packageVersion == active.package.packageVersion,
    );

    if (metadata == null) {
      throw LearningContentAssetException(
        code: LearningContentAssetErrorCode.manifestNotPublished,
        learningPathId: learningPathId,
        packageVersion: active.package.packageVersion,
        message:
            'Não existe manifesto de assets para o pacote de conteúdo ativo.',
      );
    }

    final timestamp = (now ?? DateTime.now()).toUtc();
    var manifestDownloaded = false;
    String manifestJson;
    LearningContentAssetManifest manifest;

    final stored = await repository.findManifest(active.package.id);
    if (stored != null && stored.manifestHash != metadata.sha256) {
      throw LearningContentAssetException(
        code: LearningContentAssetErrorCode.manifestConflict,
        learningPathId: learningPathId,
        packageVersion: active.package.packageVersion,
        reference: stored.manifestHash,
        message:
            'O mesmo pacote local está associado a outro manifesto imutável.',
      );
    }

    if (stored != null &&
        await _hashUtf8(stored.manifestJson) == stored.manifestHash) {
      manifestJson = stored.manifestJson;
      manifest = _parseAndValidateManifest(
        manifestJson,
        metadata: metadata,
        path: active.path,
      );
    } else {
      manifestJson = await _downloadAndValidateManifest(metadata);
      manifestDownloaded = true;
      manifest = _parseAndValidateManifest(
        manifestJson,
        metadata: metadata,
        path: active.path,
      );
    }

    var downloadedAssets = 0;
    var reusedAssets = 0;
    final verifiedThisRun = <String>{};

    for (final asset in manifest.assets) {
      if (verifiedThisRun.contains(asset.sha256)) {
        reusedAssets += 1;
        continue;
      }

      final cached = await repository.findCachedAsset(asset.sha256);
      if (cached != null && await _cachedAssetIsValid(cached, asset)) {
        await repository.touchCachedAsset(
          asset.sha256,
          accessedAt: timestamp,
          verified: true,
        );
        reusedAssets += 1;
        verifiedThisRun.add(asset.sha256);
        continue;
      }

      try {
        final bytes = await _downloadAndValidateAsset(asset);
        await repository.storeVerifiedAsset(
          descriptor: asset,
          bytes: bytes,
          source: 'remote:${asset.downloadPath}',
          verifiedAt: timestamp,
        );
        downloadedAssets += 1;
        verifiedThisRun.add(asset.sha256);
      } on Object {
        if (asset.required) rethrow;
      }
    }

    for (final asset in manifest.assets.where((asset) => asset.required)) {
      final cached = await repository.findCachedAsset(asset.sha256);
      if (cached == null || !await _cachedAssetIsValid(cached, asset)) {
        throw LearningContentAssetException(
          code: LearningContentAssetErrorCode.assetHashMismatch,
          learningPathId: learningPathId,
          packageVersion: manifest.packageVersion,
          reference: asset.assetId,
          message:
              'Um asset obrigatório não ficou disponível de forma íntegra.',
        );
      }
    }

    await repository.storeValidatedManifest(
      packageId: active.package.id,
      manifestHash: metadata.sha256,
      manifestJson: manifestJson,
      manifest: manifest,
      importedAt: timestamp,
    );
    await repository.pruneObsolete();

    return LearningContentAssetRefreshResult(
      metadata: metadata,
      manifest: manifest,
      downloadedAssets: downloadedAssets,
      reusedAssets: reusedAssets,
      manifestDownloaded: manifestDownloaded,
    );
  }

  /// Resolve um asset exclusivamente a partir da réplica local.
  ///
  /// Se o pacote ativo não possuir uma cópia íntegra, tenta o pacote previous
  /// somente para a mesma revisionId + role. A rede nunca é consultada.
  Future<LearningContentResolvedAsset?> resolveAsset({
    required String learningPathId,
    required String revisionId,
    required String role,
    bool allowPreviousFallback = true,
    DateTime? accessedAt,
  }) async {
    final catalog = await catalogService.catalogRepository.findCatalog(
      learningPathId,
    );
    if (catalog == null) return null;

    final timestamp = (accessedAt ?? DateTime.now()).toUtc();
    final active = await _resolveFromPackage(
      learningPathId: learningPathId,
      packageId: catalog.activePackageId,
      revisionId: revisionId,
      role: role,
      fromPrevious: false,
      accessedAt: timestamp,
    );
    if (active != null) return active;

    final previousId = catalog.previousPackageId;
    if (!allowPreviousFallback || previousId == null) return null;

    return _resolveFromPackage(
      learningPathId: learningPathId,
      packageId: previousId,
      revisionId: revisionId,
      role: role,
      fromPrevious: true,
      accessedAt: timestamp,
    );
  }

  Future<LearningContentResolvedAsset?> _resolveFromPackage({
    required String learningPathId,
    required int packageId,
    required String revisionId,
    required String role,
    required bool fromPrevious,
    required DateTime accessedAt,
  }) async {
    final package = await importService.repository.findPackageById(
      id: packageId,
      learningPathId: learningPathId,
    );
    if (package == null) return null;

    LearningPath path;
    try {
      path = await importService.validateStoredPackage(package);
    } on Object {
      return null;
    }

    final stored = await repository.findManifest(packageId);
    if (stored == null) return null;
    if (await _hashUtf8(stored.manifestJson) != stored.manifestHash) {
      return null;
    }

    LearningContentAssetManifest manifest;
    try {
      manifest = _parseAndValidateManifest(
        stored.manifestJson,
        metadata: OfficialLearningAssetManifestMetadata(
          learningPathId: learningPathId,
          packageVersion: package.packageVersion,
          manifestVersion: stored.manifestVersion,
          sha256: stored.manifestHash,
          sizeBytes: utf8.encode(stored.manifestJson).length,
          contentType: 'application/json',
          downloadPath:
              '/api/content/assets/manifests/$learningPathId/${package.packageVersion}',
        ),
        path: path,
      );
    } on Object {
      return null;
    }

    final candidates =
        manifest.assets
            .where(
              (asset) => asset.revisionId == revisionId && asset.role == role,
            )
            .toList(growable: false)
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (candidates.isEmpty) return null;

    for (final descriptor in candidates) {
      final cached = await repository.findCachedAsset(descriptor.sha256);
      if (cached == null || !await _cachedAssetIsValid(cached, descriptor)) {
        continue;
      }

      await repository.touchCachedAsset(
        descriptor.sha256,
        accessedAt: accessedAt,
        verified: true,
      );
      return LearningContentResolvedAsset(
        descriptor: descriptor,
        bytes: Uint8List.fromList(cached.bytes),
        packageVersion: package.packageVersion,
        fromPreviousPackage: fromPrevious,
      );
    }

    return null;
  }

  Future<String> _downloadAndValidateManifest(
    OfficialLearningAssetManifestMetadata metadata,
  ) async {
    final base = Uri.parse(AppConfig.apiBaseUrl);
    final uri = base.resolve(metadata.downloadPath);
    AppConfig.assertApiUri(uri);

    final response = await _client
        .get(uri, headers: AppConfig.environmentHeaders)
        .timeout(AppConfig.apiTimeout);

    AppConfig.assertResponseEnvironment(response.headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LearningContentAssetException(
        code: LearningContentAssetErrorCode.manifestHttpError,
        learningPathId: metadata.learningPathId,
        packageVersion: metadata.packageVersion,
        reference: response.statusCode.toString(),
        message: 'O manifesto respondeu HTTP ${response.statusCode}.',
      );
    }

    final contentType = response.headers['content-type']?.toLowerCase();
    final hash = response.headers['x-asset-manifest-sha256']
        ?.trim()
        .toLowerCase();
    final manifestVersion = response.headers['x-asset-manifest-version']
        ?.trim();
    final packageVersion = response.headers['x-content-package-version']
        ?.trim();
    final etag = response.headers['etag']?.trim();
    if (contentType == null ||
        !contentType.startsWith('application/json') ||
        hash != metadata.sha256 ||
        manifestVersion != metadata.manifestVersion.toString() ||
        packageVersion != metadata.packageVersion.toString() ||
        etag != '"sha256-${metadata.sha256}"') {
      throw LearningContentAssetException(
        code: LearningContentAssetErrorCode.manifestHeaderMismatch,
        learningPathId: metadata.learningPathId,
        packageVersion: metadata.packageVersion,
        message: 'Os headers do manifesto não correspondem ao catálogo.',
      );
    }

    final bytes = response.bodyBytes;
    if (bytes.length != metadata.sizeBytes) {
      throw LearningContentAssetException(
        code: LearningContentAssetErrorCode.manifestSizeMismatch,
        learningPathId: metadata.learningPathId,
        packageVersion: metadata.packageVersion,
        reference: bytes.length.toString(),
        message: 'O tamanho do manifesto não corresponde ao catálogo.',
      );
    }
    if (await _hashBytes(bytes) != metadata.sha256) {
      throw LearningContentAssetException(
        code: LearningContentAssetErrorCode.manifestHashMismatch,
        learningPathId: metadata.learningPathId,
        packageVersion: metadata.packageVersion,
        message: 'O manifesto não corresponde ao SHA-256 publicado.',
      );
    }

    try {
      final text = utf8.decode(bytes, allowMalformed: false);
      if (!_sameBytes(utf8.encode(text), bytes)) {
        throw const FormatException('UTF-8 não canónico.');
      }
      return text;
    } on FormatException catch (error) {
      throw LearningContentAssetException(
        code: LearningContentAssetErrorCode.invalidManifestUtf8,
        learningPathId: metadata.learningPathId,
        packageVersion: metadata.packageVersion,
        message: 'O manifesto não contém UTF-8 canónico.',
        cause: error,
      );
    }
  }

  Future<Uint8List> _downloadAndValidateAsset(
    LearningContentAssetDescriptor descriptor,
  ) async {
    final base = Uri.parse(AppConfig.apiBaseUrl);
    final uri = base.resolve(descriptor.downloadPath);
    AppConfig.assertApiUri(uri);

    final response = await _client
        .get(uri, headers: AppConfig.environmentHeaders)
        .timeout(AppConfig.apiTimeout);

    AppConfig.assertResponseEnvironment(response.headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LearningContentAssetException(
        code: LearningContentAssetErrorCode.assetHttpError,
        reference: '${descriptor.assetId}/${response.statusCode}',
        message: 'O asset oficial respondeu HTTP ${response.statusCode}.',
      );
    }

    final contentType = response.headers['content-type']
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    final hash = response.headers['x-asset-sha256']?.trim().toLowerCase();
    final size = response.headers['x-asset-size']?.trim();
    final etag = response.headers['etag']?.trim();
    if (contentType != descriptor.contentType ||
        hash != descriptor.sha256 ||
        size != descriptor.sizeBytes.toString() ||
        etag != '"sha256-${descriptor.sha256}"') {
      throw LearningContentAssetException(
        code: LearningContentAssetErrorCode.assetHeaderMismatch,
        reference: descriptor.assetId,
        message: 'Os headers do asset não correspondem ao manifesto.',
      );
    }

    final bytes = response.bodyBytes;
    if (bytes.length != descriptor.sizeBytes) {
      throw LearningContentAssetException(
        code: LearningContentAssetErrorCode.assetSizeMismatch,
        reference: descriptor.assetId,
        message: 'O tamanho do asset não corresponde ao manifesto.',
      );
    }
    if (await _hashBytes(bytes) != descriptor.sha256) {
      throw LearningContentAssetException(
        code: LearningContentAssetErrorCode.assetHashMismatch,
        reference: descriptor.assetId,
        message: 'O asset não corresponde ao SHA-256 do manifesto.',
      );
    }

    return Uint8List.fromList(bytes);
  }

  LearningContentAssetManifest _parseAndValidateManifest(
    String source, {
    required OfficialLearningAssetManifestMetadata metadata,
    required LearningPath path,
  }) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on Object catch (error) {
      throw LearningContentAssetException(
        code: LearningContentAssetErrorCode.invalidManifest,
        learningPathId: metadata.learningPathId,
        packageVersion: metadata.packageVersion,
        message: 'O manifesto não contém JSON válido.',
        cause: error,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const LearningContentAssetException(
        code: LearningContentAssetErrorCode.invalidManifest,
        message: 'A raiz do manifesto deve ser um objeto JSON.',
      );
    }

    _requireExactKeys(decoded, {
      'manifestVersion',
      'pathId',
      'packageVersion',
      'assets',
    });

    final manifestVersion = decoded['manifestVersion'];
    final pathId = decoded['pathId'];
    final packageVersion = decoded['packageVersion'];
    final rawAssets = decoded['assets'];

    if (manifestVersion != supportedManifestVersion ||
        manifestVersion != metadata.manifestVersion ||
        pathId != metadata.learningPathId ||
        packageVersion != metadata.packageVersion ||
        rawAssets is! List<dynamic>) {
      throw LearningContentAssetException(
        code: LearningContentAssetErrorCode.manifestPackageMismatch,
        learningPathId: metadata.learningPathId,
        packageVersion: metadata.packageVersion,
        message: 'O manifesto não corresponde à versão do pacote publicada.',
      );
    }

    final validRevisionIds = <String>{
      for (final activity in path.activities)
        for (final revision in activity.revisions) revision.id.value,
    };
    final assetIds = <String>{};
    final assets = <LearningContentAssetDescriptor>[];

    for (final raw in rawAssets) {
      if (raw is! Map<String, dynamic>) {
        throw const LearningContentAssetException(
          code: LearningContentAssetErrorCode.invalidManifest,
          message: 'Cada asset deve ser um objeto JSON.',
        );
      }
      _requireExactKeys(raw, {
        'assetId',
        'revisionId',
        'role',
        'contentType',
        'sha256',
        'sizeBytes',
        'downloadPath',
        'required',
        'sortOrder',
      });

      final assetId = raw['assetId'];
      final revisionId = raw['revisionId'];
      final role = raw['role'];
      final contentType = raw['contentType'];
      final sha256 = raw['sha256'];
      final sizeBytes = raw['sizeBytes'];
      final downloadPath = raw['downloadPath'];
      final required = raw['required'];
      final sortOrder = raw['sortOrder'];

      final validAssetId =
          assetId is String &&
          RegExp(r'^[a-z0-9][a-z0-9._-]{0,119}$').hasMatch(assetId);
      final validRevisionId =
          revisionId is String && validRevisionIds.contains(revisionId);
      final validRole =
          role is String && RegExp(r'^[a-z][a-z0-9._-]{0,63}$').hasMatch(role);
      final normalizedContentType = contentType is String
          ? contentType.trim().toLowerCase()
          : '';
      final normalizedHash = sha256 is String
          ? sha256.trim().toLowerCase()
          : '';
      final validHash = RegExp(r'^[0-9a-f]{64}$').hasMatch(normalizedHash);
      final validSize =
          sizeBytes is int && sizeBytes >= 1 && sizeBytes <= _maxAssetBytes;
      final validDownloadPath =
          downloadPath is String &&
          validHash &&
          downloadPath == '/api/content/assets/blobs/$normalizedHash';

      if (!validAssetId ||
          !validRole ||
          !validHash ||
          !validSize ||
          !validDownloadPath ||
          required is! bool ||
          sortOrder is! int ||
          sortOrder < 0) {
        throw LearningContentAssetException(
          code: LearningContentAssetErrorCode.invalidManifest,
          learningPathId: metadata.learningPathId,
          packageVersion: metadata.packageVersion,
          reference: assetId?.toString(),
          message: 'O manifesto contém um descritor de asset inválido.',
        );
      }

      if (!validRevisionId) {
        throw LearningContentAssetException(
          code: LearningContentAssetErrorCode.unknownRevision,
          learningPathId: metadata.learningPathId,
          packageVersion: metadata.packageVersion,
          reference: revisionId?.toString(),
          message: 'O manifesto referencia uma revisão inexistente no pacote.',
        );
      }

      if (!_supportedContentTypes.contains(normalizedContentType)) {
        throw LearningContentAssetException(
          code: LearningContentAssetErrorCode.unsupportedContentType,
          learningPathId: metadata.learningPathId,
          packageVersion: metadata.packageVersion,
          reference: normalizedContentType,
          message: 'O tipo MIME do asset não é suportado.',
        );
      }

      if (!assetIds.add(assetId)) {
        throw LearningContentAssetException(
          code: LearningContentAssetErrorCode.invalidManifest,
          reference: assetId,
          message: 'O manifesto contém assetId duplicado.',
        );
      }

      assets.add(
        LearningContentAssetDescriptor(
          assetId: assetId,
          revisionId: revisionId,
          role: role,
          contentType: normalizedContentType,
          sha256: normalizedHash,
          sizeBytes: sizeBytes,
          downloadPath: downloadPath,
          required: required,
          sortOrder: sortOrder,
        ),
      );
    }

    return LearningContentAssetManifest(
      manifestVersion: manifestVersion as int,
      learningPathId: pathId as String,
      packageVersion: packageVersion as int,
      assets: List.unmodifiable(assets),
    );
  }

  OfficialLearningAssetManifestMetadata _manifestMetadataFromJson(
    Map<String, dynamic> json,
  ) {
    _requireExactKeys(json, {
      'pathId',
      'packageVersion',
      'manifestVersion',
      'sha256',
      'sizeBytes',
      'contentType',
      'downloadPath',
      'immutable',
    }, errorCode: LearningContentAssetErrorCode.invalidCatalog);

    final pathId = json['pathId'];
    final packageVersion = json['packageVersion'];
    final manifestVersion = json['manifestVersion'];
    final sha256 = json['sha256'];
    final sizeBytes = json['sizeBytes'];
    final contentType = json['contentType'];
    final downloadPath = json['downloadPath'];
    final immutable = json['immutable'];

    final validPath =
        pathId is String &&
        RegExp(r'^[a-z0-9][a-z0-9._-]{0,199}$').hasMatch(pathId);
    final normalizedHash = sha256 is String ? sha256.trim().toLowerCase() : '';
    final validHash = RegExp(r'^[0-9a-f]{64}$').hasMatch(normalizedHash);
    final validDownloadPath =
        downloadPath is String &&
        validPath &&
        packageVersion is int &&
        downloadPath == '/api/content/assets/manifests/$pathId/$packageVersion';

    if (!validPath ||
        packageVersion is! int ||
        packageVersion < 1 ||
        manifestVersion is! int ||
        manifestVersion != supportedManifestVersion ||
        !validHash ||
        sizeBytes is! int ||
        sizeBytes < 1 ||
        sizeBytes > _maxManifestBytes ||
        contentType != 'application/json' ||
        !validDownloadPath ||
        immutable != true) {
      throw const LearningContentAssetException(
        code: LearningContentAssetErrorCode.invalidCatalog,
        message: 'A metadata de um manifesto de assets é inválida.',
      );
    }

    return OfficialLearningAssetManifestMetadata(
      learningPathId: pathId,
      packageVersion: packageVersion,
      manifestVersion: manifestVersion,
      sha256: normalizedHash,
      sizeBytes: sizeBytes,
      contentType: contentType as String,
      downloadPath: downloadPath,
    );
  }

  Future<bool> _cachedAssetIsValid(
    LearningContentAssetCacheRecord cached,
    LearningContentAssetDescriptor descriptor,
  ) async {
    if (cached.contentHash != descriptor.sha256 ||
        cached.contentType != descriptor.contentType ||
        cached.sizeBytes != descriptor.sizeBytes ||
        cached.bytes.length != descriptor.sizeBytes) {
      return false;
    }
    return await _hashBytes(cached.bytes) == descriptor.sha256;
  }

  Future<String> _hashUtf8(String source) => _hashBytes(utf8.encode(source));

  Future<String> _hashBytes(List<int> bytes) async {
    final digest = await _sha256.hash(bytes);
    return digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  bool _sameBytes(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  void _requireExactKeys(
    Map<String, dynamic> json,
    Set<String> expected, {
    LearningContentAssetErrorCode errorCode =
        LearningContentAssetErrorCode.invalidManifest,
  }) {
    final actual = json.keys.toSet();
    if (actual.length != expected.length || !actual.containsAll(expected)) {
      throw LearningContentAssetException(
        code: errorCode,
        message: 'O contrato JSON contém campos inesperados ou em falta.',
      );
    }
  }

  T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T item) predicate) {
    for (final item in items) {
      if (predicate(item)) return item;
    }
    return null;
  }
}
