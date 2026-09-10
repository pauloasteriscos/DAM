import 'dart:convert';
import 'dart:io';

import 'package:dailytalk_mobile/config/app_config.dart';
import 'package:dailytalk_mobile/data/content/content_data.dart';
import 'package:dailytalk_mobile/data/database/app_database.dart';
import 'package:dailytalk_mobile/domain/learning/learning_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _pathId = 'student.fr-fr.phase1';
const _v2Sha256 =
    'c9f22e0fac4585aa90bb161ac609a3055e3f2fd11d0b16c3537b4c4068d77e0c';
const _v3Sha256 =
    '9fc5142ad80c8e66979c8f3f5f547bb8071c4be09160b03a38cf2374eebb070b';
const _v2Revision = 'arrival.vocabulary-01.revision-02';
const _v3Revision = 'arrival.vocabulary-01.revision-03';

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
      'dailytalk-phase2-reference-journey-',
    );
    db = await AppDatabase.instance.openDatabaseForTesting(
      p.join(tempDir.path, 'phase2-reference-journey.db'),
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
    'gate real v2 -> v3 -> 16 atividades -> assets incrementais -> offline',
    () async {
      // 1) Simula um dispositivo já atualizado para o pacote v2.
      final v2Uri = Uri.parse(
        AppConfig.apiBaseUrl,
      ).resolve('/api/content/packages/$_pathId/2');
      AppConfig.assertApiUri(v2Uri);
      final v2Response = await client.get(
        v2Uri,
        headers: AppConfig.environmentHeaders,
      );
      AppConfig.assertResponseEnvironment(v2Response.headers);
      expect(v2Response.statusCode, 200);
      expect(v2Response.headers['x-content-sha256'], _v2Sha256);

      final v2Source = utf8.decode(v2Response.bodyBytes, allowMalformed: false);
      await importer.importPackage(
        payloadJson: v2Source,
        packageVersion: 2,
        source: 'remote:${v2Uri.path}',
        expectedSha256: _v2Sha256,
      );
      await catalogService.activate(learningPathId: _pathId, packageVersion: 2);

      final assetService = LearningContentAssetService(
        client: client,
        repository: assetRepository,
        catalogService: catalogService,
        importService: importer,
      );
      final v2Assets = await assetService.refreshActiveAssets(_pathId);
      expect(v2Assets.metadata.packageVersion, 2);
      expect(v2Assets.downloadedAssets, 2);
      expect(v2Assets.reusedAssets, 0);

      // 2) Sem recompilar a app, o catálogo remoto promove v2 -> v3.
      final contentRemote = LearningContentRemoteService(
        client: client,
        importService: importer,
        catalogService: catalogService,
      );
      final refreshed = await contentRemote.refreshLearningPath(_pathId);
      expect(refreshed.active.package.packageVersion, 3);
      expect(refreshed.active.package.contentHash, _v3Sha256);
      expect(refreshed.active.path.activities, hasLength(16));
      expect(refreshed.active.path.journeys.single.stages, hasLength(4));

      final vocabulary = refreshed.active.path.activities.singleWhere(
        (activity) => activity.id.value == 'arrival.vocabulary-01',
      );
      expect(vocabulary.revisions, hasLength(3));
      expect(vocabulary.currentRevisionId.value, _v3Revision);

      // 3) O manifesto v3 reutiliza blobs v2 e só descarrega os novos hashes.
      final v3Assets = await assetService.refreshActiveAssets(_pathId);
      expect(v3Assets.metadata.packageVersion, 3);
      expect(v3Assets.manifest.assets, hasLength(8));
      expect(v3Assets.manifestDownloaded, isTrue);
      expect(v3Assets.downloadedAssets, 2);
      expect(v3Assets.reusedAssets, 6);

      final secondV3Assets = await assetService.refreshActiveAssets(_pathId);
      expect(secondV3Assets.manifestDownloaded, isFalse);
      expect(secondV3Assets.downloadedAssets, 0);
      expect(secondV3Assets.reusedAssets, 8);
      expect(await db.query('learning_content_asset_cache'), hasLength(4));

      // 4) O próprio pacote recebido da API alimenta o motor de progressão.
      const engine = DefaultProgressionEngine();
      final initial = engine.evaluate(
        ProgressionRequest(
          learningPath: refreshed.active.path,
          facts: ProgressionFacts(),
          practicePreference: PracticePreference.speech,
        ),
      );
      expect(
        initial
            .decisions[PathElementId('arrival.vocabulary-01.element')]!
            .state,
        LearningActivityState.available,
      );
      expect(
        initial.decisions[PathElementId('arrival.dialogue-01.element')]!.state,
        LearningActivityState.available,
      );
      expect(
        initial.decisions[PathElementId('arrival.speech-01.element')]!.state,
        LearningActivityState.available,
      );
      expect(initial.recommendations.first.value, 'arrival.speech-01.element');

      final finalGate = engine.evaluate(
        ProgressionRequest(
          learningPath: refreshed.active.path,
          facts: ProgressionFacts(
            completedActivities: [
              ActivityId('arrival.quiz-02'),
              ActivityId('arrival.vocabulary-04'),
              ActivityId('arrival.dialogue-04'),
            ],
            achievedCompetencies: [
              CompetencyId('arrival.schedule-basics'),
              CompetencyId('arrival.help-basics'),
            ],
          ),
        ),
      );
      expect(
        finalGate
            .decisions[PathElementId('arrival.integrated-01.element')]!
            .state,
        LearningActivityState.available,
      );
      expect(
        finalGate.decisions[PathElementId('arrival.speech-04.element')]!.state,
        LearningActivityState.available,
      );

      // 5) A partir daqui não existe rede: conteúdo e assets devem continuar
      // a ser resolvidos exclusivamente pela réplica SQLite.
      client.close();

      final offline = await catalogService.loadActive(_pathId);
      expect(offline.package.packageVersion, 3);
      expect(offline.path.activities, hasLength(16));

      final currentIllustration = await assetService.resolveAsset(
        learningPathId: _pathId,
        revisionId: _v3Revision,
        role: 'illustration',
      );
      expect(currentIllustration, isNotNull);
      expect(currentIllustration!.fromPreviousPackage, isFalse);
      expect(currentIllustration.packageVersion, 3);
      expect(currentIllustration.bytes, isNotEmpty);

      final previousIllustration = await assetService.resolveAsset(
        learningPathId: _pathId,
        revisionId: _v2Revision,
        role: 'illustration',
      );
      expect(previousIllustration, isNotNull);
      expect(previousIllustration!.fromPreviousPackage, isTrue);
      expect(previousIllustration.packageVersion, 2);

      final manifests = await db.query('learning_content_asset_manifests');
      expect(manifests, hasLength(2));
      expect(await db.query('learning_content_asset_cache'), hasLength(4));
    },
  );
}
