import 'package:dailytalk_mobile/data/repositories/learning_progress_read_repository.dart';
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
        PRIMARY KEY (
          account_id,
          learning_path_id,
          path_element_id
        )
      )
      ''');

    repository = LearningProgressReadRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'counts mirror activity-element semantics and ignore structural rows',
    () async {
      await _insert(
        db,
        elementId: 'activity-element-a1',
        activityId: 'activity-a',
        state: 'completed',
      );

      await _insert(
        db,
        elementId: 'activity-element-a2',
        activityId: 'activity-a',
        state: 'completed',
      );

      await _insert(
        db,
        elementId: 'activity-element-b',
        activityId: 'activity-b',
        state: 'available',
      );

      await _insert(
        db,
        elementId: 'checkpoint',
        activityId: null,
        state: 'completed',
      );

      await _insert(
        db,
        accountId: 'other-account',
        elementId: 'other',
        activityId: 'other-activity',
        state: 'completed',
      );

      final counts = await repository.readProjectionCounts(
        accountId: ' account-1 ',
        learningPathId: ' path-1 ',
      );

      expect(counts.projectionRowCount, 4);
      expect(counts.totalActivityCount, 3);
      expect(counts.completedActivityCount, 2);
      expect(counts.minPackageVersion, 9);
      expect(counts.maxPackageVersion, 9);
    },
  );

  test(
    'empty projection returns zero counts without package version',
    () async {
      final counts = await repository.readProjectionCounts(
        accountId: 'account-1',
        learningPathId: 'path-1',
      );

      expect(counts.projectionRowCount, 0);
      expect(counts.totalActivityCount, 0);
      expect(counts.completedActivityCount, 0);
      expect(counts.minPackageVersion, isNull);
      expect(counts.maxPackageVersion, isNull);
    },
  );

  test('mixed package versions remain detectable by the caller', () async {
    await _insert(
      db,
      elementId: 'element-a',
      activityId: 'activity-a',
      state: 'available',
      packageVersion: 9,
    );

    await _insert(
      db,
      elementId: 'element-b',
      activityId: 'activity-b',
      state: 'available',
      packageVersion: 10,
    );

    final counts = await repository.readProjectionCounts(
      accountId: 'account-1',
      learningPathId: 'path-1',
    );

    expect(counts.projectionRowCount, 2);
    expect(counts.totalActivityCount, 2);
    expect(counts.minPackageVersion, 9);
    expect(counts.maxPackageVersion, 10);
  });
}

Future<void> _insert(
  Database db, {
  String accountId = 'account-1',
  String pathId = 'path-1',
  required String elementId,
  required String? activityId,
  required String state,
  int packageVersion = 9,
}) {
  return db.insert('learning_progress_projection', <String, Object?>{
    'account_id': accountId,
    'learning_path_id': pathId,
    'path_element_id': elementId,
    'activity_id': activityId,
    'state': state,
    'reason': state == 'completed' ? 'completed' : 'ready',
    'recommendation_rank': null,
    'package_version': packageVersion,
    'updated_at': '2026-09-14T12:00:00.000Z',
  });
}
