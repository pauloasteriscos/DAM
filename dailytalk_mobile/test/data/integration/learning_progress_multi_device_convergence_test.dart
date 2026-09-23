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

const _accountId = 'user-phase35d';
const _packageVersion = 3;

final class _InMemoryProgressServer extends DailyTalkApiService {
  final List<Map<String, dynamic>> _feed = <Map<String, dynamic>>[];

  final Map<String, Map<String, dynamic>> _byClientId =
      <String, Map<String, dynamic>>{};

  int _sequence = 0;

  @override
  Future<Map<String, dynamic>> secureSyncProgress(
    List<Map<String, dynamic>> items, {
    bool pullLearningProgress = false,
    String? learningProgressCursor,
    String? learningProgressPathId,
    int learningProgressLimit = 50,
  }) async {
    final results = <Map<String, dynamic>>[];

    for (final raw in items) {
      final item = Map<String, dynamic>.from(raw);

      final clientCompletionId = item['clientCompletionId']?.toString() ?? '';

      if (clientCompletionId.isEmpty) {
        throw StateError('clientCompletionId vazio.');
      }

      final existing = _byClientId[clientCompletionId];

      if (existing != null) {
        for (final key in <String>[
          'learningPathId',
          'activityId',
          'revisionId',
          'completedAt',
        ]) {
          if (existing[key] != item[key]) {
            throw StateError(
              'Retry alterou facto já aceite: $clientCompletionId.',
            );
          }
        }

        if (existing['packageVersion'] != item['packageVersion']) {
          throw StateError('Retry alterou packageVersion.');
        }

        results.add(<String, dynamic>{
          'type': 'activityCompletion',
          'clientCompletionId': clientCompletionId,
          'completionId': existing['completionId'],
          'status': 'duplicate',
          'activityId': existing['activityId'],
          'revisionId': existing['revisionId'],
        });

        continue;
      }

      _sequence += 1;

      final completionId = 'server-${_sequence.toString().padLeft(4, '0')}';

      final fact = <String, dynamic>{
        'type': 'activityCompletion',
        'completionId': completionId,
        'clientCompletionId': clientCompletionId,
        'learningPathId': item['learningPathId'],
        'activityId': item['activityId'],
        'revisionId': item['revisionId'],
        'packageVersion': item['packageVersion'],
        'completedAt': item['completedAt'],
      };

      _feed.add(fact);
      _byClientId[clientCompletionId] = fact;

      results.add(<String, dynamic>{
        'type': 'activityCompletion',
        'clientCompletionId': clientCompletionId,
        'completionId': completionId,
        'status': 'accepted',
        'activityId': fact['activityId'],
        'revisionId': fact['revisionId'],
      });
    }

    final response = <String, dynamic>{'results': results};

    if (!pullLearningProgress) {
      return response;
    }

    final normalizedPathId = learningProgressPathId?.trim();

    if (normalizedPathId == null || normalizedPathId.isEmpty) {
      throw StateError('learningProgressPathId ausente no pull multi-device.');
    }

    final pathFeed = _feed
        .where((fact) => fact['learningPathId'] == normalizedPathId)
        .toList(growable: false);

    var start = 0;

    if (learningProgressCursor != null) {
      final cursorIndex = pathFeed.indexWhere(
        (fact) => fact['completionId'] == learningProgressCursor,
      );

      if (cursorIndex < 0) {
        throw StateError('Cursor desconhecido: $learningProgressCursor');
      }

      start = cursorIndex + 1;
    }

    final candidateEnd = start + learningProgressLimit;

    final end = candidateEnd < pathFeed.length ? candidateEnd : pathFeed.length;

    final page = pathFeed
        .sublist(start, end)
        .map(Map<String, dynamic>.from)
        .toList(growable: false);

    final nextCursor = page.isEmpty
        ? learningProgressCursor
        : page.last['completionId'] as String;

    response['pull'] = <String, dynamic>{
      'learningProgress': <String, dynamic>{
        'items': page,
        'nextCursor': nextCursor,
        'hasMore': end < pathFeed.length,
      },
    };

    return response;
  }
}

LearningPath _loadJourney() {
  final source = File(_referencePath).readAsStringSync();

  return const LearningContentCodec().decodeString(source);
}

Activity _activity(LearningPath path, String id) {
  return path.activities.singleWhere((activity) => activity.id.value == id);
}

Future<void> _complete({
  required LearningProgressRepository repository,
  required LearningPath path,
  required String activityId,
  required String clientCompletionId,
  required DateTime completedAt,
}) async {
  final activity = _activity(path, activityId);

  await repository.completeActivity(
    CompleteLearningActivityWrite(
      clientCompletionId: clientCompletionId,
      accountId: _accountId,
      learningPath: path,
      activityId: activity.id,
      revisionId: activity.currentRevisionId,
      packageVersion: _packageVersion,
      completedAt: completedAt,
    ),
  );
}

