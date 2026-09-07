import 'dart:convert';
import 'dart:io';

import 'package:dailytalk_mobile/data/content/content_data.dart';
import 'package:dailytalk_mobile/data/database/app_database.dart';
import 'package:dailytalk_mobile/domain/learning/learning_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _assetPath = 'assets/content/phase1_example_path.v1.json';
const _officialV1Sha256 =
    '6d5bee9037aecaf70773e484076ad646d6b05d7f01bf0f00b8f5a70e798de968';
const _pathId = 'student.fr-fr.phase1';

String _v1Source() => File(_assetPath).readAsStringSync();

String _v2SourceWithNewRevision() {
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

String _sourceWithMutatedPublishedRevision() {
  final package = jsonDecode(_v1Source()) as Map<String, dynamic>;
  final activities = package['activities']! as List<dynamic>;
  final first = activities.first as Map<String, dynamic>;
  final revisions = first['revisions']! as List<dynamic>;
  final revision = revisions.first as Map<String, dynamic>;
  revision['title'] = <String, dynamic>{
    'pt-PT': 'Conteúdo alterado indevidamente',
  };
  return jsonEncode(package);
}

TypeMatcher<LearningContentImportException> _importError(
  LearningContentImportErrorCode code,
) => isA<LearningContentImportException>().having(
  (error) => error.code,
  'code',
  code,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Database db;
  late LearningContentPackageRepository repository;
  late LearningContentImportService service;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'dailytalk-content-import-',
    );
    final dbPath = p.join(tempDir.path, 'content-import.db');
    db = await AppDatabase.instance.openDatabaseForTesting(dbPath);
    repository = LearningContentPackageRepository(
      databaseProvider: () async => db,
    );
    service = LearningContentImportService(repository: repository);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('DailyTalk Fase 2.1B — importação e integridade', () {
    test(
      'importa pacote oficial v1 com SHA-256 e persiste bytes exatos',
      () async {
        final result = await service.importPackage(
          payloadJson: _v1Source(),
          packageVersion: 1,
          source: 'bundled-test',
          expectedSha256: _officialV1Sha256,
          importedAt: DateTime.utc(2026, 9, 7, 16),
        );

        expect(result.inserted, isTrue);
        expect(result.path.id, LearningPathId(_pathId));
        expect(result.package.schemaVersion, 1);
        expect(result.package.contentHash, _officialV1Sha256);
        expect(result.package.source, 'bundled-test');

        final rows = await db.query('learning_content_packages');
        expect(rows, hasLength(1));
        expect(rows.single['learning_path_id'], _pathId);
        expect(rows.single['package_version'], 1);
        expect(rows.single['payload_json'], _v1Source());

        // 2.1B importa, mas deliberadamente não ativa.
        expect(await db.query('learning_content_catalog'), isEmpty);
      },
    );

    test('reimportar exatamente o mesmo pacote é idempotente', () async {
      final source = _v1Source();
      final first = await service.importPackage(
        payloadJson: source,
        packageVersion: 1,
        source: 'bundled-test',
        expectedSha256: await service.computeSha256(source),
      );
      final second = await service.importPackage(
        payloadJson: source,
        packageVersion: 1,
        source: 'remote-test',
        expectedSha256: await service.computeSha256(source),
      );

      expect(first.inserted, isTrue);
      expect(second.inserted, isFalse);
      expect(second.package.id, first.package.id);
      expect(await db.query('learning_content_packages'), hasLength(1));
      expect(await db.query('learning_content_catalog'), isEmpty);
    });

    test('packageVersion inválida é rejeitada antes de escrever', () async {
      await expectLater(
        service.importPackage(
          payloadJson: _v1Source(),
          packageVersion: 0,
          source: 'remote-test',
          expectedSha256: _officialV1Sha256,
        ),
        throwsA(
          _importError(LearningContentImportErrorCode.invalidPackageVersion),
        ),
      );

      expect(await db.query('learning_content_packages'), isEmpty);
    });

    test('hash esperado malformado é rejeitado antes de escrever', () async {
      await expectLater(
        service.importPackage(
          payloadJson: _v1Source(),
          packageVersion: 1,
          source: 'remote-test',
          expectedSha256: 'not-a-sha256',
        ),
        throwsA(
          _importError(LearningContentImportErrorCode.invalidExpectedHash),
        ),
      );

      expect(await db.query('learning_content_packages'), isEmpty);
    });

    test('hash divergente rejeita pacote antes de escrever', () async {
      await expectLater(
        service.importPackage(
          payloadJson: _v1Source(),
          packageVersion: 1,
          source: 'remote-test',
          expectedSha256:
              '0000000000000000000000000000000000000000000000000000000000000000',
        ),
        throwsA(_importError(LearningContentImportErrorCode.hashMismatch)),
      );

      expect(await db.query('learning_content_packages'), isEmpty);
      expect(await db.query('learning_content_catalog'), isEmpty);
    });

    test('pacote estruturalmente inválido nunca é persistido', () async {
      final package = jsonDecode(_v1Source()) as Map<String, dynamic>;
      package['schemaVersion'] = 999;
      final invalidSource = jsonEncode(package);

      await expectLater(
        service.importPackage(
          payloadJson: invalidSource,
          packageVersion: 1,
          source: 'remote-test',
          expectedSha256: await service.computeSha256(invalidSource),
        ),
        throwsA(isA<LearningContentException>()),
      );

      expect(await db.query('learning_content_packages'), isEmpty);
    });

    test(
      'mesma packageVersion não pode ser reutilizada com outro hash',
      () async {
        final source = _v1Source();
        await service.importPackage(
          payloadJson: source,
          packageVersion: 1,
          source: 'bundled-test',
          expectedSha256: await service.computeSha256(source),
        );

        final package = jsonDecode(source) as Map<String, dynamic>;
        package['title'] = <String, dynamic>{
          'pt-PT': 'Outro título do percurso',
        };
        final conflictingSource = jsonEncode(package);

        await expectLater(
          service.importPackage(
            payloadJson: conflictingSource,
            packageVersion: 1,
            source: 'remote-test',
            expectedSha256: await service.computeSha256(conflictingSource),
          ),
          throwsA(_importError(LearningContentImportErrorCode.versionConflict)),
        );

        expect(await db.query('learning_content_packages'), hasLength(1));
      },
    );

    test('RevisionId já publicado não pode mudar de conteúdo', () async {
      final source = _v1Source();
      await service.importPackage(
        payloadJson: source,
        packageVersion: 1,
        source: 'bundled-test',
        expectedSha256: await service.computeSha256(source),
      );

      final mutatedSource = _sourceWithMutatedPublishedRevision();
      await expectLater(
        service.importPackage(
          payloadJson: mutatedSource,
          packageVersion: 2,
          source: 'remote-test',
          expectedSha256: await service.computeSha256(mutatedSource),
        ),
        throwsA(
          _importError(
            LearningContentImportErrorCode.immutableRevisionConflict,
          ),
        ),
      );

      expect(await db.query('learning_content_packages'), hasLength(1));
    });

    test(
      'nova revisão imutável pode ser importada em packageVersion seguinte',
      () async {
        final v1 = _v1Source();
        final v2 = _v2SourceWithNewRevision();

        await service.importPackage(
          payloadJson: v1,
          packageVersion: 1,
          source: 'bundled-test',
          expectedSha256: await service.computeSha256(v1),
        );
        final result = await service.importPackage(
          payloadJson: v2,
          packageVersion: 2,
          source: 'remote-test',
          expectedSha256: await service.computeSha256(v2),
        );

        expect(result.inserted, isTrue);
        expect(
          result.path.activities.first.currentRevisionId,
          RevisionId('arrival.vocabulary-01.revision-02'),
        );
        expect(await repository.listPackages(_pathId), hasLength(2));
        expect(await db.query('learning_content_catalog'), isEmpty);
      },
    );
  });
}
