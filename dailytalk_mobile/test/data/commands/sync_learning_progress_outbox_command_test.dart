import 'dart:convert';
import 'dart:io';

import 'package:dailytalk_mobile/data/api/dailytalk_api_service.dart';
import 'package:dailytalk_mobile/data/commands/sync_command.dart';
import 'package:dailytalk_mobile/data/dao/sync_queue_dao.dart';
import 'package:dailytalk_mobile/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

typedef _SyncHandler =
    Future<Map<String, dynamic>> Function(List<Map<String, dynamic>> items);

final class _FakeApiService extends DailyTalkApiService {
  _FakeApiService(this.handler);

  final _SyncHandler handler;

  int calls = 0;

  @override
  Future<Map<String, dynamic>> secureSyncProgress(
    List<Map<String, dynamic>> items,
  ) {
    calls += 1;
    return handler(items);
  }
}

Map<String, dynamic> _payload(
  String clientId, {
  bool includeCompetencies = true,
}) {
  return <String, dynamic>{
    'type': 'ActivityCompleted',
    'clientCompletionId': clientId,
    'learningPathId': 'path-main',
    'activityId': 'activity-$clientId',
    'revisionId': 'revision-$clientId',
    'packageVersion': 3,
    'completedAt': '2026-09-11T20:00:00.000Z',
    if (includeCompetencies)
      'competencyIds': <String>['competency-a', 'competency-b'],
  };
}

Map<String, dynamic> _resultFor(
  Map<String, dynamic> item, {
  String status = 'accepted',
}) {
  final clientId = item['clientCompletionId'].toString();

  return <String, dynamic>{
    'type': 'activityCompletion',
    'clientCompletionId': clientId,
    'completionId': 'server-$clientId',
    'status': status,
    'activityId': item['activityId'],
    'revisionId': item['revisionId'],
  };
}

