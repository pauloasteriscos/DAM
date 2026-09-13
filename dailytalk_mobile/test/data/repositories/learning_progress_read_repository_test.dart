import 'package:dailytalk_mobile/data/repositories/learning_progress_read_repository.dart';
import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/progression_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late LearningProgressReadRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

    await db.execute('''
      CREATE TABLE learning_progress_projection (
        account_id TEXT NOT NULL,
        learning_path_id TEXT NOT NULL,
        path_element_id TEXT NOT NULL,
        activity_id TEXT,
        state TEXT NOT NULL,
        reason TEXT NOT NULL,
        recommendation_rank INTEGER,
        package_version INTEGER NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (account_id, learning_path_id, path_element_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE learning_progress_completions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_completion_id TEXT NOT NULL UNIQUE,
        account_id TEXT NOT NULL,
        learning_path_id TEXT NOT NULL,
        activity_id TEXT NOT NULL,
        revision_id TEXT NOT NULL,
        package_version INTEGER NOT NULL,
        completed_at TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        sync_status TEXT NOT NULL
      )
    ''');

    repository = LearningProgressReadRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('lê os quatro estados pedagógicos e preserva recomendação', () async {
    await _insertProjection(
      db,
      pathElementId: 'element-locked',
      activityId: 'activity-locked',
      state: 'locked',
      reason: 'prerequisitesNotMet',
    );

    await _insertProjection(
      db,
      pathElementId: 'element-available',
      activityId: 'activity-available',
      state: 'available',
      reason: 'ready',
      recommendationRank: 1,
    );

    await _insertProjection(
      db,
      pathElementId: 'element-progress',
      activityId: 'activity-progress',
      state: 'inProgress',
      reason: 'attemptStarted',
      recommendationRank: 0,
    );

    await _insertProjection(
      db,
      pathElementId: 'element-completed',
      activityId: 'activity-completed',
      state: 'completed',
      reason: 'completed',
    );

    final entries = await repository.readProjection(
      accountId: 'account-1',
      learningPathId: 'path-1',
    );

    final byId = {for (final entry in entries) entry.pathElementId: entry};

    expect(entries, hasLength(4));

    expect(byId['element-locked']!.state, LearningActivityState.locked);
    expect(
      byId['element-locked']!.reason,
      ProgressionReason.prerequisitesNotMet,
    );

    expect(byId['element-available']!.state, LearningActivityState.available);
    expect(byId['element-available']!.reason, ProgressionReason.ready);
    expect(byId['element-available']!.recommendationRank, 1);

    expect(byId['element-progress']!.state, LearningActivityState.inProgress);
    expect(byId['element-progress']!.reason, ProgressionReason.attemptStarted);
    expect(byId['element-progress']!.recommendationRank, 0);
    expect(byId['element-progress']!.isRecommended, isTrue);

    expect(byId['element-completed']!.state, LearningActivityState.completed);
    expect(byId['element-completed']!.reason, ProgressionReason.completed);
    expect(byId['element-completed']!.packageVersion, 7);
  });

  test('contagem de concluídas usa activity_id distinto', () async {
    await _insertCompletion(
      db,
      clientCompletionId: 'completion-a1',
      activityId: 'activity-a',
    );

    await _insertCompletion(
      db,
      clientCompletionId: 'completion-a2',
      activityId: 'activity-a',
    );

    await _insertCompletion(
      db,
      clientCompletionId: 'completion-b1',
      activityId: 'activity-b',
    );

    await _insertCompletion(
      db,
      clientCompletionId: 'completion-other-account',
      accountId: 'account-2',
      activityId: 'activity-c',
    );

    final count = await repository.readCompletedActivityCount(
      accountId: 'account-1',
      learningPathId: 'path-1',
    );

    expect(count, 2);
  });

  test('completed e pending permanecem dimensões independentes', () async {
    await _insertProjection(
      db,
      pathElementId: 'element-a',
      activityId: 'activity-a',
      state: 'completed',
      reason: 'completed',
    );

    final completionId = await _insertCompletion(
      db,
      clientCompletionId: 'completion-a',
      activityId: 'activity-a',
    );

    await _insertQueueItem(db, entityId: completionId, status: 'pending');

    final projection = await repository.readProjection(
      accountId: 'account-1',
      learningPathId: 'path-1',
    );

    final syncStates = await repository.readActivitySyncStates(
      accountId: 'account-1',
      learningPathId: 'path-1',
    );

    expect(projection.single.state, LearningActivityState.completed);
    expect(syncStates['activity-a'], ProgressSyncState.pending);
  });

  test('processing é apresentado como syncing', () async {
    final completionId = await _insertCompletion(
      db,
      clientCompletionId: 'completion-processing',
      activityId: 'activity-processing',
    );

    await _insertQueueItem(db, entityId: completionId, status: 'processing');

    final states = await repository.readActivitySyncStates(
      accountId: 'account-1',
      learningPathId: 'path-1',
    );

    expect(states['activity-processing'], ProgressSyncState.syncing);
  });

  test('synced é apresentado como clean', () async {
    final completionId = await _insertCompletion(
      db,
      clientCompletionId: 'completion-synced',
      activityId: 'activity-synced',
    );

    await _insertQueueItem(db, entityId: completionId, status: 'synced');

    final states = await repository.readActivitySyncStates(
      accountId: 'account-1',
      learningPathId: 'path-1',
    );

    expect(states['activity-synced'], ProgressSyncState.clean);
  });

  test('atividade sem outbox é interpretável como clean', () async {
    await _insertCompletion(
      db,
      clientCompletionId: 'completion-clean',
      activityId: 'activity-clean',
    );

    final states = await repository.readActivitySyncStates(
      accountId: 'account-1',
      learningPathId: 'path-1',
    );

    final state = states['activity-clean'] ?? ProgressSyncState.clean;

    expect(state, ProgressSyncState.clean);
  });

  test(
    'estado técnico mais crítico prevalece para a mesma atividade',
    () async {
      final pendingId = await _insertCompletion(
        db,
        clientCompletionId: 'completion-priority-pending',
        activityId: 'activity-priority',
      );

      final processingId = await _insertCompletion(
        db,
        clientCompletionId: 'completion-priority-processing',
        activityId: 'activity-priority',
      );

      final failedId = await _insertCompletion(
        db,
        clientCompletionId: 'completion-priority-failed',
        activityId: 'activity-priority',
      );

      await _insertQueueItem(db, entityId: pendingId, status: 'pending');

      await _insertQueueItem(db, entityId: processingId, status: 'processing');

      await _insertQueueItem(db, entityId: failedId, status: 'failed');

      final states = await repository.readActivitySyncStates(
        accountId: 'account-1',
        learningPathId: 'path-1',
      );

      expect(states['activity-priority'], ProgressSyncState.failed);
    },
  );

  test('identificadores vazios são rejeitados', () async {
    expect(
      repository.readProjection(accountId: ' ', learningPathId: 'path-1'),
      throwsArgumentError,
    );

    expect(
      repository.readProjection(accountId: 'account-1', learningPathId: ' '),
      throwsArgumentError,
    );

    expect(
      repository.readCompletedActivityCount(
        accountId: '',
        learningPathId: 'path-1',
      ),
      throwsArgumentError,
    );

    expect(
      repository.readActivitySyncStates(
        accountId: 'account-1',
        learningPathId: '',
      ),
      throwsArgumentError,
    );
  });

  test(
    'estado pedagógico persistido desconhecido falha explicitamente',
    () async {
      await _insertProjection(
        db,
        pathElementId: 'element-invalid-state',
        activityId: 'activity-invalid-state',
        state: 'mystery',
        reason: 'ready',
      );

      expect(
        repository.readProjection(
          accountId: 'account-1',
          learningPathId: 'path-1',
        ),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('reason persistido desconhecido falha explicitamente', () async {
    await _insertProjection(
      db,
      pathElementId: 'element-invalid-reason',
      activityId: 'activity-invalid-reason',
      state: 'available',
      reason: 'mystery',
    );

    expect(
      repository.readProjection(
        accountId: 'account-1',
        learningPathId: 'path-1',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('estado de sync desconhecido falha explicitamente', () async {
    final completionId = await _insertCompletion(
      db,
      clientCompletionId: 'completion-invalid-sync',
      activityId: 'activity-invalid-sync',
    );

    await _insertQueueItem(db, entityId: completionId, status: 'mystery');

    expect(
      repository.readActivitySyncStates(
        accountId: 'account-1',
        learningPathId: 'path-1',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

Future<void> _insertProjection(
  Database db, {
  required String pathElementId,
  required String? activityId,
  required String state,
  required String reason,
  int? recommendationRank,
}) {
  return db
      .insert('learning_progress_projection', <String, Object?>{
        'account_id': 'account-1',
        'learning_path_id': 'path-1',
        'path_element_id': pathElementId,
        'activity_id': activityId,
        'state': state,
        'reason': reason,
        'recommendation_rank': recommendationRank,
        'package_version': 7,
        'updated_at': '2026-09-13T20:00:00.000Z',
      })
      .then((_) {});
}

Future<int> _insertCompletion(
  Database db, {
  required String clientCompletionId,
  required String activityId,
  String accountId = 'account-1',
  String learningPathId = 'path-1',
}) {
  return db.insert('learning_progress_completions', <String, Object?>{
    'client_completion_id': clientCompletionId,
    'account_id': accountId,
    'learning_path_id': learningPathId,
    'activity_id': activityId,
    'revision_id': '$activityId-r1',
    'package_version': 7,
    'completed_at': '2026-09-13T20:00:00.000Z',
    'created_at': '2026-09-13T20:00:00.000Z',
  });
}

Future<int> _insertQueueItem(
  Database db, {
  required int entityId,
  required String status,
}) {
  return db.insert('sync_queue', <String, Object?>{
    'entity_type': 'learning_progress_completion',
    'entity_id': entityId,
    'sync_status': status,
  });
}
