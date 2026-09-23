import 'dart:convert';
import 'dart:io';

import 'package:dailytalk_mobile/data/api/dailytalk_api_service.dart';
import 'package:dailytalk_mobile/data/commands/sync_command.dart';
import 'package:dailytalk_mobile/data/dao/sync_queue_dao.dart';
import 'package:dailytalk_mobile/data/database/app_database.dart';
import 'package:dailytalk_mobile/data/repositories/learning_progress_repository.dart';
import 'package:dailytalk_mobile/domain/learning/learning_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _referencePath =
    '../dailytalk-api/docs/phase2/official_reference_journey_v3.json';

typedef _SyncHandler =
    Future<Map<String, dynamic>> Function(
      List<Map<String, dynamic>> items, {
      required bool pullLearningProgress,
      String? learningProgressCursor,
      String? learningProgressPathId,
      required int learningProgressLimit,
    });

final class _FakeApiService extends DailyTalkApiService {
  _FakeApiService(this.handler);

  final _SyncHandler handler;

  int calls = 0;

  @override
  Future<Map<String, dynamic>> secureSyncProgress(
    List<Map<String, dynamic>> items, {
    bool pullLearningProgress = false,
    String? learningProgressCursor,
    String? learningProgressPathId,
    int learningProgressLimit = 50,
  }) {
    calls += 1;

    if (pullLearningProgress &&
        (learningProgressPathId == null ||
            learningProgressPathId.trim().isEmpty)) {
      throw StateError(
        'learningProgressPathId ausente num pull de reconciliação.',
      );
    }

    return handler(
      items,
      pullLearningProgress: pullLearningProgress,
      learningProgressCursor: learningProgressCursor,
      learningProgressPathId: learningProgressPathId,
      learningProgressLimit: learningProgressLimit,
    );
  }
}

LearningPath _loadJourney() {
  final source = File(_referencePath).readAsStringSync();
  return const LearningContentCodec().decodeString(source);
}

Activity _activity(LearningPath path, {int index = 0}) {
  if (path.activities.length <= index) {
    throw StateError('Percurso não tem atividades suficientes.');
  }

  return path.activities[index];
}

Map<String, dynamic> _remoteFact({
  required LearningPath path,
  required Activity activity,
  required String completionId,
  required String clientCompletionId,
  String? revisionId,
  DateTime? completedAt,
}) {
  return <String, dynamic>{
    'type': 'activityCompletion',
    'completionId': completionId,
    'clientCompletionId': clientCompletionId,
    'learningPathId': path.id.value,
    'activityId': activity.id.value,
    'revisionId': revisionId ?? activity.currentRevisionId.value,
    'packageVersion': 3,
    'completedAt': (completedAt ?? DateTime.utc(2026, 9, 13, 10))
        .toIso8601String(),
  };
}

Map<String, dynamic> _resultFor(
  Map<String, dynamic> item, {
  String status = 'accepted',
}) {
  return <String, dynamic>{
    'type': 'activityCompletion',
    'clientCompletionId': item['clientCompletionId'],
    'completionId': 'server-${item['clientCompletionId']}',
    'status': status,
    'activityId': item['activityId'],
    'revisionId': item['revisionId'],
  };
}

Map<String, dynamic> _response({
  required List<Map<String, dynamic>> results,
  required List<Map<String, dynamic>> items,
  required String? nextCursor,
  required bool hasMore,
}) {
  return <String, dynamic>{
    'results': results,
    'pull': <String, dynamic>{
      'learningProgress': <String, dynamic>{
        'items': items,
        'nextCursor': nextCursor,
        'hasMore': hasMore,
      },
    },
  };
}

Future<void> _completeLocal({
  required LearningProgressRepository repository,
  required LearningPath path,
  required String clientCompletionId,
  DateTime? completedAt,
}) async {
  final activity = _activity(path);

  await repository.completeActivity(
    CompleteLearningActivityWrite(
      clientCompletionId: clientCompletionId,
      accountId: 'user-phase35',
      learningPath: path,
      activityId: activity.id,
      revisionId: activity.currentRevisionId,
      packageVersion: 3,
      completedAt: completedAt ?? DateTime.utc(2026, 9, 13, 10),
    ),
  );
}

