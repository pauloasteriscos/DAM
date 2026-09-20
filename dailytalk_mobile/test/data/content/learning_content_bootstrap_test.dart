import 'dart:convert';
import 'dart:io';

import 'package:dailytalk_mobile/data/content/content_data.dart';
import 'package:dailytalk_mobile/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

String _newerSource(String assetPath) {
  final package =
      jsonDecode(File(assetPath).readAsStringSync()) as Map<String, dynamic>;
  final activities = package['activities']! as List<dynamic>;
  final first = activities.first as Map<String, dynamic>;
  final revisions = first['revisions']! as List<dynamic>;
  final revision2 =
      jsonDecode(jsonEncode(revisions.first)) as Map<String, dynamic>;

  revision2['id'] = 'arrival.vocabulary-01.revision-02';
  revision2['revisionNumber'] = 2;
  revision2['title'] = <String, dynamic>{
    'pt-PT': 'Palavras de acolhimento — edição revista',
  };
  first['currentRevisionId'] = revision2['id'];
  revisions.add(revision2);
  return jsonEncode(package);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Database db;
  late LearningContentPackageRepository packageRepository;
  late LearningContentImportService importer;
  late LearningContentCatalogRepository catalogRepository;
  late LearningContentCatalogService catalogService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'dailytalk-content-bootstrap-',
    );
    db = await AppDatabase.instance.openDatabaseForTesting(
      p.join(tempDir.path, 'content-bootstrap.db'),
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
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  LearningContentBootstrapService bootstrapWithCounter(
    void Function() onAssetRead,
  ) {
    return LearningContentBootstrapService(
      bundledSourceLoader: (assetPath) async {
        onAssetRead();
        return File(assetPath).readAsStringSync();
      },
      importService: importer,
      catalogService: catalogService,
    );
  }

  test('bootstrap garante baseline italiana local e é idempotente', () async {
    var assetReads = 0;
    final bootstrap = bootstrapWithCounter(() => assetReads += 1);

    final first = await bootstrap.ensureLocalBaseline(
      learningLanguageCode: 'it-IT',
    );
    final second = await bootstrap.ensureLocalBaseline(
      learningLanguageCode: 'it-IT',
    );

    expect(first.path.id.value, 'student.it-it.phase1');
    expect(first.package.packageVersion, 1);
    expect(second.package.id, first.package.id);
    expect(assetReads, 1);
    expect(await db.query('learning_content_packages'), hasLength(1));
    expect(await db.query('learning_content_catalog'), hasLength(1));
  });

  test('bootstrap prefere pacote local mais recente sem downgrade', () async {
    final descriptor = OfficialLearningPathResolver.resolve('it-IT');
    final v2 = _newerSource(descriptor.baselineAssetPath);
    await importer.importPackage(
      payloadJson: v2,
      packageVersion: 2,
      source: 'local-test',
      expectedSha256: await importer.computeSha256(v2),
    );

    var assetReads = 0;
    final bootstrap = bootstrapWithCounter(() => assetReads += 1);

    final active = await bootstrap.ensureLocalBaseline(
      learningLanguageCode: 'it-IT',
    );

    expect(active.path.id.value, 'student.it-it.phase1');
    expect(active.package.packageVersion, 2);
    expect(assetReads, 0);
    expect(await db.query('learning_content_packages'), hasLength(1));
    expect(await db.query('learning_content_catalog'), hasLength(1));
  });

  test('idiomas diferentes mantêm catálogos ativos separados', () async {
    var assetReads = 0;
    final bootstrap = bootstrapWithCounter(() => assetReads += 1);

    final italian = await bootstrap.ensureLocalBaseline(
      learningLanguageCode: 'it-IT',
    );
    final french = await bootstrap.ensureLocalBaseline(
      learningLanguageCode: 'fr-FR',
    );

    expect(italian.path.id.value, 'student.it-it.phase1');
    expect(french.path.id.value, 'student.fr-fr.phase1');
    expect(
      italian.package.learningPathId,
      isNot(french.package.learningPathId),
    );
    expect(assetReads, 2);

    final catalogs = await db.query(
      'learning_content_catalog',
      orderBy: 'learning_path_id ASC',
    );
    expect(catalogs, hasLength(2));
    expect(catalogs.map((row) => row['learning_path_id']).toSet(), <Object?>{
      'student.fr-fr.phase1',
      'student.it-it.phase1',
    });
  });

  test(
    'baseline francesa v5 evolui sobre v4 sem reescrever histórico',
    () async {
      const historicalAsset = 'assets/content/official_fr_fr_phase1.v4.json';
      final historicalPayload = File(historicalAsset).readAsStringSync();

      await importer.importPackage(
        payloadJson: historicalPayload,
        packageVersion: 4,
        source: 'historical-fr-v4-test',
        expectedSha256: await importer.computeSha256(historicalPayload),
      );
      await catalogService.activate(
        learningPathId: 'student.fr-fr.phase1',
        packageVersion: 4,
      );

      var assetReads = 0;
      final bootstrap = bootstrapWithCounter(() => assetReads += 1);
      final active = await bootstrap.ensureLocalBaseline(
        learningLanguageCode: 'fr-FR',
      );

      expect(active.path.id.value, 'student.fr-fr.phase1');
      expect(active.package.packageVersion, 5);
      expect(active.path.schemaVersion.value, 2);
      expect(
        active.path.activities.every(
          (activity) =>
              activity.currentRevisionId.value.endsWith('.revision-05') &&
              activity.revisions.length == 1 &&
              activity.currentRevision.revisionNumber == 5,
        ),
        isTrue,
      );
      expect(
        active.path.competencies.map((competency) => competency.id.value),
        everyElement(startsWith('arrival.fr-fr.')),
      );
      expect(assetReads, 1);
    },
  );
}
