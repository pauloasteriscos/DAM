import 'dart:io';

import 'package:dailytalk_mobile/data/content/content_data.dart';
import 'package:dailytalk_mobile/data/database/app_database.dart';
import 'package:dailytalk_mobile/data/repositories/learning_progress_read_repository.dart';
import 'package:dailytalk_mobile/data/repositories/learning_progress_repository.dart';
import 'package:dailytalk_mobile/domain/learning/learning_domain.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_read_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _assetPath = 'assets/content/phase1_example_path.v1.json';
const _accountId = 'phase41e3-offline-account';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Database db;
  late LearningContentPackageRepository packageRepository;
  late LearningContentImportService importService;
  late LearningContentCatalogRepository catalogRepository;
  late LearningContentCatalogService catalogService;
  late LearningContentBootstrapService bootstrap;
  late int assetReads;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'dailytalk-learning-map-e3-',
    );

    db = await AppDatabase.instance.openDatabaseForTesting(
      p.join(tempDir.path, 'learning-map-e3.db'),
    );

    packageRepository = LearningContentPackageRepository(
      databaseProvider: () async => db,
    );

    importService = LearningContentImportService(repository: packageRepository);

    catalogRepository = LearningContentCatalogRepository(
      databaseProvider: () async => db,
    );

    catalogService = LearningContentCatalogService(
      catalogRepository: catalogRepository,
      packageRepository: packageRepository,
      importService: importService,
    );

    assetReads = 0;

    bootstrap = LearningContentBootstrapService(
      bundledSourceLoader: () async {
        assetReads += 1;
        return File(_assetPath).readAsStringSync();
      },
      importService: importService,
      catalogService: catalogService,
    );
  });

  tearDown(() async {
    if (db.isOpen) {
      await db.close();
    }

    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    '4.1E.3 real SQLite composes official content into LearningMapViewModel',
    () async {
      expect(await db.query('learning_content_packages'), isEmpty);
      expect(await db.query('learning_content_catalog'), isEmpty);
      expect(await db.query('learning_progress_projection'), isEmpty);

      final active = await bootstrap.ensureLocalBaseline();

      expect(
        active.path.id.value,
        LearningContentBootstrapService.officialLearningPathId,
      );

      expect(
        active.package.packageVersion,
        LearningContentBootstrapService.officialBaselinePackageVersion,
      );

      expect(active.recoveredFromFallback, isFalse);
      expect(assetReads, 1);

      expect(await db.query('learning_content_packages'), hasLength(1));

      expect(await db.query('learning_content_catalog'), hasLength(1));

      final progressRepository = LearningProgressRepository(db);

      final rebuilt = await progressRepository.ensureProjection(
        accountId: _accountId,
        learningPath: active.path,
        activePackageVersion: active.package.packageVersion,
      );

      expect(rebuilt, isTrue);

      final expectedElementCount = active.path.journeys
          .expand((journey) => journey.stages)
          .expand((stage) => stage.elements)
          .length;

      final expectedActivityCount = active.path.journeys
          .expand((journey) => journey.stages)
          .expand((stage) => stage.elements)
          .where((element) => element.activityId != null)
          .length;

      final projectionRows = await db.query(
        'learning_progress_projection',
        where: 'account_id = ? AND learning_path_id = ?',
        whereArgs: <Object?>[_accountId, active.path.id.value],
      );

      expect(projectionRows, hasLength(expectedElementCount));

      expect(
        projectionRows.every(
          (row) => row['package_version'] == active.package.packageVersion,
        ),
        isTrue,
      );

      expect(await db.query('sync_queue'), isEmpty);

      final progressReadRepository = LearningProgressReadRepository(db);

      final readService = LearningMapReadService.fromRepositories(
        catalogService: catalogService,
        progressRepository: progressReadRepository,
      );

      final model = await readService.load(
        accountId: _accountId,
        learningPathId: active.path.id.value,
        locale: 'pt-PT',
      );

      expect(model.learningPathId, active.path.id.value);
      expect(model.packageVersion, active.package.packageVersion);
      expect(model.recoveredFromFallback, isFalse);
      expect(model.locale, 'pt-PT');
      expect(model.title, isNotEmpty);

      expect(model.elements, hasLength(expectedElementCount));
      expect(model.totalActivityCount, expectedActivityCount);
      expect(model.completedActivityCount, 0);
      expect(model.completionRatio, 0.0);

      expect(
        model.elements.any(
          (element) =>
              element.activityId != null &&
              element.state == LearningActivityState.available,
        ),
        isTrue,
      );

      final next = model.nextRecommendedElement;

      expect(next, isNotNull);
      expect(next!.activityId, isNotNull);
      expect(next.state, LearningActivityState.available);
      expect(next.syncState, ProgressSyncState.clean);
      expect(next.recommendationRank, 0);
      expect(next.isPrimaryRecommendation, isTrue);

      expect(await db.query('learning_progress_completions'), isEmpty);
      expect(await db.query('sync_queue'), isEmpty);

      // Reading the map uses the already active SQLite catalog.
      // It must not read the bundled source a second time.
      expect(assetReads, 1);
    },
  );
}
