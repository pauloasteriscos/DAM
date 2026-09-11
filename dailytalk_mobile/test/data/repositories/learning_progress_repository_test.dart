import 'dart:convert';
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
      'dailytalk-learning-progress-',
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

  CompleteLearningActivityWrite command(
    LearningPath learningPath, {
    String clientCompletionId = 'device-a-completion-0001',
    String activityId = 'arrival.dialogue-01',
    RevisionId? revisionId,
  }) {
    final activity = learningPath.activities.singleWhere(
      (candidate) => candidate.id.value == activityId,
    );

    return CompleteLearningActivityWrite(
      clientCompletionId: clientCompletionId,
      accountId: 'user-phase3',
      learningPath: learningPath,
      activityId: activity.id,
      revisionId: revisionId ?? activity.currentRevisionId,
      packageVersion: 3,
      completedAt: DateTime.utc(2026, 9, 10, 16),
      practicePreference: PracticePreference.dialogue,
    );
  }

  Future<Map<String, Object?>> projection(
    Database database,
    String elementId,
  ) async {
    final rows = await database.query(
      'learning_progress_projection',
      where:
          'account_id = ? AND learning_path_id = ? '
          'AND path_element_id = ?',
      whereArgs: <Object?>['user-phase3', 'student.fr-fr.phase1', elementId],
    );

    expect(
      rows,
      hasLength(1),
      reason: 'Projeção não encontrada para $elementId',
    );

    return rows.single;
  }

  group('LearningProgressRepository — Fase 3.2B', () {
    test(
      'percurso oficial é reavaliado pelo ProgressionEngine dentro da conclusão',
      () async {
        final learningPath = _loadReferenceJourney();

        final activity = learningPath.activities.singleWhere(
          (candidate) => candidate.id.value == 'arrival.dialogue-01',
        );

        const engine = DefaultProgressionEngine();

        final before = engine.evaluate(
          ProgressionRequest(
            learningPath: learningPath,
            facts: ProgressionFacts(),
            practicePreference: PracticePreference.dialogue,
          ),
        );

        expect(
          before.decisions[PathElementId('arrival.dialogue-02.element')]?.state,
          LearningActivityState.locked,
        );

        final path = p.join(tempDir.path, 'official-engine-completion.db');

        db = await AppDatabase.instance.openDatabaseForTesting(path);

        final repository = LearningProgressRepository(db!);

        final result = await repository.completeActivity(command(learningPath));

        expect(result.alreadyCompleted, isFalse);

        final completions = await db!.query('learning_progress_completions');

        expect(completions, hasLength(1));
        expect(completions.single['activity_id'], 'arrival.dialogue-01');
        expect(
          completions.single['revision_id'],
          activity.currentRevisionId.value,
        );

        // As evidências vêm da revisão, não do chamador.
        final expectedCompetencies = activity.currentRevision.competencies
            .map((id) => id.value)
            .toSet();

        final evidence = await db!.query('learning_competency_evidence');

        final actualCompetencies = evidence
            .map((row) => row['competency_id']! as String)
            .toSet();

        expect(actualCompetencies, equals(expectedCompetencies));

        // A projeção deve representar todo o percurso atual.
        final expectedElementCount = learningPath.journeys
            .expand((journey) => journey.stages)
            .expand((stage) => stage.elements)
            .length;

        final projectionRows = await db!.query(
          'learning_progress_projection',
          where: 'account_id = ? AND learning_path_id = ?',
          whereArgs: const <Object?>['user-phase3', 'student.fr-fr.phase1'],
        );

        expect(projectionRows, hasLength(expectedElementCount));

        expect(
          (await projection(db!, 'arrival.dialogue-01.element'))['state'],
          'completed',
        );

        // Caso real já especificado pelo percurso oficial.
        expect(
          (await projection(db!, 'arrival.dialogue-02.element'))['state'],
          'available',
        );

        expect(
          (await projection(db!, 'arrival.quiz-01.element'))['state'],
          'available',
        );

        expect(
          (await projection(db!, 'arrival.vocabulary-02.element'))['state'],
          'locked',
        );

        final queue = await db!.query(
          'sync_queue',
          where: 'entity_type = ?',
          whereArgs: const <Object?>['learning_progress_completion'],
        );

        expect(queue, hasLength(1));
        expect(queue.single['sync_status'], 'pending');
        expect(queue.single['operation'], 'ActivityCompleted');

        final payload =
            jsonDecode(queue.single['payload_json']! as String)
                as Map<String, dynamic>;

        expect(payload['clientCompletionId'], 'device-a-completion-0001');

        expect(payload['activityId'], 'arrival.dialogue-01');

        expect(payload['revisionId'], activity.currentRevisionId.value);

        expect(
          Set<String>.from(payload['competencyIds'] as List),
          equals(expectedCompetencies),
        );

        // Durabilidade: fechar/reabrir sem rede.
        await db!.close();
        db = null;

        db = await AppDatabase.instance.openDatabaseForTesting(path);

        expect(await db!.query('learning_progress_completions'), hasLength(1));

        expect(
          (await projection(db!, 'arrival.dialogue-02.element'))['state'],
          'available',
        );

        final reopenedQueue = await db!.query(
          'sync_queue',
          where: 'entity_type = ?',
          whereArgs: const <Object?>['learning_progress_completion'],
        );

        expect(reopenedQueue, hasLength(1));
      },
    );

    test('retry com o mesmo clientCompletionId continua idempotente', () async {
      final learningPath = _loadReferenceJourney();

      final path = p.join(tempDir.path, 'idempotent-engine.db');

      db = await AppDatabase.instance.openDatabaseForTesting(path);

      final repository = LearningProgressRepository(db!);
      final sameCommand = command(learningPath);

      final first = await repository.completeActivity(sameCommand);

      final completionCount = (await db!.query(
        'learning_progress_completions',
      )).length;

      final evidenceCount = (await db!.query(
        'learning_competency_evidence',
      )).length;

      final projectionCount = (await db!.query(
        'learning_progress_projection',
      )).length;

      final queueCount = (await db!.query(
        'sync_queue',
        where: 'entity_type = ?',
        whereArgs: const <Object?>['learning_progress_completion'],
      )).length;

      final second = await repository.completeActivity(sameCommand);

      expect(first.alreadyCompleted, isFalse);
      expect(second.alreadyCompleted, isTrue);
      expect(second.completionId, first.completionId);

      expect(
        await db!.query('learning_progress_completions'),
        hasLength(completionCount),
      );

      expect(
        await db!.query('learning_competency_evidence'),
        hasLength(evidenceCount),
      );

      expect(
        await db!.query('learning_progress_projection'),
        hasLength(projectionCount),
      );

      expect(
        await db!.query(
          'sync_queue',
          where: 'entity_type = ?',
          whereArgs: const <Object?>['learning_progress_completion'],
        ),
        hasLength(queueCount),
      );
    });

    test(
      'mesmo clientCompletionId não pode representar outra atividade',
      () async {
        final learningPath = _loadReferenceJourney();

        final path = p.join(tempDir.path, 'conflicting-id.db');

        db = await AppDatabase.instance.openDatabaseForTesting(path);

        final repository = LearningProgressRepository(db!);

        await repository.completeActivity(command(learningPath));

        await expectLater(
          repository.completeActivity(
            command(learningPath, activityId: 'arrival.speech-01'),
          ),
          throwsA(isA<StateError>()),
        );

        expect(await db!.query('learning_progress_completions'), hasLength(1));

        expect(
          await db!.query(
            'sync_queue',
            where: 'entity_type = ?',
            whereArgs: const <Object?>['learning_progress_completion'],
          ),
          hasLength(1),
        );
      },
    );

    test(
      'falha na outbox reverte conclusão, evidência e projeção calculada',
      () async {
        final learningPath = _loadReferenceJourney();

        final path = p.join(tempDir.path, 'rollback-engine.db');

        db = await AppDatabase.instance.openDatabaseForTesting(path);

        final repository = LearningProgressRepository(db!);

        await db!.execute('''
          CREATE TRIGGER phase3_force_outbox_failure
          BEFORE INSERT ON sync_queue
          WHEN NEW.entity_type = 'learning_progress_completion'
          BEGIN
            SELECT RAISE(
              ABORT,
              'forced phase3 outbox failure'
            );
          END
          ''');

        await expectLater(
          repository.completeActivity(command(learningPath)),
          throwsA(isA<DatabaseException>()),
        );

        expect(await db!.query('learning_progress_completions'), isEmpty);

        expect(await db!.query('learning_competency_evidence'), isEmpty);

        expect(await db!.query('learning_progress_projection'), isEmpty);

        expect(
          await db!.query(
            'sync_queue',
            where: 'entity_type = ?',
            whereArgs: const <Object?>['learning_progress_completion'],
          ),
          isEmpty,
        );

        expect(await db!.rawQuery('PRAGMA foreign_key_check'), isEmpty);

        final integrity = await db!.rawQuery('PRAGMA integrity_check');

        expect(integrity.first.values.first, 'ok');
      },
    );

    test(
      'revisão histórica concluída preserva revisionId e respetivas evidências',
      () async {
        final learningPath = _loadReferenceJourney();

        final vocabulary = learningPath.activities.singleWhere(
          (activity) => activity.id.value == 'arrival.vocabulary-01',
        );

        expect(vocabulary.revisions.length, greaterThan(1));

        final historicalRevision = vocabulary.revisions.first;

        final path = p.join(tempDir.path, 'historical-revision.db');

        db = await AppDatabase.instance.openDatabaseForTesting(path);

        final repository = LearningProgressRepository(db!);

        await repository.completeActivity(
          command(
            learningPath,
            clientCompletionId: 'device-a-historical-revision-0001',
            activityId: vocabulary.id.value,
            revisionId: historicalRevision.id,
          ),
        );

        final completions = await db!.query('learning_progress_completions');

        expect(completions, hasLength(1));

        expect(completions.single['revision_id'], historicalRevision.id.value);

        final evidence = await db!.query('learning_competency_evidence');

        final expectedCompetencies = historicalRevision.competencies
            .map((id) => id.value)
            .toSet();

        final actualCompetencies = evidence
            .map((row) => row['competency_id']! as String)
            .toSet();

        expect(actualCompetencies, equals(expectedCompetencies));

        final queue = await db!.query(
          'sync_queue',
          where: 'entity_type = ?',
          whereArgs: const <Object?>['learning_progress_completion'],
        );

        expect(queue, hasLength(1));

        final payload =
            jsonDecode(queue.single['payload_json']! as String)
                as Map<String, dynamic>;

        expect(payload['revisionId'], historicalRevision.id.value);
      },
    );
  });
}
