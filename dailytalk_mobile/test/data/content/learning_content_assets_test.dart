import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dailytalk_mobile/data/content/content_data.dart';
import 'package:dailytalk_mobile/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _contentAssetPath = 'assets/content/phase1_example_path.v1.json';
const _pathId = 'student.fr-fr.phase1';
const _revision1 = 'arrival.vocabulary-01.revision-01';
const _revision2 = 'arrival.vocabulary-01.revision-02';

String _v1Source() => File(_contentAssetPath).readAsStringSync();

String _v2Source() {
  final package = jsonDecode(_v1Source()) as Map<String, dynamic>;
  final activities = package['activities']! as List<dynamic>;
  final first = activities.first as Map<String, dynamic>;
  final revisions = first['revisions']! as List<dynamic>;
  final revision2 =
      jsonDecode(jsonEncode(revisions.first)) as Map<String, dynamic>;

  revision2['id'] = _revision2;
  revision2['revisionNumber'] = 2;
  revision2['title'] = <String, dynamic>{
    'pt-PT': 'Palavras de acolhimento — edição revista',
  };
  first['currentRevisionId'] = revision2['id'];
  revisions.add(revision2);
  return jsonEncode(package);
}

Future<String> _sha256Bytes(List<int> bytes) async {
  final digest = await Sha256().hash(bytes);
  return digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

String _manifestJson({
  required String imageHash,
  required int imageSize,
  required String audioHash,
  required int audioSize,
  String revisionId = _revision2,
  String imageContentType = 'image/png',
}) {
  return jsonEncode({
    'manifestVersion': 1,
    'pathId': _pathId,
    'packageVersion': 2,
    'assets': [
      {
        'assetId': 'arrival.vocabulary-01.illustration-01',
        'revisionId': revisionId,
        'role': 'illustration',
        'contentType': imageContentType,
        'sha256': imageHash,
        'sizeBytes': imageSize,
        'downloadPath': '/api/content/assets/blobs/$imageHash',
        'required': true,
        'sortOrder': 0,
      },
      {
        'assetId': 'arrival.vocabulary-01.pronunciation-01',
        'revisionId': revisionId,
        'role': 'pronunciation',
        'contentType': 'audio/wav',
        'sha256': audioHash,
        'sizeBytes': audioSize,
        'downloadPath': '/api/content/assets/blobs/$audioHash',
        'required': true,
        'sortOrder': 1,
      },
    ],
  });
}

TypeMatcher<LearningContentAssetException> _assetError(
  LearningContentAssetErrorCode code,
) => isA<LearningContentAssetException>().having(
  (error) => error.code,
  'code',
  code,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Database db;
  late LearningContentPackageRepository packageRepository;
  late LearningContentImportService importer;
  late LearningContentCatalogRepository catalogRepository;
  late LearningContentCatalogService catalogService;
  late LearningContentAssetRepository assetRepository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dailytalk-assets-');
    db = await AppDatabase.instance.openDatabaseForTesting(
      p.join(tempDir.path, 'assets.db'),
    );
    packageRepository = LearningContentPackageRepository(
      databaseProvider: () async => db,
    );
    importer = LearningContentImportService(repository: packageRepository);
    catalogRepository = LearningContentCatalogRepository(
      databaseProvider: () async => db,
    );
    catalogService = LearningContentCatalogService(
      catalogRepository: catalogRepository,
      packageRepository: packageRepository,
      importService: importer,
    );
    assetRepository = LearningContentAssetRepository(
      databaseProvider: () async => db,
    );

    await _importAndActivateV2(importer, catalogService);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<
    ({
      MockClient client,
      int Function() catalogRequests,
      int Function() manifestRequests,
      int Function() blobRequests,
      String imageHash,
      String audioHash,
    })
  >
  mockAssetApi({
    List<int> imageBytes = const [1, 2, 3, 4, 5],
    List<int> audioBytes = const [10, 11, 12, 13, 14, 15],
    String revisionId = _revision2,
    String imageContentType = 'image/png',
    bool invalidCatalog = false,
    bool corruptManifestBody = false,
    bool corruptImageBody = false,
    bool wrongImageHeader = false,
  }) async {
    final imageHash = await _sha256Bytes(imageBytes);
    final audioHash = await _sha256Bytes(audioBytes);
    final manifest = _manifestJson(
      imageHash: imageHash,
      imageSize: imageBytes.length,
      audioHash: audioHash,
      audioSize: audioBytes.length,
      revisionId: revisionId,
      imageContentType: imageContentType,
    );
    final manifestBytes = utf8.encode(manifest);
    final manifestHash = await _sha256Bytes(manifestBytes);
    var catalogCount = 0;
    var manifestCount = 0;
    var blobCount = 0;

    final client = MockClient((request) async {
      if (request.url.path == '/api/content/assets/catalog') {
        catalogCount += 1;
        return http.Response(
          invalidCatalog
              ? '{"success":true,"assetCatalogVersion":999,"manifests":[]}'
              : jsonEncode({
                  'success': true,
                  'assetCatalogVersion': 1,
                  'manifests': [
                    {
                      'pathId': _pathId,
                      'packageVersion': 2,
                      'manifestVersion': 1,
                      'sha256': manifestHash,
                      'sizeBytes': manifestBytes.length,
                      'contentType': 'application/json',
                      'downloadPath':
                          '/api/content/assets/manifests/$_pathId/2',
                      'immutable': true,
                    },
                  ],
                }),
          200,
          headers: {'x-dailytalk-environment': 'DEV'},
        );
      }

      if (request.url.path == '/api/content/assets/manifests/$_pathId/2') {
        manifestCount += 1;
        final body = corruptManifestBody
            ? utf8.encode(manifest.replaceFirst('"assets"', '"assetz"'))
            : manifestBytes;
        return http.Response.bytes(
          body,
          200,
          headers: {
            'x-dailytalk-environment': 'DEV',
            'content-type': 'application/json; charset=utf-8',
            'x-asset-manifest-sha256': manifestHash,
            'x-asset-manifest-version': '1',
            'x-content-package-version': '2',
            'etag': '"sha256-$manifestHash"',
          },
        );
      }

      if (request.url.path == '/api/content/assets/blobs/$imageHash') {
        blobCount += 1;
        final body = corruptImageBody
            ? [...imageBytes.take(imageBytes.length - 1), 99]
            : imageBytes;
        return http.Response.bytes(
          body,
          200,
          headers: {
            'x-dailytalk-environment': 'DEV',
            'content-type': imageContentType,
            'x-asset-sha256': wrongImageHeader
                ? List.filled(64, '0').join()
                : imageHash,
            'x-asset-size': imageBytes.length.toString(),
            'etag': '"sha256-$imageHash"',
          },
        );
      }

      if (request.url.path == '/api/content/assets/blobs/$audioHash') {
        blobCount += 1;
        return http.Response.bytes(
          audioBytes,
          200,
          headers: {
            'x-dailytalk-environment': 'DEV',
            'content-type': 'audio/wav',
            'x-asset-sha256': audioHash,
            'x-asset-size': audioBytes.length.toString(),
            'etag': '"sha256-$audioHash"',
          },
        );
      }

      return http.Response(
        '{"error":"not found"}',
        404,
        headers: {'x-dailytalk-environment': 'DEV'},
      );
    });

    return (
      client: client,
      catalogRequests: () => catalogCount,
      manifestRequests: () => manifestCount,
      blobRequests: () => blobCount,
      imageHash: imageHash,
      audioHash: audioHash,
    );
  }

  LearningContentAssetService serviceWith(http.Client client) {
    return LearningContentAssetService(
      client: client,
      repository: assetRepository,
      catalogService: catalogService,
      importService: importer,
    );
  }

  group('DailyTalk Fase 2.3 — assets oficiais', () {
    test(
      'descarrega manifesto/assets e resolve imagem e áudio offline',
      () async {
        final api = await mockAssetApi();
        final service = serviceWith(api.client);

        final result = await service.refreshActiveAssets(_pathId);

        expect(result.manifest.packageVersion, 2);
        expect(result.manifestDownloaded, isTrue);
        expect(result.downloadedAssets, 2);
        expect(result.reusedAssets, 0);
        expect(api.catalogRequests(), 1);
        expect(api.manifestRequests(), 1);
        expect(api.blobRequests(), 2);

        final image = await service.resolveAsset(
          learningPathId: _pathId,
          revisionId: _revision2,
          role: 'illustration',
        );
        final audio = await service.resolveAsset(
          learningPathId: _pathId,
          revisionId: _revision2,
          role: 'pronunciation',
        );

        expect(image, isNotNull);
        expect(image!.bytes, orderedEquals([1, 2, 3, 4, 5]));
        expect(image.fromPreviousPackage, isFalse);
        expect(audio, isNotNull);
        expect(audio!.bytes, orderedEquals([10, 11, 12, 13, 14, 15]));
      },
    );

    test('segunda atualização reutiliza manifesto e blobs íntegros', () async {
      final api = await mockAssetApi();
      final service = serviceWith(api.client);

      await service.refreshActiveAssets(_pathId);
      final second = await service.refreshActiveAssets(_pathId);

      expect(second.manifestDownloaded, isFalse);
      expect(second.downloadedAssets, 0);
      expect(second.reusedAssets, 2);
      expect(api.catalogRequests(), 2);
      expect(api.manifestRequests(), 1);
      expect(api.blobRequests(), 2);
    });

    test('catálogo de assets com versão desconhecida é rejeitado', () async {
      final api = await mockAssetApi(invalidCatalog: true);

      await expectLater(
        serviceWith(api.client).refreshActiveAssets(_pathId),
        throwsA(_assetError(LearningContentAssetErrorCode.invalidCatalog)),
      );

      expect(await db.query('learning_content_asset_manifests'), isEmpty);
      expect(await db.query('learning_content_asset_cache'), isEmpty);
    });

    test('manifesto com bytes diferentes do hash é rejeitado', () async {
      final api = await mockAssetApi(corruptManifestBody: true);

      await expectLater(
        serviceWith(api.client).refreshActiveAssets(_pathId),
        throwsA(
          _assetError(LearningContentAssetErrorCode.manifestHashMismatch),
        ),
      );

      expect(await db.query('learning_content_asset_manifests'), isEmpty);
    });

    test('manifesto não pode referenciar revisão inexistente', () async {
      final api = await mockAssetApi(
        revisionId: 'arrival.vocabulary-01.revision-99',
      );

      await expectLater(
        serviceWith(api.client).refreshActiveAssets(_pathId),
        throwsA(_assetError(LearningContentAssetErrorCode.unknownRevision)),
      );

      expect(await db.query('learning_content_asset_manifests'), isEmpty);
      expect(await db.query('learning_content_asset_cache'), isEmpty);
    });

    test('tipo MIME fora da allowlist é rejeitado antes dos blobs', () async {
      final api = await mockAssetApi(
        imageContentType: 'application/octet-stream',
      );

      await expectLater(
        serviceWith(api.client).refreshActiveAssets(_pathId),
        throwsA(
          _assetError(LearningContentAssetErrorCode.unsupportedContentType),
        ),
      );

      expect(api.blobRequests(), 0);
      expect(await db.query('learning_content_asset_manifests'), isEmpty);
    });

    test('header de blob incoerente impede publicação do manifesto', () async {
      final api = await mockAssetApi(wrongImageHeader: true);

      await expectLater(
        serviceWith(api.client).refreshActiveAssets(_pathId),
        throwsA(_assetError(LearningContentAssetErrorCode.assetHeaderMismatch)),
      );

      expect(await db.query('learning_content_asset_manifests'), isEmpty);
    });

    test(
      'blob adulterado é rejeitado e não substitui cache íntegro anterior',
      () async {
        final goodApi = await mockAssetApi();
        final service = serviceWith(goodApi.client);
        await service.refreshActiveAssets(_pathId);

        final before = await assetRepository.findCachedAsset(goodApi.imageHash);
        expect(before, isNotNull);

        // Corrompe apenas a linha local para obrigar um novo download do mesmo
        // hash; o serviço só escreve depois de validar os novos bytes.
        await db.update(
          'learning_content_asset_cache',
          {
            'bytes': Uint8List.fromList([9, 9, 9, 9, 9]),
          },
          where: 'content_hash = ?',
          whereArgs: [goodApi.imageHash],
        );

        final badApi = await mockAssetApi(corruptImageBody: true);
        await expectLater(
          serviceWith(badApi.client).refreshActiveAssets(_pathId),
          throwsA(_assetError(LearningContentAssetErrorCode.assetHashMismatch)),
        );

        final after = await assetRepository.findCachedAsset(goodApi.imageHash);
        expect(after, isNotNull);
        // A tentativa remota falhou antes do REPLACE; permanece exatamente a
        // linha que existia imediatamente antes da tentativa.
        expect(after!.bytes, orderedEquals([9, 9, 9, 9, 9]));
      },
    );

    test('prune remove órfão mas preserva assets do pacote ativo', () async {
      final api = await mockAssetApi();
      final service = serviceWith(api.client);
      await service.refreshActiveAssets(_pathId);

      final orphanHash = await _sha256Bytes([99, 98, 97]);
      await db.insert('learning_content_asset_cache', {
        'content_hash': orphanHash,
        'content_type': 'image/png',
        'size_bytes': 3,
        'bytes': Uint8List.fromList([99, 98, 97]),
        'source': 'test-orphan',
        'downloaded_at': DateTime.utc(2026, 9, 10).toIso8601String(),
        'last_verified_at': DateTime.utc(2026, 9, 10).toIso8601String(),
        'last_accessed_at': DateTime.utc(2026, 9, 10).toIso8601String(),
      });

      final pruned = await assetRepository.pruneObsolete();

      expect(pruned.removedBlobs, 1);
      expect(await assetRepository.findCachedAsset(orphanHash), isNull);
      expect(await assetRepository.findCachedAsset(api.imageHash), isNotNull);
      expect(await assetRepository.findCachedAsset(api.audioHash), isNotNull);
    });

    test('resolver usa previous apenas para a mesma revisão e role', () async {
      // Recria a base com v1 ativo, associa asset à revision-01 e depois ativa
      // v2. O pacote v1 torna-se previous e pode servir fallback local.
      final v2 = await packageRepository.findPackage(
        learningPathId: _pathId,
        packageVersion: 2,
      );
      expect(v2, isNotNull);

      final v1 = _v1Source();
      await importer.importPackage(
        payloadJson: v1,
        packageVersion: 1,
        source: 'test-v1',
        expectedSha256: await importer.computeSha256(v1),
      );
      await catalogService.activate(learningPathId: _pathId, packageVersion: 1);

      final v1Record = await packageRepository.findPackage(
        learningPathId: _pathId,
        packageVersion: 1,
      );
      const bytes = [31, 32, 33];
      final hash = await _sha256Bytes(bytes);
      final descriptor = LearningContentAssetDescriptor(
        assetId: 'arrival.vocabulary-01.illustration-v1',
        revisionId: _revision1,
        role: 'illustration',
        contentType: 'image/png',
        sha256: hash,
        sizeBytes: bytes.length,
        downloadPath: '/api/content/assets/blobs/$hash',
        required: true,
        sortOrder: 0,
      );
      final manifest = LearningContentAssetManifest(
        manifestVersion: 1,
        learningPathId: _pathId,
        packageVersion: 1,
        assets: [descriptor],
      );
      final manifestJson = jsonEncode({
        'manifestVersion': 1,
        'pathId': _pathId,
        'packageVersion': 1,
        'assets': [
          {
            'assetId': descriptor.assetId,
            'revisionId': descriptor.revisionId,
            'role': descriptor.role,
            'contentType': descriptor.contentType,
            'sha256': descriptor.sha256,
            'sizeBytes': descriptor.sizeBytes,
            'downloadPath': descriptor.downloadPath,
            'required': descriptor.required,
            'sortOrder': descriptor.sortOrder,
          },
        ],
      });
      await assetRepository.storeVerifiedAsset(
        descriptor: descriptor,
        bytes: Uint8List.fromList(bytes),
        source: 'test',
        verifiedAt: DateTime.utc(2026, 9, 10),
      );
      await assetRepository.storeValidatedManifest(
        packageId: v1Record!.id,
        manifestHash: await _sha256Bytes(utf8.encode(manifestJson)),
        manifestJson: manifestJson,
        manifest: manifest,
        importedAt: DateTime.utc(2026, 9, 10),
      );

      await catalogService.activate(learningPathId: _pathId, packageVersion: 2);

      final service = LearningContentAssetService(
        client: MockClient((_) async => http.Response('', 500)),
        repository: assetRepository,
        catalogService: catalogService,
        importService: importer,
      );

      final resolved = await service.resolveAsset(
        learningPathId: _pathId,
        revisionId: _revision1,
        role: 'illustration',
      );

      expect(resolved, isNotNull);
      expect(resolved!.fromPreviousPackage, isTrue);
      expect(resolved.packageVersion, 1);
      expect(resolved.bytes, orderedEquals(bytes));

      final wrongRevision = await service.resolveAsset(
        learningPathId: _pathId,
        revisionId: _revision2,
        role: 'illustration',
      );
      expect(wrongRevision, isNull);
    });
  });
}

Future<void> _importAndActivateV2(
  LearningContentImportService importer,
  LearningContentCatalogService catalogService,
) async {
  final source = _v2Source();
  await importer.importPackage(
    payloadJson: source,
    packageVersion: 2,
    source: 'test-v2',
    expectedSha256: await importer.computeSha256(source),
  );
  await catalogService.activate(learningPathId: _pathId, packageVersion: 2);
}