ReconcileLearningProgressCommand _command({
  required DailyTalkApiService api,
  required SyncQueueDao dao,
  required LearningProgressRepository repository,
  required LearningPath path,
  int pullLimit = 50,
}) {
  return ReconcileLearningProgressCommand(
    apiService: api,
    syncQueueDao: dao,
    repository: repository,
    accountId: 'user-phase35',
    learningPath: path,
    activePackageVersion: 3,
    pullLimit: pullLimit,
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
    tempDir = await Directory.systemTemp.createTemp('dailytalk-phase35b3-');
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

  test('3.5B3 — outbox vazia continua a fazer pull remoto', () async {
    final journey = _loadJourney();
    final activity = _activity(journey);

    db = await AppDatabase.instance.openDatabaseForTesting(
      p.join(tempDir.path, 'pull-only.db'),
    );

    final repository = LearningProgressRepository(db!);
    final dao = SyncQueueDao(db!);

    final remote = _remoteFact(
      path: journey,
      activity: activity,
      completionId: 'server-pull-only-1',
      clientCompletionId: 'remote-pull-only-1',
    );

    final api = _FakeApiService((
      items, {
      required bool pullLearningProgress,
      String? learningProgressCursor,
      String? learningProgressPathId,
      required int learningProgressLimit,
    }) async {
      expect(items, isEmpty);
      expect(pullLearningProgress, isTrue);
      expect(learningProgressCursor, isNull);

      return _response(
        results: const <Map<String, dynamic>>[],
        items: <Map<String, dynamic>>[remote],
        nextCursor: 'server-pull-only-1',
        hasMore: false,
      );
    });

    final result = await _command(
      api: api,
      dao: dao,
      repository: repository,
      path: journey,
    ).execute();

    expect(result.success, isTrue);
    expect(result.syncedCount, 0);
    expect(api.calls, 1);

    expect(await db!.query('learning_progress_completions'), hasLength(1));

    expect(
      await repository.readSyncCursor(
        accountId: 'user-phase35',
        learningPathId: journey.id.value,
      ),
      'server-pull-only-1',
    );
  });

  test('3.5B3 — push accepted e pull ocorrem na mesma chamada', () async {
    final journey = _loadJourney();

    db = await AppDatabase.instance.openDatabaseForTesting(
      p.join(tempDir.path, 'push-pull.db'),
    );

    final repository = LearningProgressRepository(db!);
    final dao = SyncQueueDao(db!);

    final completedAt = DateTime.utc(2026, 9, 13, 10);

    await _completeLocal(
      repository: repository,
      path: journey,
      clientCompletionId: 'local-accepted-1',
      completedAt: completedAt,
    );

    final api = _FakeApiService((
      items, {
      required bool pullLearningProgress,
      String? learningProgressCursor,
      String? learningProgressPathId,
      required int learningProgressLimit,
    }) async {
      expect(items, hasLength(1));
      expect(pullLearningProgress, isTrue);
      expect(learningProgressCursor, isNull);

      final item = items.single;

      return _response(
        results: <Map<String, dynamic>>[_resultFor(item)],
        items: <Map<String, dynamic>>[
          <String, dynamic>{...item, 'completionId': 'server-local-accepted-1'},
        ],
        nextCursor: 'server-local-accepted-1',
        hasMore: false,
      );
    });

    final result = await _command(
      api: api,
      dao: dao,
      repository: repository,
      path: journey,
    ).execute();

    expect(result.success, isTrue);
    expect(result.syncedCount, 1);
    expect(api.calls, 1);

    final queue = await db!.query(
      'sync_queue',
      where: 'entity_type = ?',
      whereArgs: const <Object?>['learning_progress_completion'],
    );

    expect(queue.single['sync_status'], 'synced');

    // A conclusão local devolvida pelo servidor não é duplicada.
    expect(await db!.query('learning_progress_completions'), hasLength(1));
  });

  test('3.5B3 — duplicate remoto também finaliza a outbox', () async {
    final journey = _loadJourney();

    db = await AppDatabase.instance.openDatabaseForTesting(
      p.join(tempDir.path, 'duplicate.db'),
    );

    final repository = LearningProgressRepository(db!);
    final dao = SyncQueueDao(db!);

    await _completeLocal(
      repository: repository,
      path: journey,
      clientCompletionId: 'local-duplicate-1',
    );

    final api = _FakeApiService((
      items, {
      required bool pullLearningProgress,
      String? learningProgressCursor,
      String? learningProgressPathId,
      required int learningProgressLimit,
    }) async {
      final item = items.single;

      return _response(
        results: <Map<String, dynamic>>[_resultFor(item, status: 'duplicate')],
        items: <Map<String, dynamic>>[
          <String, dynamic>{
            ...item,
            'completionId': 'server-local-duplicate-1',
          },
        ],
        nextCursor: 'server-local-duplicate-1',
        hasMore: false,
      );
    });

    final result = await _command(
      api: api,
      dao: dao,
      repository: repository,
      path: journey,
    ).execute();

    expect(result.success, isTrue);
    expect(result.syncedCount, 1);

    final queue = await db!.query('sync_queue');

    expect(queue.single['sync_status'], 'synced');
  });

  test('3.5B3 — falha no merge nunca marca outbox como synced', () async {
    final journey = _loadJourney();

    db = await AppDatabase.instance.openDatabaseForTesting(
      p.join(tempDir.path, 'merge-failure.db'),
    );

    final repository = LearningProgressRepository(db!);
    final dao = SyncQueueDao(db!);

    await _completeLocal(
      repository: repository,
      path: journey,
      clientCompletionId: 'local-merge-failure-1',
    );

    final api = _FakeApiService((
      items, {
      required bool pullLearningProgress,
      String? learningProgressCursor,
      String? learningProgressPathId,
      required int learningProgressLimit,
    }) async {
      final item = items.single;

      return _response(
        results: <Map<String, dynamic>>[_resultFor(item)],
        items: <Map<String, dynamic>>[
          <String, dynamic>{
            ...item,
            'clientCompletionId': 'remote-invalid-revision-1',
            'completionId': 'server-invalid-revision-1',
            'revisionId': 'revision-does-not-exist',
          },
        ],
        nextCursor: 'server-invalid-revision-1',
        hasMore: false,
      );
    });

    final result = await _command(
      api: api,
      dao: dao,
      repository: repository,
      path: journey,
    ).execute();

    expect(result.success, isFalse);

    final queue = await db!.query('sync_queue');

    expect(queue.single['sync_status'], 'failed');

    expect(
      await repository.readSyncCursor(
        accountId: 'user-phase35',
        learningPathId: journey.id.value,
      ),
      isNull,
    );
  });

  test('3.5B3 — hasMore executa páginas pull-only adicionais', () async {
    final journey = _loadJourney();
    final firstActivity = _activity(journey);
    final secondActivity = _activity(journey, index: 1);

    db = await AppDatabase.instance.openDatabaseForTesting(
      p.join(tempDir.path, 'pagination.db'),
    );

    final repository = LearningProgressRepository(db!);
    final dao = SyncQueueDao(db!);

    late final _FakeApiService api;

    api = _FakeApiService((
      items, {
      required bool pullLearningProgress,
      String? learningProgressCursor,
      String? learningProgressPathId,
      required int learningProgressLimit,
    }) async {
      expect(pullLearningProgress, isTrue);

      if (api.calls == 1) {
        expect(items, isEmpty);
        expect(learningProgressCursor, isNull);

        return _response(
          results: const <Map<String, dynamic>>[],
          items: <Map<String, dynamic>>[
            _remoteFact(
              path: journey,
              activity: firstActivity,
              completionId: 'server-page-1',
              clientCompletionId: 'remote-page-1',
            ),
          ],
          nextCursor: 'server-page-1',
          hasMore: true,
        );
      }

      expect(api.calls, 2);
      expect(items, isEmpty);
      expect(learningProgressCursor, 'server-page-1');

      return _response(
        results: const <Map<String, dynamic>>[],
        items: <Map<String, dynamic>>[
          _remoteFact(
            path: journey,
            activity: secondActivity,
            completionId: 'server-page-2',
            clientCompletionId: 'remote-page-2',
          ),
        ],
        nextCursor: 'server-page-2',
        hasMore: false,
      );
    });

    final result = await _command(
      api: api,
      dao: dao,
      repository: repository,
      path: journey,
      pullLimit: 1,
    ).execute();

    expect(result.success, isTrue);
    expect(api.calls, 2);

    expect(await db!.query('learning_progress_completions'), hasLength(2));

    expect(
      await repository.readSyncCursor(
        accountId: 'user-phase35',
        learningPathId: journey.id.value,
      ),
      'server-page-2',
    );
  });

  test(
    '3.5B3 — resposta incompatível não avança cursor nem sincroniza outbox',
    () async {
      final journey = _loadJourney();

      db = await AppDatabase.instance.openDatabaseForTesting(
        p.join(tempDir.path, 'invalid-response.db'),
      );

      final repository = LearningProgressRepository(db!);
      final dao = SyncQueueDao(db!);

      await _completeLocal(
        repository: repository,
        path: journey,
        clientCompletionId: 'local-invalid-response-1',
      );

      final api = _FakeApiService((
        items, {
        required bool pullLearningProgress,
        String? learningProgressCursor,
        String? learningProgressPathId,
        required int learningProgressLimit,
      }) async {
        final wrong = _resultFor(items.single);

        wrong['clientCompletionId'] = 'another-client-id';

        return _response(
          results: <Map<String, dynamic>>[wrong],
          items: const <Map<String, dynamic>>[],
          nextCursor: null,
          hasMore: false,
        );
      });

      final result = await _command(
        api: api,
        dao: dao,
        repository: repository,
        path: journey,
      ).execute();

      expect(result.success, isFalse);

      final queue = await db!.query('sync_queue');

      expect(queue.single['sync_status'], 'failed');

      expect(
        await repository.readSyncCursor(
          accountId: 'user-phase35',
          learningPathId: journey.id.value,
        ),
        isNull,
      );
    },
  );

  test('3.5B3 — payload local inválido não impede pull remoto', () async {
    final journey = _loadJourney();
    final activity = _activity(journey);

    db = await AppDatabase.instance.openDatabaseForTesting(
      p.join(tempDir.path, 'invalid-local-pull.db'),
    );

    final repository = LearningProgressRepository(db!);
    final dao = SyncQueueDao(db!);

    await dao.enqueue(
      entityType: 'learning_progress_completion',
      entityId: 999,
      operation: 'ActivityCompleted',
      endpoint: '/api/sync/progress',
      method: 'POST',
      payloadJson: jsonEncode(<String, dynamic>{
        'type': 'ActivityCompleted',
        'clientCompletionId': 'invalid-local-1',
        'learningPathId': journey.id.value,
        'activityId': activity.id.value,
        // revisionId deliberadamente ausente.
        'packageVersion': 3,
        'completedAt': '2026-09-13T10:00:00.000Z',
      }),
    );

    final remote = _remoteFact(
      path: journey,
      activity: activity,
      completionId: 'server-after-invalid-local',
      clientCompletionId: 'remote-after-invalid-local',
    );

    final api = _FakeApiService((
      items, {
      required bool pullLearningProgress,
      String? learningProgressCursor,
      String? learningProgressPathId,
      required int learningProgressLimit,
    }) async {
      expect(items, isEmpty);
      expect(pullLearningProgress, isTrue);

      return _response(
        results: const <Map<String, dynamic>>[],
        items: <Map<String, dynamic>>[remote],
        nextCursor: 'server-after-invalid-local',
        hasMore: false,
      );
    });

    final result = await _command(
      api: api,
      dao: dao,
      repository: repository,
      path: journey,
    ).execute();

    expect(result.success, isFalse);
    expect(result.failedCount, 1);
    expect(api.calls, 1);

    final queue = await db!.query('sync_queue');

    expect(queue.single['sync_status'], 'failed');

    expect(await db!.query('learning_progress_completions'), hasLength(1));

    expect(
      await repository.readSyncCursor(
        accountId: 'user-phase35',
        learningPathId: journey.id.value,
      ),
      'server-after-invalid-local',
    );
  });
}
