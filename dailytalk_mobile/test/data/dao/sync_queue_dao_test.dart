import 'dart:io';

import 'package:dailytalk_mobile/data/dao/sync_queue_dao.dart';
import 'package:dailytalk_mobile/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  Database? db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dailytalk-sync-queue-');
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

  Future<int> enqueueLearningCompletion(
    SyncQueueDao dao, {
    int entityId = 101,
  }) {
    return dao.enqueue(
      entityType: 'learning_progress_completion',
      entityId: entityId,
      operation: 'ActivityCompleted',
      endpoint: '/api/sync/progress',
      payloadJson: '{"clientCompletionId":"completion-$entityId"}',
    );
  }

  group('SyncQueueDao — Fase 3.3', () {
    test('item pending sobrevive ao fecho e reabertura da base', () async {
      final path = p.join(tempDir.path, 'durable-outbox.db');

      var now = DateTime.utc(2026, 9, 10, 17);

      db = await AppDatabase.instance.openDatabaseForTesting(path);

      var dao = SyncQueueDao(db!, clock: () => now);

      final id = await enqueueLearningCompletion(dao);

      expect(await dao.getPendingItems(), hasLength(1));

      await db!.close();
      db = null;

      now = now.add(const Duration(minutes: 1));

      db = await AppDatabase.instance.openDatabaseForTesting(path);

      dao = SyncQueueDao(db!, clock: () => now);

      final pending = await dao.getPendingItems();

      expect(pending, hasLength(1));
      expect(pending.single['id'], id);
      expect(pending.single['attempt_count'], 0);
      expect(pending.single['sync_status'], 'pending');
    });

    test(
      'claim é localmente exclusivo e muda estado para processing',
      () async {
        final path = p.join(tempDir.path, 'atomic-claim.db');

        final now = DateTime.utc(2026, 9, 10, 17, 10);

        db = await AppDatabase.instance.openDatabaseForTesting(path);

        final dao = SyncQueueDao(db!, clock: () => now);

        final id = await enqueueLearningCompletion(dao);

        final firstClaim = await dao.claimPendingItems();
        final secondClaim = await dao.claimPendingItems();

        expect(firstClaim, hasLength(1));
        expect(firstClaim.single['id'], id);
        expect(firstClaim.single['sync_status'], 'processing');

        expect(secondClaim, isEmpty);

        final rows = await db!.query(
          'sync_queue',
          where: 'id = ?',
          whereArgs: <Object?>[id],
        );

        expect(rows.single['sync_status'], 'processing');
      },
    );

    test(
      'falha aplica backoff e item não é elegível antes de next_retry_at',
      () async {
        final path = p.join(tempDir.path, 'retry-backoff.db');

        var now = DateTime.utc(2026, 9, 10, 17, 20);

        db = await AppDatabase.instance.openDatabaseForTesting(path);

        final dao = SyncQueueDao(db!, clock: () => now);

        final id = await enqueueLearningCompletion(dao);

        expect(await dao.claimPendingItems(), hasLength(1));

        expect(
          await dao.markFailed(id: id, error: 'SocketException: offline'),
          1,
        );

        var rows = await db!.query(
          'sync_queue',
          where: 'id = ?',
          whereArgs: <Object?>[id],
        );

        expect(rows.single['attempt_count'], 1);
        expect(rows.single['sync_status'], 'failed');
        expect(rows.single['last_error'], 'network');

        expect(
          rows.single['next_retry_at'],
          DateTime.utc(2026, 9, 10, 17, 25).toIso8601String(),
        );

        expect(await dao.getPendingItems(), isEmpty);

        now = DateTime.utc(2026, 9, 10, 17, 24, 59);

        expect(await dao.getPendingItems(), isEmpty);

        now = DateTime.utc(2026, 9, 10, 17, 25);

        expect(await dao.getPendingItems(), hasLength(1));
      },
    );

    test('backoff cresce entre tentativas sem criar nova linha', () async {
      final path = p.join(tempDir.path, 'exponential-backoff.db');

      var now = DateTime.utc(2026, 9, 10, 18);

      db = await AppDatabase.instance.openDatabaseForTesting(path);

      final dao = SyncQueueDao(db!, clock: () => now);

      final id = await enqueueLearningCompletion(dao);

      await dao.claimPendingItems();

      await dao.markFailed(id: id, error: 'timeout');

      now = DateTime.utc(2026, 9, 10, 18, 5);

      expect(await dao.claimPendingItems(), hasLength(1));

      await dao.markFailed(id: id, error: 'timeout novamente');

      final rows = await db!.query('sync_queue');

      expect(rows, hasLength(1));
      expect(rows.single['id'], id);
      expect(rows.single['attempt_count'], 2);

      expect(
        rows.single['next_retry_at'],
        DateTime.utc(2026, 9, 10, 18, 15).toIso8601String(),
      );
    });

    test('erro bruto potencialmente sensível não é persistido', () async {
      final path = p.join(tempDir.path, 'safe-error.db');

      final now = DateTime.utc(2026, 9, 10, 18, 30);

      db = await AppDatabase.instance.openDatabaseForTesting(path);

      final dao = SyncQueueDao(db!, clock: () => now);

      final id = await enqueueLearningCompletion(dao);

      await dao.claimPendingItems();

      const secret = 'Bearer eyJhbGciOiJsuper-secret-token-value';

      await dao.markFailed(id: id, error: 'HTTP 401 Unauthorized: $secret');

      final rows = await db!.query(
        'sync_queue',
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );

      final stored = rows.single['last_error'] as String;

      expect(stored, 'authentication');
      expect(stored, isNot(contains('Bearer')));
      expect(stored, isNot(contains('secret')));
      expect(stored, isNot(contains('eyJ')));
    });

    test(
      'processing abandonado é recuperado após expiração do lease',
      () async {
        final path = p.join(tempDir.path, 'processing-lease.db');

        var now = DateTime.utc(2026, 9, 10, 19);

        db = await AppDatabase.instance.openDatabaseForTesting(path);

        final dao = SyncQueueDao(db!, clock: () => now);

        final id = await enqueueLearningCompletion(dao);

        expect(await dao.claimPendingItems(), hasLength(1));

        now = DateTime.utc(2026, 9, 10, 19, 14, 59);

        expect(
          await dao.claimPendingItems(
            processingLease: const Duration(minutes: 15),
          ),
          isEmpty,
        );

        now = DateTime.utc(2026, 9, 10, 19, 15);

        final recovered = await dao.claimPendingItems(
          processingLease: const Duration(minutes: 15),
        );

        expect(recovered, hasLength(1));
        expect(recovered.single['id'], id);
        expect(recovered.single['sync_status'], 'processing');

        final rows = await db!.query(
          'sync_queue',
          where: 'id = ?',
          whereArgs: <Object?>[id],
        );

        expect(rows.single['last_error'], 'processing_lease_expired');

        // Expiração do lease não inventa uma falha remota.
        expect(rows.single['attempt_count'], 0);
      },
    );

    test('sucesso torna item terminal e limpa estado de retry', () async {
      final path = p.join(tempDir.path, 'successful-retry.db');

      var now = DateTime.utc(2026, 9, 10, 20);

      db = await AppDatabase.instance.openDatabaseForTesting(path);

      final dao = SyncQueueDao(db!, clock: () => now);

      final id = await enqueueLearningCompletion(dao);

      await dao.claimPendingItems();

      await dao.markFailed(id: id, error: 'network offline');

      now = DateTime.utc(2026, 9, 10, 20, 5);

      expect(await dao.claimPendingItems(), hasLength(1));

      expect(await dao.markSynced(id), 1);

      final rows = await db!.query(
        'sync_queue',
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );

      expect(rows, hasLength(1));
      expect(rows.single['sync_status'], 'synced');
      expect(rows.single['attempt_count'], 1);
      expect(rows.single['last_error'], isNull);
      expect(rows.single['next_retry_at'], isNull);
      expect(rows.single['processed_at'], isNotNull);

      expect(await dao.getPendingItems(), isEmpty);

      expect(await dao.claimPendingItems(), isEmpty);
    });
  });
}
