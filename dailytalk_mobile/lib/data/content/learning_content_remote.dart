import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import 'learning_content_catalog.dart';
import 'learning_content_import.dart';

/// Códigos estáveis da fronteira de distribuição remota do conteúdo oficial.
enum LearningContentRemoteErrorCode {
  catalogHttpError,
  invalidCatalog,
  packageNotPublished,
  staleCatalogConflict,
  packageHttpError,
  packageHeaderMismatch,
  packageSizeMismatch,
  packageHashMismatch,
  invalidUtf8,
}

/// Exceção estável da fronteira HTTP -> conteúdo oficial local.
final class LearningContentRemoteException implements Exception {
  const LearningContentRemoteException({
    required this.code,
    required this.message,
    this.learningPathId,
    this.packageVersion,
    this.reference,
    this.cause,
  });

  final LearningContentRemoteErrorCode code;
  final String message;
  final String? learningPathId;
  final int? packageVersion;
  final String? reference;
  final Object? cause;

  @override
  String toString() => 'LearningContentRemoteException(${code.name}): $message';
}

/// Metadata imutável publicada pelo catálogo oficial da API.
final class OfficialLearningContentMetadata {
  const OfficialLearningContentMetadata({
    required this.learningPathId,
    required this.schemaVersion,
    required this.packageVersion,
    required this.sha256,
    required this.sizeBytes,
    required this.contentType,
    required this.downloadPath,
  });

  final String learningPathId;
  final int schemaVersion;
  final int packageVersion;
  final String sha256;
  final int sizeBytes;
  final String contentType;
  final String downloadPath;
}

enum LearningContentRefreshStatus {
  downloadedAndActivated,
  activatedFromLocalPackage,
  alreadyCurrent,
  ignoredStaleRemote,
}

/// Resultado de uma verificação remota sem esconder se houve I/O de rede.
final class LearningContentRefreshResult {
  const LearningContentRefreshResult({
    required this.status,
    required this.metadata,
    required this.active,
    required this.downloaded,
  });

  final LearningContentRefreshStatus status;
  final OfficialLearningContentMetadata metadata;
  final ActiveLearningContent active;
  final bool downloaded;
}

/// Consulta a distribuição oficial, valida bytes e promove conteúdo no SQLite.
///
/// A rede nunca é usada para ler o percurso durante a aprendizagem. Este
/// serviço apenas atualiza a réplica local. A leitura normal continua a ser
/// feita por [LearningContentCatalogService.loadActive].
final class LearningContentRemoteService {
  LearningContentRemoteService({
    http.Client? client,
    LearningContentImportService? importService,
    LearningContentCatalogService? catalogService,
    Sha256? sha256,
  }) : _client = client ?? http.Client(),
       importService = importService ?? LearningContentImportService(),
       catalogService = catalogService ?? LearningContentCatalogService(),
       _sha256 = sha256 ?? Sha256();

  final http.Client _client;
  final LearningContentImportService importService;
  final LearningContentCatalogService catalogService;
  final Sha256 _sha256;

  Future<List<OfficialLearningContentMetadata>> fetchCatalog() async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/content/catalog');
    AppConfig.assertApiUri(uri);

    final response = await _client
        .get(uri, headers: AppConfig.environmentHeaders)
        .timeout(AppConfig.apiTimeout);

