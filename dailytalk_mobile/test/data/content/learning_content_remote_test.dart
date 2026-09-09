import 'dart:convert';
import 'dart:io';

import 'package:dailytalk_mobile/data/content/content_data.dart';
import 'package:dailytalk_mobile/data/database/app_database.dart';
import 'package:dailytalk_mobile/domain/learning/learning_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

TypeMatcher<LearningContentRemoteException> _remoteError(
  LearningContentRemoteErrorCode code,
) => isA<LearningContentRemoteException>().having(
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
      'dailytalk-content-remote-',
    );
    db = await AppDatabase.instance.openDatabaseForTesting(
      p.join(tempDir.path, 'content-remote.db'),
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

  Future<void> importAndActivate(String source, int version) async {
    await importer.importPackage(
      payloadJson: source,
      packageVersion: version,
      source: 'local-test',
      expectedSha256: await importer.computeSha256(source),
    );
    await catalogService.activate(
      learningPathId: _pathId,
      packageVersion: version,
    );
  }

  Future<({MockClient client, int Function() packageRequests})>
  mockOfficialApi({
    required String payload,
    required int packageVersion,
    String? catalogHash,
    String? packageHashHeader,
    int schemaVersion = 1,
    bool validCatalog = true,
  }) async {
    final payloadBytes = utf8.encode(payload);
    final hash = catalogHash ?? await importer.computeSha256(payload);
    var downloadCount = 0;

    final client = MockClient((request) async {
      if (request.url.path == '/api/content/catalog') {
        return http.Response(
          validCatalog
              ? jsonEncode({
                  'success': true,
                  'catalogVersion': 1,
                  'packages': [
                    {
                      'pathId': _pathId,
                      'schemaVersion': schemaVersion,
                      'packageVersion': packageVersion,
                      'sha256': hash,
                      'sizeBytes': payloadBytes.length,
                      'contentType': 'application/json',
                      'downloadPath':
                          '/api/content/packages/$_pathId/$packageVersion',
                      'immutable': true,
                    },
                  ],
                })
              : '{"success":true,"catalogVersion":999,"packages":[]}',
          200,
          headers: {'x-dailytalk-environment': 'DEV'},
        );
      }

      if (request.url.path ==
          '/api/content/packages/$_pathId/$packageVersion') {
        downloadCount += 1;
        return http.Response.bytes(
          payloadBytes,
          200,
          headers: {
            'x-dailytalk-environment': 'DEV',
            'content-type': 'application/json; charset=utf-8',
            'x-content-sha256': packageHashHeader ?? hash,
            'x-content-package-version': packageVersion.toString(),
            'x-content-schema-version': schemaVersion.toString(),
            'etag': '"sha256-$hash"',
          },
        );
      }

      return http.Response(
        '{"error":"not found"}',
        404,
        headers: {'x-dailytalk-environment': 'DEV'},
      );
    });

    return (client: client, packageRequests: () => downloadCount);
  }

  LearningContentRemoteService remoteWith(http.Client client) {
    return LearningContentRemoteService(
      client: client,
      importService: importer,
      catalogService: catalogService,
    );
  }

  group('DailyTalk Fase 2.2B — atualização remota no Flutter', () {
    test('descarrega, valida, importa e ativa pacote oficial', () async {
      final api = await mockOfficialApi(
        payload: _v1Source(),
        packageVersion: 1,
      );
      final result = await remoteWith(api.client).refreshLearningPath(_pathId);

      expect(
        result.status,
        LearningContentRefreshStatus.downloadedAndActivated,
      );
      expect(result.downloaded, isTrue);
      expect(result.active.package.packageVersion, 1);
      expect(result.active.path.id, LearningPathId(_pathId));
      expect(api.packageRequests(), 1);
      expect(await db.query('learning_content_packages'), hasLength(1));
      expect(await db.query('learning_content_catalog'), hasLength(1));
    });

    test(
      'segunda verificação da mesma versão não volta a descarregar',
      () async {
        final api = await mockOfficialApi(
          payload: _v1Source(),
          packageVersion: 1,
        );
        final remote = remoteWith(api.client);

        await remote.refreshLearningPath(_pathId);
        final second = await remote.refreshLearningPath(_pathId);

        expect(second.status, LearningContentRefreshStatus.alreadyCurrent);
        expect(second.downloaded, isFalse);
        expect(api.packageRequests(), 1);
        expect(await db.query('learning_content_packages'), hasLength(1));
      },
    );

    test(
      'versão remota seguinte torna-se ativa e preserva a anterior',
      () async {
        final v1 = _v1Source();
        final v2 = _v2Source();
        await importAndActivate(v1, 1);

        final api = await mockOfficialApi(payload: v2, packageVersion: 2);
        final result = await remoteWith(
          api.client,
        ).refreshLearningPath(_pathId);

        expect(result.active.package.packageVersion, 2);
        expect(result.downloaded, isTrue);

        final catalog = await catalogRepository.findCatalog(_pathId);
        final previous = await packageRepository.findPackageById(
          id: catalog!.previousPackageId!,
          learningPathId: _pathId,
        );
        expect(previous!.packageVersion, 1);
        expect(await packageRepository.listPackages(_pathId), hasLength(2));
      },
    );

    test(
      'bytes com SHA-256 divergente são rejeitados sem trocar o ativo',
      () async {
        await importAndActivate(_v1Source(), 1);
        final goodV2 = _v2Source();
        final goodHash = await importer.computeSha256(goodV2);
        final corruptedV2 = goodV2.replaceFirst('Palavras', 'Xalavras');
        expect(utf8.encode(corruptedV2), hasLength(utf8.encode(goodV2).length));

        final api = await mockOfficialApi(
          payload: corruptedV2,
          packageVersion: 2,
          catalogHash: goodHash,
          packageHashHeader: goodHash,
        );

        await expectLater(
          remoteWith(api.client).refreshLearningPath(_pathId),
          throwsA(
            _remoteError(LearningContentRemoteErrorCode.packageHashMismatch),
          ),
        );

        final active = await catalogService.loadActive(_pathId);
        expect(active.package.packageVersion, 1);
        expect(await packageRepository.listPackages(_pathId), hasLength(1));
      },
    );

    test('headers incoerentes são rejeitados antes da importação', () async {
      await importAndActivate(_v1Source(), 1);
      final v2 = _v2Source();
      final api = await mockOfficialApi(
        payload: v2,
        packageVersion: 2,
        packageHashHeader:
            '0000000000000000000000000000000000000000000000000000000000000000',
      );

      await expectLater(
        remoteWith(api.client).refreshLearningPath(_pathId),
        throwsA(
          _remoteError(LearningContentRemoteErrorCode.packageHeaderMismatch),
        ),
      );

      expect(
        (await catalogService.loadActive(_pathId)).package.packageVersion,
        1,
      );
      expect(await packageRepository.listPackages(_pathId), hasLength(1));
    });

    test(
      'JSON remoto inválido nunca substitui a última versão válida',
      () async {
        await importAndActivate(_v1Source(), 1);
        const invalidPackage = '{"schemaVersion":999,"id":"broken"}';
        final api = await mockOfficialApi(
          payload: invalidPackage,
          packageVersion: 2,
          schemaVersion: 999,
        );

        await expectLater(
          remoteWith(api.client).refreshLearningPath(_pathId),
          throwsA(isA<LearningContentException>()),
        );

        final active = await catalogService.loadActive(_pathId);
        expect(active.package.packageVersion, 1);
        expect(await packageRepository.listPackages(_pathId), hasLength(1));
      },
    );

    test(
      'catálogo com contrato não suportado é rejeitado antes de escrever',
      () async {
        final api = await mockOfficialApi(
          payload: _v1Source(),
          packageVersion: 1,
          validCatalog: false,
        );

        await expectLater(
          remoteWith(api.client).refreshLearningPath(_pathId),
          throwsA(_remoteError(LearningContentRemoteErrorCode.invalidCatalog)),
        );

        expect(await db.query('learning_content_packages'), isEmpty);
        expect(await db.query('learning_content_catalog'), isEmpty);
      },
    );

    test(
      'catálogo remoto atrasado nunca faz downgrade do conteúdo ativo',
      () async {
        await importAndActivate(_v1Source(), 1);
        await importer.importPackage(
          payloadJson: _v2Source(),
          packageVersion: 2,
          source: 'local-test',
          expectedSha256: await importer.computeSha256(_v2Source()),
        );
        await catalogService.activate(
          learningPathId: _pathId,
          packageVersion: 2,
        );

        final api = await mockOfficialApi(
          payload: _v1Source(),
          packageVersion: 1,
        );
        final result = await remoteWith(
          api.client,
        ).refreshLearningPath(_pathId);

        expect(result.status, LearningContentRefreshStatus.ignoredStaleRemote);
        expect(result.active.package.packageVersion, 2);
        expect(api.packageRequests(), 0);
      },
    );

    test(
      'falha de rede não remove o conteúdo local utilizável offline',
      () async {
        await importAndActivate(_v1Source(), 1);
        final client = MockClient((_) async {
          throw SocketException('offline');
        });

        await expectLater(
          remoteWith(client).refreshLearningPath(_pathId),
          throwsA(isA<SocketException>()),
        );

        final offline = await catalogService.loadActive(_pathId);
        expect(offline.package.packageVersion, 1);
        expect(offline.path.id, LearningPathId(_pathId));
      },
    );
  });
}