ReconcileLearningProgressCommand _reconcile({
  required DailyTalkApiService server,
  required Database db,
  required LearningPath path,
}) {
  return ReconcileLearningProgressCommand(
    apiService: server,
    syncQueueDao: SyncQueueDao(db),
    repository: LearningProgressRepository(db),
    accountId: _accountId,
    learningPath: path,
    activePackageVersion: _packageVersion,
  );
}

Future<Set<String>> _completedActivities(Database db) async {
  final rows = await db.rawQuery(
    '''
    SELECT DISTINCT activity_id
    FROM learning_progress_completions
    WHERE account_id = ?
    ORDER BY activity_id
    ''',
    const <Object?>[_accountId],
  );

  return rows.map((row) => row['activity_id']! as String).toSet();
}

Future<Set<String>> _competencies(Database db) async {
  final rows = await db.rawQuery(
    '''
    SELECT DISTINCT e.competency_id
    FROM learning_competency_evidence e
    INNER JOIN learning_progress_completions c
      ON c.id = e.completion_id
    WHERE c.account_id = ?
    ORDER BY e.competency_id
    ''',
    const <Object?>[_accountId],
  );

  return rows.map((row) => row['competency_id']! as String).toSet();
}

Future<List<Map<String, Object?>>> _projection(
  Database db,
  LearningPath path,
) async {
  final rows = await db.query(
    'learning_progress_projection',
    where: 'account_id = ? AND learning_path_id = ?',
    whereArgs: <Object?>[_accountId, path.id.value],
    orderBy: 'path_element_id ASC',
  );

  return rows
      .map(
        (row) => <String, Object?>{
          'path_element_id': row['path_element_id'],
          'activity_id': row['activity_id'],
          'state': row['state'],
          'reason': row['reason'],
          'recommendation_rank': row['recommendation_rank'],
          'package_version': row['package_version'],
        },
      )
      .toList(growable: false);
}

Future<String?> _stateForActivity(
  Database db,
  LearningPath path,
  String activityId,
) async {
  final rows = await db.query(
    'learning_progress_projection',
    columns: const <String>['state'],
    where:
        'account_id = ? '
        'AND learning_path_id = ? '
        'AND activity_id = ?',
    whereArgs: <Object?>[_accountId, path.id.value, activityId],
    limit: 1,
  );

  if (rows.isEmpty) {
    return null;
  }

  return rows.single['state'] as String?;
}

