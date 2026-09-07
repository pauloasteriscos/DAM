import 'dart:convert';
import 'dart:io';

import 'package:dailytalk_mobile/data/content/content_data.dart';
import 'package:dailytalk_mobile/data/database/app_database.dart';
import 'package:dailytalk_mobile/domain/learning/learning_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _assetPath = 'assets/content/phase1_example_path.v1.json';
const _pathId = 'student.fr-fr.phase1';

String _v1Source() => File(_assetPath).readAsStringSync();

String _v2Source() {
  final package = jsonDecode(_v1Source()) as Map<String, dynamic>;
  final activities = package['activities']! as List<dynamic>;
  final first = activities.first as Map<String, dynamic>;
  final revisions = first['revisions']! as List<dynamic>;
  final revision1 = revisions.first as Map<String, dynamic>;
  final revision2 = jsonDecode(jsonEncode(revision1)) as Map<String, dynamic>;

  revision2['id'] = 'arrival.vocabulary-01.revision-02';
  revision2['revisionNumber'] = 2;
  revision2['title'] = <String, dynamic>{
    'pt-PT': 'Palavras de acolhimento — edição revista',
  };
  first['currentRevisionId'] = revision2['id'];
  revisions.add(revision2);
  return jsonEncode(package);
}

TypeMatcher<LearningContentCatalogException> _catalogError(
  LearningContentCatalogErrorCode code,
) => isA<LearningContentCatalogException>().having(
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

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'dailytalk-content-catalog-',
    );
    final dbPath = p.join(tempDir.path, 'content-catalog.db');
    db = await AppDatabase.instance.openDatabaseForTesting(dbPath);

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

  Future<LearningContentImportResult> importVersion(
    String source,
    int version,
  ) async {
    return importer.importPackage(
      payloadJson: source,
      packageVersion: version,
      source: 'test',
      expectedSha256: await importer.computeSha256(source),
    );
  }

  group('DailyTalk Fase 2.1C — ativação atómica e fallback', () {
    test('primeira ativação cria catálogo sem versão anterior', () async {
      final imported = await importVersion(_v1Source(), 1);

      final result = await catalogService.activate(
        learningPathId: _pathId,
        packageVersion: 1,
        activatedAt: DateTime.utc(2026, 9, 7, 17),
      );

      expect(result.changed, isTrue);
      expect(result.package.id, imported.package.id);
      expect(result.path.id, LearningPathId(_pathId));
      expect(result.catalog.activePackageId, imported.package.id);
      expect(result.catalog.previousPackageId, isNull);
    });

    test(
      'ativar versão seguinte desloca o ativo anterior atomicamente',
      () async {
        final v1 = await importVersion(_v1Source(), 1);
        final v2 = await importVersion(_v2Source(), 2);
        await catalogService.activate(
          learningPathId: _pathId,
          packageVersion: 1,
        );

        final result = await catalogService.activate(
          learningPathId: _pathId,
          packageVersion: 2,
        );

        expect(result.changed, isTrue);
        expect(result.catalog.activePackageId, v2.package.id);
        expect(result.catalog.previousPackageId, v1.package.id);

        final rows = await db.query('learning_content_catalog');
        expect(rows, hasLength(1));
      },
    );

    test('reativar o mesmo pacote é idempotente e preserva previous', () async {
      final v1 = await importVersion(_v1Source(), 1);
      final v2 = await importVersion(_v2Source(), 2);
      await catalogService.activate(learningPathId: _pathId, packageVersion: 1);
      final firstV2 = await catalogService.activate(
        learningPathId: _pathId,
        packageVersion: 2,
        activatedAt: DateTime.utc(2026, 9, 7, 17, 10),
      );

      final again = await catalogService.activate(
        learningPathId: _pathId,
        packageVersion: 2,
        activatedAt: DateTime.utc(2026, 9, 7, 18),
      );

      expect(again.changed, isFalse);
      expect(again.catalog.activePackageId, v2.package.id);
      expect(again.catalog.previousPackageId, v1.package.id);
      expect(again.catalog.activatedAt, firstV2.catalog.activatedAt);
    });

    test('pacote inexistente é rejeitado sem modificar catálogo', () async {
      final v1 = await importVersion(_v1Source(), 1);
      await catalogService.activate(learningPathId: _pathId, packageVersion: 1);

      await expectLater(
        catalogService.activate(learningPathId: _pathId, packageVersion: 999),
        throwsA(_catalogError(LearningContentCatalogErrorCode.packageNotFound)),
      );

      final catalog = await catalogRepository.findCatalog(_pathId);
      expect(catalog!.activePackageId, v1.package.id);
      expect(catalog.previousPackageId, isNull);
    });

    test('pacote SQLite corrompido não pode ser ativado', () async {
      final v1 = await importVersion(_v1Source(), 1);
      final v2 = await importVersion(_v2Source(), 2);
      await catalogService.activate(learningPathId: _pathId, packageVersion: 1);

      await db.update(
        'learning_content_packages',
        {'payload_json': '{"corrupted":true}'},
        where: 'id = ?',
        whereArgs: [v2.package.id],
      );

      await expectLater(
        catalogService.activate(learningPathId: _pathId, packageVersion: 2),
        throwsA(
          isA<LearningContentImportException>().having(
            (error) => error.code,
            'code',
            LearningContentImportErrorCode.storedPackageCorrupted,
          ),
        ),
      );

      final catalog = await catalogRepository.findCatalog(_pathId);
      expect(catalog!.activePackageId, v1.package.id);
      expect(catalog.previousPackageId, isNull);
    });

    test('loadActive lê normalmente o pacote ativo válido', () async {
      final v1 = await importVersion(_v1Source(), 1);
      await catalogService.activate(learningPathId: _pathId, packageVersion: 1);

      final active = await catalogService.loadActive(_pathId);

      expect(active.recoveredFromFallback, isFalse);
      expect(active.package.id, v1.package.id);
      expect(active.path.id, LearningPathId(_pathId));
    });

    test(
      'corrupção do ativo promove automaticamente a versão anterior válida',
      () async {
        final v1 = await importVersion(_v1Source(), 1);
        final v2 = await importVersion(_v2Source(), 2);
        await catalogService.activate(
          learningPathId: _pathId,
          packageVersion: 1,
        );
        await catalogService.activate(
          learningPathId: _pathId,
          packageVersion: 2,
        );

        await db.update(
          'learning_content_packages',
          {'payload_json': '{"corrupted":true}'},
          where: 'id = ?',
          whereArgs: [v2.package.id],
        );

        final recovered = await catalogService.loadActive(
          _pathId,
          recoveredAt: DateTime.utc(2026, 9, 7, 18),
        );

        expect(recovered.recoveredFromFallback, isTrue);
        expect(recovered.package.id, v1.package.id);
        expect(recovered.catalog.activePackageId, v1.package.id);
        expect(recovered.catalog.previousPackageId, isNull);

        // O pacote falhado não é apagado: fica disponível para diagnóstico.
        expect(
          await packageRepository.findPackage(
            learningPathId: _pathId,
            packageVersion: 2,
          ),
          isNotNull,
        );
      },
    );

    test(
      'sem versão anterior, ativo corrompido falha de forma explícita',
      () async {
        final v1 = await importVersion(_v1Source(), 1);
        await catalogService.activate(
          learningPathId: _pathId,
          packageVersion: 1,
        );
        await db.update(
          'learning_content_packages',
          {'payload_json': '{"corrupted":true}'},
          where: 'id = ?',
          whereArgs: [v1.package.id],
        );

        await expectLater(
          catalogService.loadActive(_pathId),
          throwsA(
            _catalogError(LearningContentCatalogErrorCode.noValidFallback),
          ),
        );
      },
    );

    test(
      'se ativo e anterior estiverem inválidos, nenhum ponteiro é alterado',
      () async {
        final v1 = await importVersion(_v1Source(), 1);
        final v2 = await importVersion(_v2Source(), 2);
        await catalogService.activate(
          learningPathId: _pathId,
          packageVersion: 1,
        );
        await catalogService.activate(
          learningPathId: _pathId,
          packageVersion: 2,
        );

        await db.update(
          'learning_content_packages',
          {'payload_json': '{"bad":1}'},
          where: 'id IN (?, ?)',
          whereArgs: [v1.package.id, v2.package.id],
        );

        await expectLater(
          catalogService.loadActive(_pathId),
          throwsA(
            _catalogError(LearningContentCatalogErrorCode.noValidFallback),
          ),
        );

        final catalog = await catalogRepository.findCatalog(_pathId);
        expect(catalog!.activePackageId, v2.package.id);
        expect(catalog.previousPackageId, v1.package.id);
      },
    );

    test('percurso sem catálogo ativo é distinguido de corrupção', () async {
      await importVersion(_v1Source(), 1);

      await expectLater(
        catalogService.loadActive(_pathId),
        throwsA(_catalogError(LearningContentCatalogErrorCode.noActivePackage)),
      );
    });
  });
}
