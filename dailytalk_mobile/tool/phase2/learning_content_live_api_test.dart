import 'dart:convert';
import 'dart:io';

import 'package:dailytalk_mobile/data/content/content_data.dart';
import 'package:dailytalk_mobile/data/database/app_database.dart';
import 'package:dailytalk_mobile/domain/learning/learning_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _pathId = 'student.fr-fr.phase1';
const _v1Asset = 'assets/content/phase1_example_path.v1.json';
const _v1Sha256 =
    '6d5bee9037aecaf70773e484076ad646d6b05d7f01bf0f00b8f5a70e798de968';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Este gate é deliberadamente de integração com um Worker DEV real.
  // O flutter_test instala um HttpOverrides que devolve HTTP 400 para impedir
  // rede real em testes comuns; aqui removemos apenas esse override no processo
  // isolado do gate para exercitar 127.0.0.1:8787 de ponta a ponta.
  HttpOverrides.global = null;

  late Directory tempDir;
  late Database db;
  late http.Client client;
  late LearningContentPackageRepository packageRepository;
  late LearningContentImportService importer;
  late LearningContentCatalogRepository catalogRepository;
  late LearningContentCatalogService catalogService;

  setUpAll(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDownAll(() {
    debugDefaultTargetPlatformOverride = null;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dailytalk-phase2-live-');
    db = await AppDatabase.instance.openDatabaseForTesting(
      p.join(tempDir.path, 'phase2-live.db'),
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
  });

  tearDown(() async {
    client.close();
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('gate real API v2 -> Flutter -> SQLite -> leitura offline', () async {
    final v1Source = File(_v1Asset).readAsStringSync();
    await importer.importPackage(
      payloadJson: v1Source,
      packageVersion: 1,
      source: 'bundled:$_v1Asset',
      expectedSha256: _v1Sha256,
    );
    await catalogService.activate(learningPathId: _pathId, packageVersion: 1);

    expect(
      (await catalogService.loadActive(_pathId)).package.packageVersion,
      1,
    );

    final remote = LearningContentRemoteService(
      client: client,
      importService: importer,
      catalogService: catalogService,
    );
    final result = await remote.refreshLearningPath(_pathId);

    expect(result.status, LearningContentRefreshStatus.downloadedAndActivated);
    expect(result.active.package.packageVersion, 2);

    final vocabulary = result.active.path.activities.firstWhere(
      (activity) => activity.id == ActivityId('arrival.vocabulary-01'),
    );
    expect(
      vocabulary.currentRevisionId,
      RevisionId('arrival.vocabulary-01.revision-02'),
    );
    expect(
      vocabulary.currentRevision.title.resolve(
        'pt-PT',
        fallbackLocale: 'pt-PT',
      ),
      'Palavras de acolhimento — edição revista',
    );

    final catalog = await catalogRepository.findCatalog(_pathId);
    expect(catalog, isNotNull);
    expect(catalog!.previousPackageId, isNotNull);

    final previous = await packageRepository.findPackageById(
      id: catalog.previousPackageId!,
      learningPathId: _pathId,
    );
    expect(previous, isNotNull);
    expect(previous!.packageVersion, 1);

    // A fronteira HTTP deixa de ser necessária depois da ativação. Fechar o
    // cliente simula indisponibilidade da rede para a leitura de aprendizagem.
    client.close();
    final offline = await catalogService.loadActive(_pathId);
    expect(offline.package.packageVersion, 2);
    expect(
      jsonDecode(offline.package.payloadJson),
      isA<Map<String, dynamic>>(),
    );
  });
}