    AppConfig.assertResponseEnvironment(response.headers);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LearningContentRemoteException(
        code: LearningContentRemoteErrorCode.catalogHttpError,
        reference: response.statusCode.toString(),
        message: 'O catálogo oficial respondeu HTTP ${response.statusCode}.',
      );
    }

    final Object decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (error) {
      throw LearningContentRemoteException(
        code: LearningContentRemoteErrorCode.invalidCatalog,
        message: 'O catálogo oficial não contém JSON válido.',
        cause: error,
      );
    }

    if (decoded is! Map ||
        decoded['success'] != true ||
        decoded['catalogVersion'] != 1 ||
        decoded['packages'] is! List) {
      throw const LearningContentRemoteException(
        code: LearningContentRemoteErrorCode.invalidCatalog,
        message: 'O catálogo oficial não respeita o contrato suportado.',
      );
    }

    final packages = <OfficialLearningContentMetadata>[];
    for (final item in decoded['packages'] as List) {
      if (item is! Map) {
        throw const LearningContentRemoteException(
          code: LearningContentRemoteErrorCode.invalidCatalog,
          message: 'O catálogo contém metadata de pacote inválida.',
        );
      }
      packages.add(_metadataFromJson(Map<String, dynamic>.from(item)));
    }

    return List.unmodifiable(packages);
  }

  /// Atualiza um percurso para a versão mais recente publicada pela API.
  ///
  /// Ordem deliberada:
  /// catálogo -> monotonicidade -> download -> headers -> tamanho -> SHA-256
  /// -> UTF-8 -> importação SQLite -> ativação transacional.
  Future<LearningContentRefreshResult> refreshLearningPath(
    String learningPathId, {
    DateTime? importedAt,
    DateTime? activatedAt,
  }) async {
    final catalog = await fetchCatalog();
    final metadata = catalog
        .where((item) => item.learningPathId == learningPathId)
        .firstOrNull;

    if (metadata == null) {
      throw LearningContentRemoteException(
        code: LearningContentRemoteErrorCode.packageNotPublished,
        learningPathId: learningPathId,
        message: 'O catálogo não publica nenhum pacote para este percurso.',
      );
    }

    final activePackage = await _findCurrentActivePackage(learningPathId);
    if (activePackage != null &&
        metadata.packageVersion < activePackage.packageVersion) {
      final active = await catalogService.loadActive(learningPathId);
      return LearningContentRefreshResult(
        status: LearningContentRefreshStatus.ignoredStaleRemote,
        metadata: metadata,
        active: active,
        downloaded: false,
      );
    }

    final localPackage = await importService.repository.findPackage(
      learningPathId: learningPathId,
      packageVersion: metadata.packageVersion,
    );

    if (localPackage != null) {
      if (localPackage.contentHash != metadata.sha256) {
        throw LearningContentRemoteException(
          code: LearningContentRemoteErrorCode.staleCatalogConflict,
          learningPathId: learningPathId,
          packageVersion: metadata.packageVersion,
          reference: localPackage.contentHash,
          message:
              'A API publicou a mesma packageVersion com hash diferente da cópia local imutável.',
        );
      }

      await importService.validateStoredPackage(localPackage);
      final activation = await catalogService.activate(
        learningPathId: learningPathId,
        packageVersion: metadata.packageVersion,
        activatedAt: activatedAt,
      );
      final active = await catalogService.loadActive(learningPathId);

      return LearningContentRefreshResult(
        status: activation.changed
            ? LearningContentRefreshStatus.activatedFromLocalPackage
            : LearningContentRefreshStatus.alreadyCurrent,
        metadata: metadata,
        active: active,
        downloaded: false,
      );
    }

    final payload = await _downloadAndValidatePackage(metadata);
    final imported = await importService.importPackage(
      payloadJson: payload,
      packageVersion: metadata.packageVersion,
      source: 'remote:${metadata.downloadPath}',
      expectedSha256: metadata.sha256,
      importedAt: importedAt,
    );

    if (imported.path.id.value != metadata.learningPathId ||
        imported.package.schemaVersion != metadata.schemaVersion) {
      throw LearningContentRemoteException(
        code: LearningContentRemoteErrorCode.invalidCatalog,
        learningPathId: metadata.learningPathId,
        packageVersion: metadata.packageVersion,
        message:
            'A metadata remota não corresponde ao percurso/schema do pacote validado.',
      );
    }

    await catalogService.activate(
      learningPathId: learningPathId,
      packageVersion: metadata.packageVersion,
      activatedAt: activatedAt,
    );
    final active = await catalogService.loadActive(learningPathId);

    return LearningContentRefreshResult(
      status: LearningContentRefreshStatus.downloadedAndActivated,
      metadata: metadata,
      active: active,
      downloaded: true,
    );
  }

  Future<LearningContentPackageRecord?> _findCurrentActivePackage(
    String learningPathId,
  ) async {
    final catalog = await catalogService.catalogRepository.findCatalog(
      learningPathId,
    );
    if (catalog == null) return null;

    return importService.repository.findPackageById(
      id: catalog.activePackageId,
      learningPathId: learningPathId,
    );
  }

  Future<String> _downloadAndValidatePackage(
    OfficialLearningContentMetadata metadata,
  ) async {
    final base = Uri.parse(AppConfig.apiBaseUrl);
    final uri = base.resolve(metadata.downloadPath);
    AppConfig.assertApiUri(uri);

    final response = await _client
        .get(uri, headers: AppConfig.environmentHeaders)
        .timeout(AppConfig.apiTimeout);

    AppConfig.assertResponseEnvironment(response.headers);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LearningContentRemoteException(
        code: LearningContentRemoteErrorCode.packageHttpError,
        learningPathId: metadata.learningPathId,
        packageVersion: metadata.packageVersion,
        reference: response.statusCode.toString(),
        message: 'O pacote oficial respondeu HTTP ${response.statusCode}.',
      );
    }

    _validatePackageHeaders(response.headers, metadata);

    final bytes = response.bodyBytes;
    if (bytes.length != metadata.sizeBytes) {
      throw LearningContentRemoteException(
        code: LearningContentRemoteErrorCode.packageSizeMismatch,
        learningPathId: metadata.learningPathId,
        packageVersion: metadata.packageVersion,
        reference: bytes.length.toString(),
        message:
            'O tamanho recebido não corresponde ao tamanho publicado no catálogo.',
      );
    }

    final digest = await _sha256.hash(bytes);
    final receivedHash = digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    if (receivedHash != metadata.sha256) {
      throw LearningContentRemoteException(
        code: LearningContentRemoteErrorCode.packageHashMismatch,
        learningPathId: metadata.learningPathId,
        packageVersion: metadata.packageVersion,
        reference: receivedHash,
        message: 'Os bytes recebidos não correspondem ao SHA-256 publicado.',
      );
    }

    try {
      final payload = utf8.decode(bytes, allowMalformed: false);
      final roundTrip = utf8.encode(payload);
      if (roundTrip.length != bytes.length) {
        throw const FormatException('UTF-8 não canónico.');
      }
      for (var index = 0; index < bytes.length; index += 1) {
        if (roundTrip[index] != bytes[index]) {
          throw const FormatException('UTF-8 não canónico.');
        }
      }
      return payload;
    } on FormatException catch (error) {
      throw LearningContentRemoteException(
        code: LearningContentRemoteErrorCode.invalidUtf8,
        learningPathId: metadata.learningPathId,
        packageVersion: metadata.packageVersion,
        message: 'O pacote oficial não contém UTF-8 canónico válido.',
        cause: error,
      );
    }
  }

  void _validatePackageHeaders(
    Map<String, String> headers,
    OfficialLearningContentMetadata metadata,
  ) {
    final contentType = headers['content-type']?.toLowerCase();
    final hash = headers['x-content-sha256']?.trim().toLowerCase();
    final packageVersion = headers['x-content-package-version']?.trim();
    final schemaVersion = headers['x-content-schema-version']?.trim();
    final etag = headers['etag']?.trim();
    final expectedEtag = '"sha256-${metadata.sha256}"';

    if (contentType == null ||
        !contentType.startsWith('application/json') ||
        hash != metadata.sha256 ||
        packageVersion != metadata.packageVersion.toString() ||
        schemaVersion != metadata.schemaVersion.toString() ||
        etag != expectedEtag) {
      throw LearningContentRemoteException(
        code: LearningContentRemoteErrorCode.packageHeaderMismatch,
        learningPathId: metadata.learningPathId,
        packageVersion: metadata.packageVersion,
        reference: '$hash/$packageVersion/$schemaVersion/$etag',
        message: 'Os headers do pacote não correspondem à metadata publicada.',
      );
    }
  }

  OfficialLearningContentMetadata _metadataFromJson(Map<String, dynamic> json) {
    final pathId = json['pathId'];
    final schemaVersion = json['schemaVersion'];
    final packageVersion = json['packageVersion'];
    final sha256 = json['sha256'];
    final sizeBytes = json['sizeBytes'];
    final contentType = json['contentType'];
    final downloadPath = json['downloadPath'];
    final immutable = json['immutable'];

    final validPath =
        pathId is String &&
        RegExp(r'^[a-z0-9][a-z0-9._-]{0,199}$').hasMatch(pathId);
    final validHash =
        sha256 is String &&
        RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256.toLowerCase());
    final validDownloadPath =
        downloadPath is String &&
        validPath &&
        packageVersion is int &&
        downloadPath == '/api/content/packages/$pathId/$packageVersion';

    if (!validPath ||
        schemaVersion is! int ||
        schemaVersion < 1 ||
        packageVersion is! int ||
        packageVersion < 1 ||
        !validHash ||
        sizeBytes is! int ||
        sizeBytes < 1 ||
        contentType != 'application/json' ||
        !validDownloadPath ||
        immutable != true) {
      throw const LearningContentRemoteException(
        code: LearningContentRemoteErrorCode.invalidCatalog,
        message: 'A metadata de um pacote oficial é inválida.',
      );
    }

    return OfficialLearningContentMetadata(
      learningPathId: pathId,
      schemaVersion: schemaVersion,
      packageVersion: packageVersion,
      sha256: sha256.toLowerCase(),
      sizeBytes: sizeBytes,
      contentType: contentType as String,
      downloadPath: downloadPath,
    );
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