Future<int> _enqueueLearning(
  SyncQueueDao dao, {
  required int entityId,
  required String clientId,
  Map<String, dynamic>? payload,
}) {
  return dao.enqueue(
    entityType: 'learning_progress_completion',
    entityId: entityId,
    operation: 'ActivityCompleted',
    endpoint: '/api/sync/progress',
    method: 'POST',
    payloadJson: jsonEncode(payload ?? _payload(clientId)),
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
    tempDir = await Directory.systemTemp.createTemp('dailytalk-phase34b-');
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
    'accepted sincroniza outbox e remove competencyIds do transporte',
    () async {
      final path = p.join(tempDir.path, 'accepted.db');

      db = await AppDatabase.instance.openDatabaseForTesting(path);

      final dao = SyncQueueDao(db!);

      final id = await _enqueueLearning(
        dao,
        entityId: 1,
        clientId: 'completion-1',
      );

      var sent = <Map<String, dynamic>>[];

      final api = _FakeApiService((items) async {
        sent = items.map(Map<String, dynamic>.from).toList(growable: false);

        return <String, dynamic>{
          'results': items.map(_resultFor).toList(growable: false),
        };
      });

      final result = await SyncLearningProgressOutboxCommand(
        apiService: api,
        syncQueueDao: dao,
      ).execute();

      expect(result.success, isTrue);
      expect(result.syncedCount, 1);
      expect(result.failedCount, 0);

      expect(api.calls, 1);
      expect(sent, hasLength(1));

      final transported = sent.single;

      expect(transported['type'], 'activityCompletion');
      expect(transported['clientCompletionId'], 'completion-1');
      expect(transported.containsKey('competencyIds'), isFalse);

      final rows = await db!.query(
        'sync_queue',
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );

      expect(rows.single['sync_status'], 'synced');
      expect(rows.single['processed_at'], isNotNull);

      final storedPayload = Map<String, dynamic>.from(
        jsonDecode(rows.single['payload_json']! as String) as Map,
      );

      expect(storedPayload['competencyIds'], <String>[
        'competency-a',
        'competency-b',
      ]);
    },
  );

  test('duplicate remoto também torna a conclusão local synced', () async {
    final path = p.join(tempDir.path, 'duplicate.db');

    db = await AppDatabase.instance.openDatabaseForTesting(path);

    final dao = SyncQueueDao(db!);

    final id = await _enqueueLearning(
      dao,
      entityId: 2,
      clientId: 'completion-2',
    );

    final api = _FakeApiService((items) async {
      return <String, dynamic>{
        'results': items
            .map((item) => _resultFor(item, status: 'duplicate'))
            .toList(growable: false),
      };
    });

    final result = await SyncLearningProgressOutboxCommand(
      apiService: api,
      syncQueueDao: dao,
    ).execute();

    expect(result.success, isTrue);
    expect(result.syncedCount, 1);

    final rows = await db!.query(
      'sync_queue',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );

    expect(rows.single['sync_status'], 'synced');
  });

  test('falha de rede preserva outbox e agenda retry', () async {
    final path = p.join(tempDir.path, 'network.db');

    final now = DateTime.utc(2026, 9, 11, 20);

    db = await AppDatabase.instance.openDatabaseForTesting(path);

    final dao = SyncQueueDao(db!, clock: () => now);

    final id = await _enqueueLearning(
      dao,
      entityId: 3,
      clientId: 'completion-3',
    );

    final api = _FakeApiService((_) async {
      throw Exception('SocketException: network offline');
    });

    final result = await SyncLearningProgressOutboxCommand(
      apiService: api,
      syncQueueDao: dao,
    ).execute();

    expect(result.success, isFalse);
    expect(result.failedCount, 1);

    final rows = await db!.query(
      'sync_queue',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );

    final row = rows.single;

    expect(row['sync_status'], 'failed');
    expect(row['attempt_count'], 1);
    expect(row['last_error'], 'network');
    expect(row['next_retry_at'], isNotNull);
    expect(row['processed_at'], isNull);
  });

  test(
    'resposta remota incompatível nunca marca conclusão como synced',
    () async {
      final path = p.join(tempDir.path, 'mismatch.db');

      db = await AppDatabase.instance.openDatabaseForTesting(path);

      final dao = SyncQueueDao(db!);

      final id = await _enqueueLearning(
        dao,
        entityId: 4,
        clientId: 'completion-4',
      );

      final api = _FakeApiService((items) async {
        final wrong = _resultFor(items.single);

        wrong['clientCompletionId'] = 'completion-de-outro-item';

        return <String, dynamic>{
          'results': <Map<String, dynamic>>[wrong],
        };
      });

      final result = await SyncLearningProgressOutboxCommand(
        apiService: api,
        syncQueueDao: dao,
      ).execute();

      expect(result.success, isFalse);

      final rows = await db!.query(
        'sync_queue',
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );

      expect(rows.single['sync_status'], 'failed');
      expect(rows.single['last_error'], 'invalid_payload');
    },
  );

  test('worker pedagógico não reclama outras famílias da outbox', () async {
    final path = p.join(tempDir.path, 'entity-filter.db');

    db = await AppDatabase.instance.openDatabaseForTesting(path);

    final dao = SyncQueueDao(db!);

    final unrelatedId = await dao.enqueue(
      entityType: 'analytics_record',
      entityId: 999,
      operation: 'AnalyticsCreated',
      endpoint: '/api/analytics',
      payloadJson: '{"safe":true}',
    );

    final api = _FakeApiService((_) async {
      throw StateError('A API não deveria ter sido chamada.');
    });

    final result = await SyncLearningProgressOutboxCommand(
      apiService: api,
      syncQueueDao: dao,
    ).execute();

    expect(result.success, isTrue);
    expect(result.syncedCount, 0);
    expect(api.calls, 0);

    final rows = await db!.query(
      'sync_queue',
      where: 'id = ?',
      whereArgs: <Object?>[unrelatedId],
    );

    expect(rows.single['sync_status'], 'pending');
  });

  test('payload local inválido falha sem chegar ao Secure Sync', () async {
    final path = p.join(tempDir.path, 'invalid-local.db');

    db = await AppDatabase.instance.openDatabaseForTesting(path);

    final dao = SyncQueueDao(db!);

    final invalidPayload = _payload('completion-5');

    invalidPayload.remove('revisionId');

    final id = await _enqueueLearning(
      dao,
      entityId: 5,
      clientId: 'completion-5',
      payload: invalidPayload,
    );

    final api = _FakeApiService((_) async {
      throw StateError('A API não deveria ter sido chamada.');
    });

    final result = await SyncLearningProgressOutboxCommand(
      apiService: api,
      syncQueueDao: dao,
    ).execute();

    expect(result.success, isFalse);
    expect(result.failedCount, 1);
    expect(api.calls, 0);

    final rows = await db!.query(
      'sync_queue',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );

    expect(rows.single['sync_status'], 'failed');
    expect(rows.single['last_error'], 'invalid_payload');
  });

  test('um lote transporta no máximo 50 conclusões', () async {
    final path = p.join(tempDir.path, 'batch-limit.db');

    db = await AppDatabase.instance.openDatabaseForTesting(path);

    final dao = SyncQueueDao(db!);

    for (var i = 1; i <= 51; i++) {
      await _enqueueLearning(dao, entityId: i, clientId: 'batch-$i');
    }

    final api = _FakeApiService((items) async {
      expect(items, hasLength(50));

      return <String, dynamic>{
        'results': items.map(_resultFor).toList(growable: false),
      };
    });

    final result = await SyncLearningProgressOutboxCommand(
      apiService: api,
      syncQueueDao: dao,
    ).execute();

    expect(result.success, isTrue);
    expect(result.syncedCount, 50);
    expect(api.calls, 1);

    final rows = await db!.query('sync_queue');

    expect(rows.where((row) => row['sync_status'] == 'synced').length, 50);

    expect(rows.where((row) => row['sync_status'] == 'pending').length, 1);
  });
}
