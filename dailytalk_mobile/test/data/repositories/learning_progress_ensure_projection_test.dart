import 'dart:io';

import 'package:dailytalk_mobile/data/database/app_database.dart';
import 'package:dailytalk_mobile/data/repositories/learning_progress_repository.dart';
import 'package:dailytalk_mobile/domain/learning/learning_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _referencePath =
    '../dailytalk-api/docs/phase2/official_reference_journey_v3.json';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Database db;
  late LearningPath path;
  late LearningProgressRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'dailytalk-ensure-projection-',
    );

    db = await AppDatabase.instance.openDatabaseForTesting(
      p.join(tempDir.path, 'progress.db'),
    );

    path = const LearningContentCodec().decodeString(
      File(_referencePath).readAsStringSync(),
    );

    repository = LearningProgressRepository(db);
  });

  tearDown(() async {
    if (db.isOpen) {
      await db.close();
    }

    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'conta nova offline recebe projeção completa sem criar outbox',
    () async {
      expect(await db.query('learning_progress_projection'), isEmpty);

      expect(await db.query('learning_progress_completions'), isEmpty);

      final rebuilt = await repository.ensureProjection(
        accountId: 'offline-new-user',
        learningPath: path,
        activePackageVersion: 3,
      );

      expect(rebuilt, isTrue);

      final rows = await _projectionRows(
        db,
        accountId: 'offline-new-user',
        pathId: path.id.value,
      );

      expect(rows, hasLength(_elementCount(path)));

      expect(rows.every((row) => row['package_version'] == 3), isTrue);

      // Com zero factos, pelo menos uma atividade sem pré-requisitos
      // deve estar imediatamente disponível localmente.
      expect(
        rows.any(
          (row) =>
              row['activity_id'] != null &&
              row['state'] == LearningActivityState.available.name,
        ),
        isTrue,
      );

      expect(await db.query('learning_progress_completions'), isEmpty);

      expect(await db.query('sync_queue'), isEmpty);
    },
  );

  test('segunda chamada é idempotente', () async {
    final first = await repository.ensureProjection(
      accountId: 'idempotent-user',
      learningPath: path,
      activePackageVersion: 3,
    );

    expect(first, isTrue);

    final before = await _projectionRows(
      db,
      accountId: 'idempotent-user',
      pathId: path.id.value,
    );

    final second = await repository.ensureProjection(
      accountId: 'idempotent-user',
      learningPath: path,
      activePackageVersion: 3,
    );

    expect(second, isFalse);

    final after = await _projectionRows(
      db,
      accountId: 'idempotent-user',
      pathId: path.id.value,
    );

    expect(after, before);
    expect(await db.query('sync_queue'), isEmpty);
  });

  test('mudança de packageVersion força reconstrução local', () async {
    await repository.ensureProjection(
      accountId: 'upgrade-user',
      learningPath: path,
      activePackageVersion: 3,
    );

    final rebuilt = await repository.ensureProjection(
      accountId: 'upgrade-user',
      learningPath: path,
      activePackageVersion: 4,
    );

    expect(rebuilt, isTrue);

    final rows = await _projectionRows(
      db,
      accountId: 'upgrade-user',
      pathId: path.id.value,
    );

    expect(rows.every((row) => row['package_version'] == 4), isTrue);

    expect(await db.query('sync_queue'), isEmpty);
  });

  test('fallback para pacote anterior também reconstrói a projeção', () async {
    await repository.ensureProjection(
      accountId: 'fallback-user',
      learningPath: path,
      activePackageVersion: 4,
    );

    final rebuilt = await repository.ensureProjection(
      accountId: 'fallback-user',
      learningPath: path,
      activePackageVersion: 3,
    );

    expect(rebuilt, isTrue);

    final rows = await _projectionRows(
      db,
      accountId: 'fallback-user',
      pathId: path.id.value,
    );

    expect(rows.every((row) => row['package_version'] == 3), isTrue);

    expect(await db.query('sync_queue'), isEmpty);
  });

  test('reconstrução preserva inProgress local', () async {
    const accountId = 'in-progress-user';

    await repository.ensureProjection(
      accountId: accountId,
      learningPath: path,
      activePackageVersion: 3,
    );

    final rows = await _projectionRows(
      db,
      accountId: accountId,
      pathId: path.id.value,
    );

    final candidate = rows.firstWhere(
      (row) =>
          row['activity_id'] is String &&
          row['state'] == LearningActivityState.available.name,
    );

    final activityId = candidate['activity_id']! as String;
    final elementId = candidate['path_element_id']! as String;

    await db.update(
      'learning_progress_projection',
      <String, Object?>{
        'state': LearningActivityState.inProgress.name,
        'reason': ProgressionReason.attemptStarted.name,
      },
      where:
          'account_id = ? AND learning_path_id = ? '
          'AND path_element_id = ?',
      whereArgs: <Object?>[accountId, path.id.value, elementId],
    );

    final rebuilt = await repository.ensureProjection(
      accountId: accountId,
      learningPath: path,
      activePackageVersion: 3,
      forceRebuild: true,
    );

    expect(rebuilt, isTrue);

    final after = await _projectionRows(
      db,
      accountId: accountId,
      pathId: path.id.value,
    );

    final preserved = after.singleWhere(
      (row) => row['activity_id'] == activityId,
    );

    expect(preserved['state'], LearningActivityState.inProgress.name);

    expect(preserved['reason'], ProgressionReason.attemptStarted.name);

    expect(await db.query('sync_queue'), isEmpty);
  });
}

Future<List<Map<String, Object?>>> _projectionRows(
  Database db, {
  required String accountId,
  required String pathId,
}) {
  return db.query(
    'learning_progress_projection',
    where: 'account_id = ? AND learning_path_id = ?',
    whereArgs: <Object?>[accountId, pathId],
    orderBy: 'path_element_id',
  );
}

int _elementCount(LearningPath path) {
  var count = 0;

  for (final journey in path.journeys) {
    for (final stage in journey.stages) {
      count += stage.elements.length;
    }
  }

  return count;
}
