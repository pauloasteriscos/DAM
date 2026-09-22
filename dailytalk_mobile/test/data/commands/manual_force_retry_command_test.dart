import 'dart:convert';
import 'dart:io';

import 'package:dailytalk_mobile/data/api/dailytalk_api_service.dart';
import 'package:dailytalk_mobile/data/commands/sync_command.dart';
import 'package:dailytalk_mobile/data/dao/sync_queue_dao.dart';
import 'package:dailytalk_mobile/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final class _FakeApiService extends DailyTalkApiService {
  int calls = 0;

  @override
  Future<Map<String, dynamic>> secureSyncProgress(
    List<Map<String, dynamic>> items, {
    bool pullLearningProgress = false,
    String? learningProgressPathId,
    String? learningProgressCursor,
    int learningProgressLimit = 50,
  }) async {
    calls += 1;

    return <String, dynamic>{
      'results': items
          .map(
            (item) => <String, dynamic>{
              'type': 'activityCompletion',
              'clientCompletionId': item['clientCompletionId'],
              'completionId': 'server-${item['clientCompletionId']}',
              'status': 'accepted',
              'activityId': item['activityId'],
              'revisionId': item['revisionId'],
            },
          )
          .toList(growable: false),
    };
  }
}

Map<String, dynamic> _payload(String clientId) {
  return <String, dynamic>{
    'type': 'ActivityCompleted',
    'clientCompletionId': clientId,
    'learningPathId': 'student.en-us.phase1',
    'activityId': 'arrival.vocabulary-01',
    'revisionId': 'arrival.vocabulary-01.r1',
    'packageVersion': 3,
    'completedAt': '2026-09-22T12:00:00.000Z',
  };
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
    tempDir = await Directory.systemTemp.createTemp(
      'dailytalk-manual-force-retry-',
    );
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
    'manual forceRetry ultrapassa cooldown; automatico continua bloqueado',
    () async {
      final now = DateTime.utc(2026, 9, 22, 16);

      db = await AppDatabase.instance.openDatabaseForTesting(
        p.join(tempDir.path, 'manual-force-retry-command.db'),
      );

      final dao = SyncQueueDao(db!, clock: () => now);

      final id = await dao.enqueue(
        entityType: 'learning_progress_completion',
        entityId: 1,
        operation: 'ActivityCompleted',
        endpoint: '/api/sync/progress',
        method: 'POST',
        payloadJson: jsonEncode(_payload('manual-force-retry-1')),
      );

      expect(
        await dao.claimPendingItemsByEntityType(
          entityType: 'learning_progress_completion',
        ),
        hasLength(1),
      );

      expect(await dao.markFailed(id: id, error: 'network offline'), 1);

      var rows = await db!.query(
        'sync_queue',
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );

      expect(rows.single['sync_status'], 'failed');
      expect(rows.single['attempt_count'], 1);
      expect(
        rows.single['next_retry_at'],
        now.add(const Duration(seconds: 5)).toIso8601String(),
      );

      final automaticApi = _FakeApiService();
      final automatic = await SyncLearningProgressOutboxCommand(
        apiService: automaticApi,
        syncQueueDao: dao,
      ).execute();

      expect(automatic.success, isTrue);
      expect(automatic.syncedCount, 0);
      expect(automaticApi.calls, 0);

      rows = await db!.query(
        'sync_queue',
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );

      expect(rows.single['sync_status'], 'failed');
      expect(rows.single['attempt_count'], 1);

      final manualApi = _FakeApiService();
      final manual = await SyncLearningProgressOutboxCommand(
        apiService: manualApi,
        syncQueueDao: dao,
        forceRetry: true,
      ).execute();

      expect(manual.success, isTrue);
      expect(manual.syncedCount, 1);
      expect(manual.failedCount, 0);
      expect(manualApi.calls, 1);

      rows = await db!.query(
        'sync_queue',
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );

      expect(rows.single['sync_status'], 'synced');
      expect(rows.single['attempt_count'], 1);
      expect(rows.single['next_retry_at'], isNull);
      expect(rows.single['processed_at'], isNotNull);
    },
  );
}
