import 'dart:io';

import 'package:dailytalk_mobile/data/database/app_database.dart';
import 'package:dailytalk_mobile/data/repositories/learning_progress_repository.dart';
import 'package:dailytalk_mobile/domain/learning/learning_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _referencePath =
    '../dailytalk-api/docs/phase2/official_reference_journey_v3.json';

LearningPath _loadReferenceJourney() {
  final source = File(_referencePath).readAsStringSync();
  return const LearningContentCodec().decodeString(source);
}

RemoteLearningCompletionFact _remoteFact(
  LearningPath learningPath, {
  String serverCompletionId = 'server-completion-0001',
  String clientCompletionId = 'device-b-completion-0001',
  String activityId = 'arrival.dialogue-01',
  RevisionId? revisionId,
  int packageVersion = 3,
  DateTime? completedAt,
}) {
  final activity = learningPath.activities.singleWhere(
    (candidate) => candidate.id.value == activityId,
  );

  return RemoteLearningCompletionFact(
    serverCompletionId: serverCompletionId,
    clientCompletionId: clientCompletionId,
    learningPathId: learningPath.id.value,
    activityId: activity.id,
    revisionId: revisionId ?? activity.currentRevisionId,
    packageVersion: packageVersion,
    completedAt: completedAt ?? DateTime.utc(2026, 9, 13, 10),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  Database? db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dailytalk-remote-merge-');
  });

  tearDown(() async {
    final current = db;

    if (current != null && current.isOpen) {
      await current.close();
    }

    db = null;

    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'Fase 3.5B2 — v6 para esquema atual cria estado de cursor sem destruir settings',
    () async {
      final path = p.join(tempDir.path, 'migration-v6-current.db');

      db = await openDatabase(
        path,
        version: 6,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE app_settings (
              key TEXT PRIMARY KEY,
              value TEXT,
              value_type TEXT NOT NULL DEFAULT 'text',
              updated_at TEXT NOT NULL
            )
          ''');

          await database.insert('app_settings', <String, Object?>{
            'key': 'sentinel',
            'value': 'preserve',
            'value_type': 'text',
            'updated_at': '2026-09-13T10:00:00.000Z',
          });
        },
      );

      await db!.close();
      db = null;

      db = await AppDatabase.instance.openDatabaseForTesting(path);

      final tables = await db!.rawQuery('''
        SELECT name
        FROM sqlite_master
        WHERE type = 'table'
          AND name = 'learning_progress_sync_state'
        ''');

      expect(tables, hasLength(1));

      final sentinel = await db!.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: const <Object?>['sentinel'],
      );

      expect(sentinel, hasLength(1));
      expect(sentinel.single['value'], 'preserve');

      final version = await db!.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: const <Object?>['database_version'],
      );

      expect(version.single['value'], '8');

      final pragma = await db!.rawQuery('PRAGMA user_version');
      expect(pragma.single['user_version'], 8);
    },
  );

  test(
    'Fase 3.5B2 — conclusão remota gera facto, evidência, projeção e cursor sem outbox',
    () async {
      final learningPath = _loadReferenceJourney();
      final path = p.join(tempDir.path, 'remote-merge.db');

      db = await AppDatabase.instance.openDatabaseForTesting(path);

      final repository = LearningProgressRepository(db!);
      final fact = _remoteFact(learningPath);

      final result = await repository.mergeRemoteProgress(
        MergeRemoteLearningProgressWrite(
          accountId: 'user-phase3',
          learningPath: learningPath,
          activePackageVersion: 3,
          expectedCursor: null,
          nextCursor: fact.serverCompletionId,
          completions: <RemoteLearningCompletionFact>[fact],
        ),
      );

      expect(result.insertedCount, 1);
      expect(result.duplicateCount, 0);
      expect(result.cursor, fact.serverCompletionId);

      final completions = await db!.query('learning_progress_completions');

      expect(completions, hasLength(1));
      expect(
        completions.single['client_completion_id'],
        fact.clientCompletionId,
      );
      expect(completions.single['activity_id'], fact.activityId.value);

      final activity = learningPath.activities.singleWhere(
        (item) => item.id == fact.activityId,
      );

      final expectedCompetencies = activity.currentRevision.competencies
          .map((id) => id.value)
          .toSet();

      final evidence = await db!.query('learning_competency_evidence');

      expect(
        evidence.map((row) => row['competency_id']! as String).toSet(),
        expectedCompetencies,
      );

      final projection = await db!.query(
        'learning_progress_projection',
        where:
            'account_id = ? AND learning_path_id = ? '
            'AND activity_id = ?',
        whereArgs: <Object?>[
          'user-phase3',
          learningPath.id.value,
          fact.activityId.value,
        ],
      );

      expect(projection.single['state'], 'completed');

      final queue = await db!.query(
        'sync_queue',
        where: 'entity_type = ?',
        whereArgs: const <Object?>['learning_progress_completion'],
      );

      expect(
        queue,
        isEmpty,
        reason: 'Facto recebido da cloud nunca cria nova outbox.',
      );

      expect(
        await repository.readSyncCursor(
          accountId: 'user-phase3',
          learningPathId: learningPath.id.value,
        ),
        fact.serverCompletionId,
      );
    },
  );

  test(
    'Fase 3.5B2 — facto local devolvido pelo servidor permanece idempotente',
    () async {
      final learningPath = _loadReferenceJourney();
      final path = p.join(tempDir.path, 'local-roundtrip.db');

      db = await AppDatabase.instance.openDatabaseForTesting(path);

      final repository = LearningProgressRepository(db!);

      final activity = learningPath.activities.singleWhere(
        (item) => item.id.value == 'arrival.dialogue-01',
      );

      final completedAt = DateTime.utc(2026, 9, 13, 10);

      const clientId = 'device-a-roundtrip-0001';

      await repository.completeActivity(
        CompleteLearningActivityWrite(
          clientCompletionId: clientId,
          accountId: 'user-phase3',
          learningPath: learningPath,
          activityId: activity.id,
          revisionId: activity.currentRevisionId,
          packageVersion: 3,
          completedAt: completedAt,
        ),
      );

      final queueBefore = await db!.query(
        'sync_queue',
        where: 'entity_type = ?',
        whereArgs: const <Object?>['learning_progress_completion'],
      );

      expect(queueBefore, hasLength(1));

      final remote = RemoteLearningCompletionFact(
        serverCompletionId: 'server-roundtrip-0001',
        clientCompletionId: clientId,
        learningPathId: learningPath.id.value,
        activityId: activity.id,
        revisionId: activity.currentRevisionId,
        packageVersion: 3,
        completedAt: completedAt,
      );

      final result = await repository.mergeRemoteProgress(
        MergeRemoteLearningProgressWrite(
          accountId: 'user-phase3',
          learningPath: learningPath,
          activePackageVersion: 3,
          expectedCursor: null,
          nextCursor: remote.serverCompletionId,
          completions: <RemoteLearningCompletionFact>[remote],
        ),
      );

      expect(result.insertedCount, 0);
      expect(result.duplicateCount, 1);

      expect(await db!.query('learning_progress_completions'), hasLength(1));

      final queueAfter = await db!.query(
        'sync_queue',
        where: 'entity_type = ?',
        whereArgs: const <Object?>['learning_progress_completion'],
      );

      expect(queueAfter, hasLength(1));
    },
  );

  test(
    'Fase 3.5B2 — revisão desconhecida reverte factos, projeção e cursor',
    () async {
      final learningPath = _loadReferenceJourney();
      final path = p.join(tempDir.path, 'invalid-revision.db');

      db = await AppDatabase.instance.openDatabaseForTesting(path);

      final repository = LearningProgressRepository(db!);

      final invalid = _remoteFact(
        learningPath,
        serverCompletionId: 'server-invalid-0001',
        clientCompletionId: 'device-invalid-0001',
        revisionId: RevisionId('arrival.dialogue-01.revision-missing'),
      );

      await expectLater(
        repository.mergeRemoteProgress(
          MergeRemoteLearningProgressWrite(
            accountId: 'user-phase3',
            learningPath: learningPath,
            activePackageVersion: 3,
            expectedCursor: null,
            nextCursor: invalid.serverCompletionId,
            completions: <RemoteLearningCompletionFact>[invalid],
          ),
        ),
        throwsA(isA<StateError>()),
      );

      expect(await db!.query('learning_progress_completions'), isEmpty);

      expect(await db!.query('learning_competency_evidence'), isEmpty);

      expect(await db!.query('learning_progress_projection'), isEmpty);

      expect(await db!.query('learning_progress_sync_state'), isEmpty);
    },
  );

  test('Fase 3.5B2 — compare-and-set impede regressão do cursor', () async {
    final learningPath = _loadReferenceJourney();
    final path = p.join(tempDir.path, 'cursor-cas.db');

    db = await AppDatabase.instance.openDatabaseForTesting(path);

    final repository = LearningProgressRepository(db!);
    final first = _remoteFact(
      learningPath,
      serverCompletionId: 'server-cursor-0001',
      clientCompletionId: 'device-cursor-0001',
    );

    await repository.mergeRemoteProgress(
      MergeRemoteLearningProgressWrite(
        accountId: 'user-phase3',
        learningPath: learningPath,
        activePackageVersion: 3,
        expectedCursor: null,
        nextCursor: first.serverCompletionId,
        completions: <RemoteLearningCompletionFact>[first],
      ),
    );

    await expectLater(
      repository.mergeRemoteProgress(
        MergeRemoteLearningProgressWrite(
          accountId: 'user-phase3',
          learningPath: learningPath,
          activePackageVersion: 3,
          expectedCursor: null,
          nextCursor: null,
          completions: const <RemoteLearningCompletionFact>[],
        ),
      ),
      throwsA(isA<StateError>()),
    );

    expect(
      await repository.readSyncCursor(
        accountId: 'user-phase3',
        learningPathId: learningPath.id.value,
      ),
      first.serverCompletionId,
    );

    expect(await db!.query('learning_progress_completions'), hasLength(1));
  });
}
