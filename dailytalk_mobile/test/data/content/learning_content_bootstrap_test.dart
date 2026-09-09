import 'dart:convert';
import 'dart:io';

import 'package:dailytalk_mobile/data/content/content_data.dart';
import 'package:dailytalk_mobile/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _assetPath = 'assets/content/phase1_example_path.v1.json';

String _v2Source() {
  final package =
      jsonDecode(File(_assetPath).readAsStringSync()) as Map<String, dynamic>;
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

  test('Fase 2.2B bootstrap garante baseline local e é idempotente', () async {
    var assetReads = 0;
    final bootstrap = LearningContentBootstrapService(
      bundledSourceLoader: () async {
        assetReads += 1;
        return File(_assetPath).readAsStringSync();
      },
      importService: importer,
      catalogService: catalogService,
    );

    final first = await bootstrap.ensureLocalBaseline();
    final second = await bootstrap.ensureLocalBaseline();

    expect(first.package.packageVersion, 1);
    expect(second.package.id, first.package.id);
    expect(assetReads, 1);
    expect(await db.query('learning_content_packages'), hasLength(1));
    expect(await db.query('learning_content_catalog'), hasLength(1));
  });

  test(
    'Fase 2.2B bootstrap prefere pacote local mais recente sem downgrade',
    () async {
      final v2 = _v2Source();
      await importer.importPackage(
        payloadJson: v2,
        packageVersion: 2,
        source: 'local-test',
        expectedSha256: await importer.computeSha256(v2),
      );

      var assetReads = 0;
      final bootstrap = LearningContentBootstrapService(
        bundledSourceLoader: () async {
          assetReads += 1;
          return File(_assetPath).readAsStringSync();
        },
        importService: importer,
        catalogService: catalogService,
      );

      final active = await bootstrap.ensureLocalBaseline();

      expect(active.package.packageVersion, 2);
      expect(assetReads, 0);
      expect(await db.query('learning_content_packages'), hasLength(1));
      expect(await db.query('learning_content_catalog'), hasLength(1));
    },
  );
}
