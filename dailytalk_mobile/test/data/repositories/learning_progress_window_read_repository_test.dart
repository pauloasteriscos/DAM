import 'package:dailytalk_mobile/data/repositories/learning_progress_read_repository.dart';
import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late LearningProgressReadRepository repository;

  setUpAll(sqfliteFfiInit);

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
        id INTEGER PRIMARY KEY,
        account_id TEXT NOT NULL,
        learning_path_id TEXT NOT NULL,
        activity_id TEXT NOT NULL
      )
      ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        sync_status TEXT NOT NULL
      )
      ''');

    await db.insert(
      'learning_progress_projection',
      _projectionRow(
        elementId: 'element-a',
        activityId: 'activity-a',
        recommendationRank: 1,
      ),
    );

    await db.insert(
      'learning_progress_projection',
      _projectionRow(elementId: 'element-b', activityId: 'activity-b'),
    );

    await db.insert(
      'learning_progress_projection',
      _projectionRow(
        elementId: 'element-c',
        activityId: 'activity-c',
        recommendationRank: 0,
      ),
    );

    await db.insert(
      'learning_progress_projection',
      _projectionRow(
        accountId: 'other-account',
        elementId: 'other-element',
        activityId: 'other-activity',
        recommendationRank: 0,
      ),
    );

    await db.insert('learning_progress_completions', <String, Object?>{
      'id': 1,
      'account_id': 'account-1',
      'learning_path_id': 'path-1',
      'activity_id': 'activity-a',
    });

    await db.insert('learning_progress_completions', <String, Object?>{
      'id': 2,
      'account_id': 'account-1',
      'learning_path_id': 'path-1',
      'activity_id': 'activity-b',
    });

    await db.insert('learning_progress_completions', <String, Object?>{
      'id': 3,
      'account_id': 'account-1',
      'learning_path_id': 'path-1',
      'activity_id': 'activity-a',
    });

    await db.insert('sync_queue', <String, Object?>{
      'id': 1,
      'entity_type': 'learning_progress_completion',
      'entity_id': 1,
      'sync_status': 'pending',
    });

    await db.insert('sync_queue', <String, Object?>{
      'id': 2,
      'entity_type': 'learning_progress_completion',
      'entity_id': 2,
      'sync_status': 'synced',
    });

    await db.insert('sync_queue', <String, Object?>{
      'id': 3,
      'entity_type': 'learning_progress_completion',
      'entity_id': 3,
      'sync_status': 'failed',
    });

    repository = LearningProgressReadRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('projection read returns only requested path elements', () async {
    final result = await repository.readProjectionForPathElements(
      accountId: ' account-1 ',
      learningPathId: ' path-1 ',
      pathElementIds: const <String>[' element-c ', 'element-a', 'element-a'],
    );

    expect(result, hasLength(2));

    expect(result.map((entry) => entry.pathElementId).toSet(), <String>{
      'element-a',
      'element-c',
    });
  });

  test('projection read chunks large id windows', () async {
    final ids = <String>[
      'element-a',
      'element-c',
      ...List<String>.generate(399, (index) => 'missing-$index'),
    ];

    expect(ids, hasLength(401));

    final result = await repository.readProjectionForPathElements(
      accountId: 'account-1',
      learningPathId: 'path-1',
      pathElementIds: ids,
    );

    expect(result, hasLength(2));

    expect(result.map((entry) => entry.pathElementId).toSet(), <String>{
      'element-a',
      'element-c',
    });
  });

  test('recommendation read stays global for requested path', () async {
    final result = await repository.readRecommendedProjection(
      accountId: 'account-1',
      learningPathId: 'path-1',
    );

    expect(result, hasLength(2));

    expect(result.map((entry) => entry.pathElementId).toSet(), <String>{
      'element-a',
      'element-c',
    });

    expect(result.every((entry) => entry.recommendationRank != null), isTrue);
  });

  test(
    'sync read filters activities and keeps strongest queue state',
    () async {
      final result = await repository.readActivitySyncStatesForActivities(
        accountId: 'account-1',
        learningPathId: 'path-1',
        activityIds: const <String>['activity-a'],
      );

      expect(result, <String, ProgressSyncState>{
        'activity-a': ProgressSyncState.failed,
      });

      final both = await repository.readActivitySyncStatesForActivities(
        accountId: 'account-1',
        learningPathId: 'path-1',
        activityIds: const <String>['activity-a', 'activity-b'],
      );

      expect(both['activity-a'], ProgressSyncState.failed);

      expect(both['activity-b'], ProgressSyncState.clean);
    },
  );

  test('empty windows short-circuit and blank ids fail closed', () async {
    expect(
      await repository.readProjectionForPathElements(
        accountId: 'account-1',
        learningPathId: 'path-1',
        pathElementIds: const <String>[],
      ),
      isEmpty,
    );

    expect(
      await repository.readActivitySyncStatesForActivities(
        accountId: 'account-1',
        learningPathId: 'path-1',
        activityIds: const <String>[],
      ),
      isEmpty,
    );

    await expectLater(
      repository.readProjectionForPathElements(
        accountId: 'account-1',
        learningPathId: 'path-1',
        pathElementIds: const <String>[' '],
      ),
      throwsArgumentError,
    );

    await expectLater(
      repository.readActivitySyncStatesForActivities(
        accountId: 'account-1',
        learningPathId: 'path-1',
        activityIds: const <String>[' '],
      ),
      throwsArgumentError,
    );
  });
}

Map<String, Object?> _projectionRow({
  String accountId = 'account-1',
  String pathId = 'path-1',
  required String elementId,
  required String activityId,
  int? recommendationRank,
}) {
  return <String, Object?>{
    'account_id': accountId,
    'learning_path_id': pathId,
    'path_element_id': elementId,
    'activity_id': activityId,
    'state': 'available',
    'reason': 'ready',
    'recommendation_rank': recommendationRank,
    'package_version': 9,
    'updated_at': '2026-09-14T10:00:00.000Z',
  };
}