Future<void> _expectOutboxSynced(Database db) async {
  final rows = await db.query(
    'sync_queue',
    columns: const <String>['sync_status'],
    where: 'entity_type = ?',
    whereArgs: const <Object?>['learning_progress_completion'],
  );

  expect(rows, isNotEmpty);

  for (final row in rows) {
    expect(row['sync_status'], 'synced');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  Database? dbA;
  Database? dbB;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dailytalk-phase35d-');
  });

  tearDown(() async {
    for (final db in <Database?>[dbA, dbB]) {
      if (db != null && db.isOpen) {
        await db.close();
      }
    }

    dbA = null;
    dbB = null;

    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    '3.5D — A e B avançam offline em ramos diferentes e convergem para a união',
    () async {
      final path = _loadJourney();

      dbA = await AppDatabase.instance.openDatabaseForTesting(
        p.join(tempDir.path, 'device-a.db'),
      );

      dbB = await AppDatabase.instance.openDatabaseForTesting(
        p.join(tempDir.path, 'device-b.db'),
      );

      final repositoryA = LearningProgressRepository(dbA!);

      final repositoryB = LearningProgressRepository(dbB!);

      final server = _InMemoryProgressServer();

      // ---------------------------------------------------------
      // 1. A e B trabalham totalmente offline.
      // ---------------------------------------------------------
      //
      // A segue Vocabulário.
      await _complete(
        repository: repositoryA,
        path: path,
        activityId: 'arrival.vocabulary-01',
        clientCompletionId: 'device-a-vocabulary-01',
        completedAt: DateTime.utc(2026, 9, 13, 10),
      );

      // B segue Fala.
      await _complete(
        repository: repositoryB,
        path: path,
        activityId: 'arrival.speech-01',
        clientCompletionId: 'device-b-speech-01',
        completedAt: DateTime.utc(2026, 9, 13, 10, 1),
      );

      // A e B também concluem independentemente a mesma atividade.
      // São dois factos de transporte válidos, mas uma única atividade
      // global para efeitos de progressão/pontuação base.
      await _complete(
        repository: repositoryA,
        path: path,
        activityId: 'arrival.dialogue-01',
        clientCompletionId: 'device-a-dialogue-01',
        completedAt: DateTime.utc(2026, 9, 13, 10, 2),
      );

      await _complete(
        repository: repositoryB,
        path: path,
        activityId: 'arrival.dialogue-01',
        clientCompletionId: 'device-b-dialogue-01',
        completedAt: DateTime.utc(2026, 9, 13, 10, 3),
      );

      expect(await _completedActivities(dbA!), <String>{
        'arrival.vocabulary-01',
        'arrival.dialogue-01',
      });

      expect(await _completedActivities(dbB!), <String>{
        'arrival.speech-01',
        'arrival.dialogue-01',
      });

      // ---------------------------------------------------------
      // 2. A sincroniza primeiro.
      // ---------------------------------------------------------

      expect(
        (await _reconcile(
          server: server,
          db: dbA!,
          path: path,
        ).execute()).success,
        isTrue,
      );

      // ---------------------------------------------------------
      // 3. B sincroniza e recebe A ∪ B.
      // ---------------------------------------------------------

      expect(
        (await _reconcile(
          server: server,
          db: dbB!,
          path: path,
        ).execute()).success,
        isTrue,
      );

      // ---------------------------------------------------------
      // 4. A faz pull novamente e recebe o que nasceu em B.
      // ---------------------------------------------------------

      expect(
        (await _reconcile(
          server: server,
          db: dbA!,
          path: path,
        ).execute()).success,
        isTrue,
      );

      // Existem quatro factos de conclusão:
      //
      // - vocab A
      // - speech B
      // - dialogue A
      // - dialogue B
      //
      // Mas apenas três ActivityId distintas.
      final factsA = await dbA!.query(
        'learning_progress_completions',
        where: 'account_id = ?',
        whereArgs: const <Object?>[_accountId],
      );

      final factsB = await dbB!.query(
        'learning_progress_completions',
        where: 'account_id = ?',
        whereArgs: const <Object?>[_accountId],
      );

      expect(factsA, hasLength(4));
      expect(factsB, hasLength(4));

      const expectedActivities = <String>{
        'arrival.vocabulary-01',
        'arrival.dialogue-01',
        'arrival.speech-01',
      };

      expect(await _completedActivities(dbA!), expectedActivities);

      expect(await _completedActivities(dbB!), expectedActivities);

      // ---------------------------------------------------------
      // 5. Competências também convergem.
      // ---------------------------------------------------------

      const expectedCompetencies = <String>{
        'arrival.greeting-basics',
        'arrival.pronunciation-basics',
      };

      expect(await _competencies(dbA!), expectedCompetencies);

      expect(await _competencies(dbB!), expectedCompetencies);

      // ---------------------------------------------------------
      // 6. Projeção pedagógica determinística: A == B.
      // ---------------------------------------------------------

      final projectionA = await _projection(dbA!, path);

      final projectionB = await _projection(dbB!, path);

      expect(projectionA, projectionB);

      for (final completed in expectedActivities) {
        expect(await _stateForActivity(dbA!, path, completed), 'completed');

        expect(await _stateForActivity(dbB!, path, completed), 'completed');
      }

      // O ramo de vocabulário desbloqueia vocabulary-02.
      expect(
        await _stateForActivity(dbA!, path, 'arrival.vocabulary-02'),
        'available',
      );

      // A união vocab/dialogue satisfaz dialogue-02.
      expect(
        await _stateForActivity(dbA!, path, 'arrival.dialogue-02'),
        'available',
      );

      // Speech + pronunciation-basics satisfaz speech-02.
      expect(
        await _stateForActivity(dbA!, path, 'arrival.speech-02'),
        'available',
      );

      // greeting-basics satisfaz quiz-01.
      expect(
        await _stateForActivity(dbA!, path, 'arrival.quiz-01'),
        'available',
      );

      // ---------------------------------------------------------
      // 7. Base global de pontuação: DISTINCT activity_id.
      // ---------------------------------------------------------

      expect(
        await repositoryA.readGlobalDistinctCompletedActivityCount(
          accountId: _accountId,
        ),
        3,
      );

      expect(
        await repositoryB.readGlobalDistinctCompletedActivityCount(
          accountId: _accountId,
        ),
        3,
      );

      // ---------------------------------------------------------
      // 8. Outboxes locais foram confirmadas.
      // ---------------------------------------------------------

      await _expectOutboxSynced(dbA!);
      await _expectOutboxSynced(dbB!);

      // ---------------------------------------------------------
      // 9. Repetir pull não infla factos, score nem projeção.
      // ---------------------------------------------------------

      final beforeA = await _projection(dbA!, path);

      final beforeB = await _projection(dbB!, path);

      expect(
        (await _reconcile(
          server: server,
          db: dbA!,
          path: path,
        ).execute()).success,
        isTrue,
      );

      expect(
        (await _reconcile(
          server: server,
          db: dbB!,
          path: path,
        ).execute()).success,
        isTrue,
      );

      expect(
        await dbA!.query(
          'learning_progress_completions',
          where: 'account_id = ?',
          whereArgs: const <Object?>[_accountId],
        ),
        hasLength(4),
      );

      expect(
        await dbB!.query(
          'learning_progress_completions',
          where: 'account_id = ?',
          whereArgs: const <Object?>[_accountId],
        ),
        hasLength(4),
      );

      expect(
        await repositoryA.readGlobalDistinctCompletedActivityCount(
          accountId: _accountId,
        ),
        3,
      );

      expect(
        await repositoryB.readGlobalDistinctCompletedActivityCount(
          accountId: _accountId,
        ),
        3,
      );

      expect(await _projection(dbA!, path), beforeA);

      expect(await _projection(dbB!, path), beforeB);

      expect(await _projection(dbA!, path), await _projection(dbB!, path));
    },
  );
}
