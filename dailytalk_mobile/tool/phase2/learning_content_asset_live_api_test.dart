import 'dart:io';

import 'package:dailytalk_mobile/data/content/content_data.dart';
import 'package:dailytalk_mobile/data/database/app_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _pathId = 'student.fr-fr.phase1';
const _v1Asset = 'assets/content/phase1_example_path.v1.json';
const _v1Sha256 =
    '6d5bee9037aecaf70773e484076ad646d6b05d7f01bf0f00b8f5a70e798de968';
const _revision2 = 'arrival.vocabulary-01.revision-02';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Gate isolado: flutter_test bloqueia HTTP real por defeito.
  HttpOverrides.global = null;

  late Directory tempDir;
  late Database db;
  late http.Client client;
  late LearningContentPackageRepository packageRepository;
  late LearningContentImportService importer;
  late LearningContentCatalogRepository catalogRepository;
  late LearningContentCatalogService catalogService;
  late LearningContentAssetRepository assetRepository;

  setUpAll(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDownAll(() {
    debugDefaultTargetPlatformOverride = null;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'dailytalk-phase2-assets-live-',
    );
    db = await AppDatabase.instance.openDatabaseForTesting(
      p.join(tempDir.path, 'phase2-assets-live.db'),
    );
    client = http.Client();

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
  });

  tearDown(() async {
    client.close();
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'gate real manifest -> assets -> cache incremental -> leitura offline',
    () async {
      final v1Source = File(_v1Asset).readAsStringSync();
      await importer.importPackage(
        payloadJson: v1Source,
        packageVersion: 1,
        source: 'bundled:$_v1Asset',
        expectedSha256: _v1Sha256,
      );
      await catalogService.activate(learningPathId: _pathId, packageVersion: 1);

      final contentRemote = LearningContentRemoteService(
        client: client,
        importService: importer,
        catalogService: catalogService,
      );
      final contentResult = await contentRemote.refreshLearningPath(_pathId);
      expect(contentResult.active.package.packageVersion, 2);

      final assetService = LearningContentAssetService(
        client: client,
        repository: assetRepository,
        catalogService: catalogService,
        importService: importer,
      );

      final first = await assetService.refreshActiveAssets(_pathId);
      expect(first.metadata.packageVersion, 2);
      expect(first.manifest.manifestVersion, 1);
      expect(first.manifest.assets, hasLength(2));
      expect(first.manifestDownloaded, isTrue);
      expect(first.downloadedAssets, 2);
      expect(first.reusedAssets, 0);

      final second = await assetService.refreshActiveAssets(_pathId);
      expect(second.manifestDownloaded, isFalse);
      expect(second.downloadedAssets, 0);
      expect(second.reusedAssets, 2);

      final cacheRows = await db.query('learning_content_asset_cache');
      expect(cacheRows, hasLength(2));

      // A partir daqui não existe rede: a resolução deve depender apenas da
      // réplica SQLite e dos hashes previamente verificados.
      client.close();

      final illustration = await assetService.resolveAsset(
        learningPathId: _pathId,
        revisionId: _revision2,
        role: 'illustration',
      );
      final pronunciation = await assetService.resolveAsset(
        learningPathId: _pathId,
        revisionId: _revision2,
        role: 'pronunciation',
      );

      expect(illustration, isNotNull);
      expect(illustration!.descriptor.contentType, 'image/png');
      expect(illustration.bytes, isNotEmpty);
      expect(illustration.fromPreviousPackage, isFalse);

      expect(pronunciation, isNotNull);
      expect(pronunciation!.descriptor.contentType, 'audio/wav');
      expect(pronunciation.bytes, isNotEmpty);

      final prune = await assetRepository.pruneObsolete();
      expect(prune.removedManifests, 0);
      expect(prune.removedBlobs, 0);
      expect(await db.query('learning_content_asset_cache'), hasLength(2));
    },
  );
}
