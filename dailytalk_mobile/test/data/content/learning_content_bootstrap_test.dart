import 'dart:convert';
import 'dart:io';

import 'package:dailytalk_mobile/data/content/content_data.dart';
import 'package:dailytalk_mobile/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

String _newerSource(String assetPath, {required int revisionNumber}) {
  final package =
      jsonDecode(File(assetPath).readAsStringSync()) as Map<String, dynamic>;
  final activities = package['activities']! as List<dynamic>;
  final first = activities.first as Map<String, dynamic>;
  final revisions = first['revisions']! as List<dynamic>;
  final revision2 =
      jsonDecode(jsonEncode(revisions.first)) as Map<String, dynamic>;

  revision2['id'] = 'arrival.vocabulary-01.revision-$revisionNumber';
  revision2['revisionNumber'] = revisionNumber;
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
    expect(first.package.packageVersion, 8);
    expect(second.package.id, first.package.id);
    expect(assetReads, 1);
    expect(await db.query('learning_content_packages'), hasLength(1));
    expect(await db.query('learning_content_catalog'), hasLength(1));
  });

  test('bootstrap prefere pacote local mais recente sem downgrade', () async {
    final descriptor = OfficialLearningPathResolver.resolve('it-IT');
    final v9 = _newerSource(descriptor.baselineAssetPath, revisionNumber: 9);
    await importer.importPackage(
      payloadJson: v9,
      packageVersion: 9,
      source: 'local-test',
      expectedSha256: await importer.computeSha256(v9),
    );

    var assetReads = 0;
    final bootstrap = bootstrapWithCounter(() => assetReads += 1);

    final active = await bootstrap.ensureLocalBaseline(
      learningLanguageCode: 'it-IT',
    );

    expect(active.path.id.value, 'student.it-it.phase1');
    expect(active.package.packageVersion, 9);
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

  test('release 8 evolui sobre v7 sem reescrever hist\u00f3rico', () async {
    const previousVersions = <String, int>{
      'pt-PT': 7,
      'en-US': 7,
      'es-ES': 7,
      'fr-FR': 7,
      'it-IT': 7,
      'de-DE': 7,
    };

    for (final entry in previousVersions.entries) {
      final descriptor = OfficialLearningPathResolver.resolve(entry.key);
      final historicalName = entry.key.toLowerCase().replaceAll('-', '_');
      final historicalAsset =
          'assets/content/official_${historicalName}_phase1.v${entry.value}.json';
      final historicalPayload = File(historicalAsset).readAsStringSync();

      await importer.importPackage(
        payloadJson: historicalPayload,
        packageVersion: entry.value,
        source: 'historical-${entry.key}-v${entry.value}-test',
        expectedSha256: await importer.computeSha256(historicalPayload),
      );
      await catalogService.activate(
        learningPathId: descriptor.learningPathId,
        packageVersion: entry.value,
      );

      var assetReads = 0;
      final bootstrap = bootstrapWithCounter(() => assetReads += 1);
      final active = await bootstrap.ensureLocalBaseline(
        learningLanguageCode: entry.key,
      );

      expect(
        active.path.id.value,
        descriptor.learningPathId,
        reason: entry.key,
      );
      expect(active.package.packageVersion, 8, reason: entry.key);
      expect(active.path.schemaVersion.value, 2, reason: entry.key);

      final languageNamespace = descriptor.learningPathId.split('.')[1];
      expect(
        active.path.competencies.map((competency) => competency.id.value),
        everyElement(startsWith('arrival.$languageNamespace.')),
        reason: entry.key,
      );

      expect(assetReads, 1, reason: entry.key);

      final packageRows = await db.query(
        'learning_content_packages',
        columns: <String>['package_version', 'payload_json'],
        where: 'learning_path_id = ?',
        whereArgs: <Object?>[descriptor.learningPathId],
        orderBy: 'package_version ASC',
      );

      expect(
        packageRows.map((row) => row['package_version']).toSet(),
        <Object?>{entry.value, 8},
        reason: '${entry.key} package history',
      );

      final historicalRow = packageRows.singleWhere(
        (row) => row['package_version'] == entry.value,
      );
      expect(
        historicalRow['payload_json'],
        historicalPayload,
        reason: '${entry.key} historical bytes changed',
      );
    }
  });
}
