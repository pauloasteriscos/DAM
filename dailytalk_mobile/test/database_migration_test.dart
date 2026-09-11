import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dailytalk_mobile/data/database/app_database.dart';

const _historicActivityId = 1;
const _historicStudentId = 1;
const _historicSubmissionId = 1;
const _historicRemoteActivityId = 'fase0-historic-activity';
const _historicStudentRemoteId = 'fase0-historic-student';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'dailytalk-sqlite-migration-',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('DailyTalk SQLite — Fase 2.3 — catálogo e assets', () {
    test('base nova v6 cria schema esperado e invariantes locais', () async {
      final path = p.join(tempDir.path, 'fresh-v6.db');
      final db = await AppDatabase.instance.openDatabaseForTesting(path);

      expect(await db.getVersion(), 6);
      expect(await _foreignKeysEnabled(db), isTrue);
      expect(await _integrityCheck(db), 'ok');

      final tables = await _userTables(db);
      expect(
        tables,
        containsAll(<String>[
          'activities',
          'activity_params',
          'students',
          'submissions',
          'submission_results',
          'analytics_definitions',
          'analytics_records',
          'sync_queue',
          'local_private_notes',
          'app_settings',
          'learning_content_packages',
          'learning_content_catalog',
          'learning_content_asset_manifests',
          'learning_content_asset_entries',
          'learning_content_asset_cache',
        ]),
      );

      expect(
        await _columnExists(db, 'submissions', 'client_submission_id'),
        isTrue,
      );
      expect(
        await _indexExists(db, 'idx_submissions_client_submission_id'),
        isTrue,
      );

      expect(
        await _indexExists(db, 'idx_learning_content_packages_path_hash'),
        isTrue,
      );
      expect(
        await _indexExists(db, 'idx_learning_content_catalog_active'),
        isTrue,
      );
      expect(
        await _indexExists(
          db,
          'idx_learning_content_asset_entries_revision_role',
        ),
        isTrue,
      );
      expect(
        await _indexExists(db, 'idx_learning_content_asset_entries_hash'),
        isTrue,
      );
      expect(
        await _indexExists(db, 'idx_learning_content_asset_cache_access'),
        isTrue,
      );

      final settings = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['database_version'],
      );
      expect(settings, hasLength(1));
      expect(settings.single['value'], '6');

      await db.close();
    });

    test(
      'v1 → v6 preserva dados e acrescenta catálogo + assets + notas',
      () async {
        final path = await _createHistoricalDatabase(tempDir, version: 1);

        final db = await AppDatabase.instance.openDatabaseForTesting(path);

        expect(await db.getVersion(), 6);
        expect(await _foreignKeysEnabled(db), isTrue);
        expect(await _integrityCheck(db), 'ok');

        await _assertHistoricDataPreserved(db);

        expect(await _tableExists(db, 'local_private_notes'), isTrue);
        expect(
          await _columnExists(db, 'submissions', 'client_submission_id'),
          isTrue,
        );
        expect(
          await _indexExists(db, 'idx_submissions_client_submission_id'),
          isTrue,
        );

        final submissions = await db.query(
          'submissions',
          where: 'id = ?',
          whereArgs: [_historicSubmissionId],
        );
        expect(submissions, hasLength(1));
        final clientId = submissions.single['client_submission_id']?.toString();
        expect(clientId, isNotNull);
        expect(clientId, isNotEmpty);
        expect(clientId, startsWith('legacy-1-'));

        await _assertDatabaseVersionSetting(db, '6');

        await db.close();
      },
    );

    test('v2 → v6 preserva nota privada, progresso e fila pendente', () async {
      final path = await _createHistoricalDatabase(tempDir, version: 2);

      final db = await AppDatabase.instance.openDatabaseForTesting(path);

      expect(await db.getVersion(), 6);
      expect(await _integrityCheck(db), 'ok');

      await _assertHistoricDataPreserved(db);

      final notes = await db.query(
        'local_private_notes',
        where: 'title = ?',
        whereArgs: ['Nota privada histórica'],
      );
      expect(notes, hasLength(1));
      expect(
        notes.single['note_text'],
        'Conteúdo que nunca deve ser sincronizado',
      );

      final submissions = await db.query(
        'submissions',
        where: 'id = ?',
        whereArgs: [_historicSubmissionId],
      );
      expect(submissions.single['sync_status'], 'pending');
      expect(submissions.single['attempt_count'], 2);

      final queue = await db.query(
        'sync_queue',
        where: 'entity_id = ?',
        whereArgs: [_historicSubmissionId],
      );
      expect(queue, hasLength(1));
      expect(queue.single['sync_status'], 'pending');
      expect(queue.single['attempt_count'], 1);

      final clientId = submissions.single['client_submission_id']?.toString();
      expect(clientId, isNotNull);
      expect(clientId, isNotEmpty);

      await _assertDatabaseVersionSetting(db, '6');

      await db.close();
    });

    test(
      'v2 intermédia com client_submission_id já existente migra sem mascarar erro',
      () async {
        final path = await _createHistoricalDatabase(tempDir, version: 2);

        var db = await databaseFactoryFfi.openDatabase(path);
        await db.execute(
          'ALTER TABLE submissions ADD COLUMN client_submission_id TEXT',
        );
        await db.update(
          'submissions',
          {'client_submission_id': 'already-stable-id'},
          where: 'id = ?',
          whereArgs: [_historicSubmissionId],
        );
        await db.close();

        db = await AppDatabase.instance.openDatabaseForTesting(path);

        expect(await db.getVersion(), 6);
        final rows = await db.query(
          'submissions',
          columns: ['client_submission_id'],
          where: 'id = ?',
          whereArgs: [_historicSubmissionId],
        );

        expect(rows, hasLength(1));
        expect(rows.single['client_submission_id'], 'already-stable-id');
        expect(
          await _indexExists(db, 'idx_submissions_client_submission_id'),
          isTrue,
        );
        expect(await _integrityCheck(db), 'ok');

        await db.close();
      },
    );

    test(
      'v3 → v6 preserva progresso e cria catálogo/assets aditivamente',
      () async {
        final path = await _createHistoricalV3Database(tempDir);
        final db = await AppDatabase.instance.openDatabaseForTesting(path);

        expect(await db.getVersion(), 6);
        await _assertHistoricDataPreserved(db);

        final submissions = await db.query(
          'submissions',
          columns: ['client_submission_id', 'sync_status', 'attempt_count'],
          where: 'id = ?',
          whereArgs: [_historicSubmissionId],
        );
        expect(submissions, hasLength(1));
        expect(
          submissions.single['client_submission_id'],
          'historic-stable-v3',
        );
        expect(submissions.single['sync_status'], 'pending');
        expect(submissions.single['attempt_count'], 2);

        expect(await _tableExists(db, 'learning_content_packages'), isTrue);
        expect(await _tableExists(db, 'learning_content_catalog'), isTrue);
        expect(await _integrityCheck(db), 'ok');
        await _assertDatabaseVersionSetting(db, '6');

        await db.close();
      },
    );

    test(
      'v4 → v6 preserva pacote/catálogo e acrescenta cache de assets',
      () async {
        final path = p.join(tempDir.path, 'historical-v4.db');

        var db = await AppDatabase.instance.openDatabaseForTesting(path);
        final now = DateTime.utc(2026, 9, 9, 12).toIso8601String();
        final packageId = await db.insert('learning_content_packages', {
          'learning_path_id': 'student.fr-fr.phase1',
          'package_version': 2,
          'schema_version': 1,
          'content_hash': List.filled(64, 'a').join(),
          'payload_json': '{}',
          'source': 'historical-v4',
          'imported_at': now,
        });
        await db.insert('learning_content_catalog', {
          'learning_path_id': 'student.fr-fr.phase1',
          'active_package_id': packageId,
          'previous_package_id': null,
          'activated_at': now,
        });

        await db.execute('DROP TABLE learning_content_asset_entries');
        await db.execute('DROP TABLE learning_content_asset_manifests');
        await db.execute('DROP TABLE learning_content_asset_cache');
        await db.execute('PRAGMA user_version = 4');
        await db.update(
          'app_settings',
          {'value': '4', 'updated_at': now},
          where: 'key = ?',
          whereArgs: ['database_version'],
        );
        await db.close();

        db = await AppDatabase.instance.openDatabaseForTesting(path);

        expect(await db.getVersion(), 6);
        expect(
          await _tableExists(db, 'learning_content_asset_manifests'),
          isTrue,
        );
        expect(
          await _tableExists(db, 'learning_content_asset_entries'),
          isTrue,
        );
        expect(await _tableExists(db, 'learning_content_asset_cache'), isTrue);
        expect(
          await _indexExists(
            db,
            'idx_learning_content_asset_entries_revision_role',
          ),
          isTrue,
        );

        final packages = await db.query(
          'learning_content_packages',
          where: 'id = ?',
          whereArgs: [packageId],
        );
        expect(packages, hasLength(1));
        expect(packages.single['source'], 'historical-v4');

        final catalog = await db.query(
          'learning_content_catalog',
          where: 'learning_path_id = ?',
          whereArgs: ['student.fr-fr.phase1'],
        );
        expect(catalog, hasLength(1));
        expect(catalog.single['active_package_id'], packageId);

        expect(await _integrityCheck(db), 'ok');
        await _assertDatabaseVersionSetting(db, '6');
        await db.close();
      },
    );

    test(
      'Fase 3.1 — base nova v6 cria schema de progresso e aplica invariantes',
      () async {
        final path = p.join(tempDir.path, 'fase3-fresh-v6.db');
        final db = await AppDatabase.instance.openDatabaseForTesting(path);

        expect(await db.getVersion(), 6);
        expect(await _foreignKeysEnabled(db), isTrue);

        for (final table in <String>[
          'learning_progress_completions',
          'learning_competency_evidence',
          'learning_progress_projection',
        ]) {
          expect(
            await _tableExists(db, table),
            isTrue,
            reason: 'Tabela da Fase 3 em falta: $table',
          );
        }

        for (final index in <String>[
          'idx_learning_progress_completions_account_path',
          'idx_learning_progress_completions_activity',
          'idx_learning_competency_evidence_completion',
          'idx_learning_competency_evidence_competency',
          'idx_learning_progress_projection_state',
          'idx_sync_queue_learning_completion_once',
        ]) {
          expect(
            await _indexExists(db, index),
            isTrue,
            reason: 'Índice da Fase 3 em falta: $index',
          );
        }

        final now = DateTime.utc(2026, 9, 10, 15).toIso8601String();

        final completionId = await db.insert('learning_progress_completions', {
          'client_completion_id': 'completion-device-a-0001',
          'account_id': 'user-phase3',
          'learning_path_id': 'student.fr-fr.phase1',
          'activity_id': 'arrival.vocabulary-01',
          'revision_id': 'arrival.vocabulary-01.rev-1',
          'package_version': 3,
          'completed_at': now,
          'created_at': now,
        });

        await db.insert('learning_competency_evidence', {
          'completion_id': completionId,
          'competency_id': 'arrival.greeting-basics',
          'evidence_type': 'activity_completion',
          'created_at': now,
        });

        await db.insert('learning_progress_projection', {
          'account_id': 'user-phase3',
          'learning_path_id': 'student.fr-fr.phase1',
          'path_element_id': 'arrival.vocabulary-01.element',
          'activity_id': 'arrival.vocabulary-01',
          'state': 'completed',
          'reason': 'completed',
          'recommendation_rank': null,
          'package_version': 3,
          'updated_at': now,
        });

        await db.insert('sync_queue', {
          'entity_type': 'learning_progress_completion',
          'entity_id': completionId,
          'operation': 'ActivityCompleted',
          'endpoint': '/api/sync/progress',
          'method': 'POST',
          'payload_json': '{"phase":3}',
          'sync_status': 'pending',
          'attempt_count': 0,
          'last_error': null,
          'created_at': now,
          'updated_at': now,
          'next_retry_at': null,
          'processed_at': null,
        });

        // client_completion_id é uma identidade estável.
        await expectLater(
          db.insert('learning_progress_completions', {
            'client_completion_id': 'completion-device-a-0001',
            'account_id': 'user-phase3',
            'learning_path_id': 'student.fr-fr.phase1',
            'activity_id': 'arrival.dialogue-01',
            'revision_id': 'arrival.dialogue-01.rev-1',
            'package_version': 3,
            'completed_at': now,
            'created_at': now,
          }),
          throwsA(isA<DatabaseException>()),
        );

        // Evidência não pode existir sem a conclusão correspondente.
        await expectLater(
          db.insert('learning_competency_evidence', {
            'completion_id': 999999,
            'competency_id': 'competency.invalid',
            'evidence_type': 'activity_completion',
            'created_at': now,
          }),
          throwsA(isA<DatabaseException>()),
        );

        // Estado pedagógico inválido deve ser rejeitado pelo SQLite.
        await expectLater(
          db.insert('learning_progress_projection', {
            'account_id': 'user-phase3',
            'learning_path_id': 'student.fr-fr.phase1',
            'path_element_id': 'element.invalid',
            'activity_id': 'activity.invalid',
            'state': 'syncing',
            'reason': 'invalid-test',
            'recommendation_rank': null,
            'package_version': 3,
            'updated_at': now,
          }),
          throwsA(isA<DatabaseException>()),
        );

        // A mesma conclusão não pode gerar duas operações equivalentes
        // na outbox local.
        await expectLater(
          db.insert('sync_queue', {
            'entity_type': 'learning_progress_completion',
            'entity_id': completionId,
            'operation': 'ActivityCompleted',
            'endpoint': '/api/sync/progress',
            'method': 'POST',
            'payload_json': '{"phase":3,"retry":true}',
            'sync_status': 'pending',
            'attempt_count': 0,
            'last_error': null,
            'created_at': now,
            'updated_at': now,
            'next_retry_at': null,
            'processed_at': null,
          }),
          throwsA(isA<DatabaseException>()),
        );

        final evidence = await db.query(
          'learning_competency_evidence',
          where: 'completion_id = ?',
          whereArgs: [completionId],
        );
        expect(evidence, hasLength(1));

        final projection = await db.query(
          'learning_progress_projection',
          where: 'path_element_id = ?',
          whereArgs: ['arrival.vocabulary-01.element'],
        );
        expect(projection, hasLength(1));
        expect(projection.single['state'], 'completed');

        final queue = await db.query(
          'sync_queue',
          where: 'entity_type = ? AND entity_id = ?',
          whereArgs: ['learning_progress_completion', completionId],
        );
        expect(queue, hasLength(1));
        expect(queue.single['sync_status'], 'pending');

        expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        expect(await _integrityCheck(db), 'ok');

        await db.close();
      },
    );

    test(
      'Fase 3.1 — v5 → v6 preserva fila e acrescenta schema de progresso',
      () async {
        final path = p.join(tempDir.path, 'fase3-v5-to-v6.db');

        // Criar uma base atual e reduzi-la apenas ao delta conhecido da v5.
        // Isso permite testar especificamente a migration 5 -> 6.
        var db = await AppDatabase.instance.openDatabaseForTesting(path);

        final now = DateTime.utc(2026, 9, 10, 15, 30).toIso8601String();

        await db.insert('sync_queue', {
          'id': 501,
          'entity_type': 'submission',
          'entity_id': 77,
          'operation': 'create',
          'endpoint': '/api/sync/progress',
          'method': 'POST',
          'payload_json': '{"preserve":"v5"}',
          'sync_status': 'pending',
          'attempt_count': 2,
          'last_error': 'offline',
          'created_at': now,
          'updated_at': now,
          'next_retry_at': null,
          'processed_at': null,
        });

        await db.execute(
          'DROP INDEX IF EXISTS idx_sync_queue_learning_completion_once',
        );
        await db.execute('DROP TABLE IF EXISTS learning_competency_evidence');
        await db.execute('DROP TABLE IF EXISTS learning_progress_projection');
        await db.execute('DROP TABLE IF EXISTS learning_progress_completions');

        await db.execute('PRAGMA user_version = 5');

        await db.update(
          'app_settings',
          {'value': '5', 'updated_at': now},
          where: 'key = ?',
          whereArgs: ['database_version'],
        );

        await db.close();

        // Abertura pela aplicação deve executar somente o avanço necessário.
        db = await AppDatabase.instance.openDatabaseForTesting(path);

        expect(await db.getVersion(), 6);

        for (final table in <String>[
          'learning_progress_completions',
          'learning_competency_evidence',
          'learning_progress_projection',
        ]) {
          expect(await _tableExists(db, table), isTrue);
        }

        expect(
          await _indexExists(db, 'idx_sync_queue_learning_completion_once'),
          isTrue,
        );

        final preservedQueue = await db.query(
          'sync_queue',
          where: 'id = ?',
          whereArgs: [501],
        );

        expect(preservedQueue, hasLength(1));
        expect(preservedQueue.single['entity_type'], 'submission');
        expect(preservedQueue.single['entity_id'], 77);
        expect(preservedQueue.single['payload_json'], '{"preserve":"v5"}');
        expect(preservedQueue.single['sync_status'], 'pending');
        expect(preservedQueue.single['attempt_count'], 2);
        expect(preservedQueue.single['last_error'], 'offline');

        await _assertDatabaseVersionSetting(db, '6');

        expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        expect(await _integrityCheck(db), 'ok');

        await db.close();
      },
    );
    test('catálogo rejeita ponteiro para pacote de outro percurso', () async {
      final path = p.join(tempDir.path, 'catalog-foreign-key.db');
      final db = await AppDatabase.instance.openDatabaseForTesting(path);
      final now = DateTime.utc(2026, 9, 7, 15).toIso8601String();

      final packageId = await db.insert('learning_content_packages', {
        'learning_path_id': 'path-a',
        'package_version': 1,
        'schema_version': 1,
        'content_hash': List.filled(64, 'a').join(),
        'payload_json': '{}',
        'source': 'test',
        'imported_at': now,
      });

      await expectLater(
        db.insert('learning_content_catalog', {
          'learning_path_id': 'path-b',
          'active_package_id': packageId,
          'previous_package_id': null,
          'activated_at': now,
        }),
        throwsA(isA<DatabaseException>()),
      );

      expect(await _integrityCheck(db), 'ok');
      await db.close();
    });

    test(
      'índice único pós-migração impede clientSubmissionId duplicado',
      () async {
        final path = await _createHistoricalDatabase(tempDir, version: 2);
        final db = await AppDatabase.instance.openDatabaseForTesting(path);

        final migrated = await db.query(
          'submissions',
          columns: ['client_submission_id'],
          where: 'id = ?',
          whereArgs: [_historicSubmissionId],
        );
        final clientId = migrated.single['client_submission_id'] as String;

        final now = DateTime.utc(2026, 8, 31, 10, 30).toIso8601String();

        await expectLater(
          db.insert('submissions', {
            'client_submission_id': clientId,
            'activity_id': _historicActivityId,
            'student_id': _historicStudentId,
            'remote_activity_id': _historicRemoteActivityId,
            'submission_json': '{"duplicate":true}',
            'sync_status': 'pending',
            'attempt_count': 0,
            'created_at': now,
            'updated_at': now,
          }),
          throwsA(isA<DatabaseException>()),
        );

        expect(await _integrityCheck(db), 'ok');
        await db.close();
      },
    );
  });
}

Future<String> _createHistoricalV3Database(Directory directory) async {
  final path = await _createHistoricalDatabase(directory, version: 2);
  final db = await databaseFactoryFfi.openDatabase(path);

  await db.execute(
    'ALTER TABLE submissions ADD COLUMN client_submission_id TEXT',
  );
  await db.update(
    'submissions',
    {'client_submission_id': 'historic-stable-v3'},
    where: 'id = ?',
    whereArgs: [_historicSubmissionId],
  );
  await db.execute(
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_submissions_client_submission_id '
    'ON submissions(client_submission_id)',
  );
  await db.update(
    'app_settings',
    {
      'value': '3',
      'updated_at': DateTime.utc(2026, 8, 31, 9).toIso8601String(),
    },
    where: 'key = ?',
    whereArgs: ['database_version'],
  );
  await db.execute('PRAGMA user_version = 3');
  await db.close();
  return path;
}

Future<String> _createHistoricalDatabase(
  Directory directory, {
  required int version,
}) async {
  assert(version == 1 || version == 2);

  final path = p.join(directory.path, 'historic-v$version.db');

  final db = await databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: version,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (database, createdVersion) async {
        await _createV1Schema(database);

        if (createdVersion >= 2) {
          await _createV2Extras(database);
        }

        await _seedHistoricalData(database, createdVersion);
      },
    ),
  );

  await db.close();
  return path;
}

/// Schema histórico v1 baseado no commit 79d4e65.
Future<void> _createV1Schema(Database db) async {
  final batch = db.batch();

  batch.execute('''
    CREATE TABLE IF NOT EXISTS activities (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      remote_activity_id TEXT NOT NULL UNIQUE,
      title TEXT,
      type TEXT NOT NULL,
      scenario TEXT,
      language_code TEXT NOT NULL,
      difficulty TEXT,
      activity_url TEXT,
      source TEXT NOT NULL DEFAULT 'remote',
      is_cached INTEGER NOT NULL DEFAULT 0,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      last_opened_at TEXT
    )
  ''');

  batch.execute('''
    CREATE TABLE IF NOT EXISTS activity_params (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      activity_id INTEGER,
      param_name TEXT NOT NULL,
      param_type TEXT NOT NULL,
      param_value TEXT,
      is_required INTEGER NOT NULL DEFAULT 0,
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE
    )
  ''');

  batch.execute('''
    CREATE TABLE IF NOT EXISTS students (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invenira_std_id TEXT NOT NULL UNIQUE,
      display_name TEXT,
      class_name TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      last_seen_at TEXT
    )
  ''');

  batch.execute('''
    CREATE TABLE IF NOT EXISTS submissions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      activity_id INTEGER NOT NULL,
      student_id INTEGER,
      remote_activity_id TEXT NOT NULL,
      submission_json TEXT NOT NULL,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      attempt_count INTEGER NOT NULL DEFAULT 0,
      last_error TEXT,
      submitted_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      last_sync_at TEXT,
      FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE,
      FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE SET NULL
    )
  ''');

  batch.execute('''
    CREATE TABLE IF NOT EXISTS submission_results (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      submission_id INTEGER NOT NULL UNIQUE,
      remote_activity_id TEXT NOT NULL,
      score REAL,
      feedback_text TEXT,
      feedback_url TEXT,
      metrics_json TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (submission_id) REFERENCES submissions(id) ON DELETE CASCADE
    )
  ''');

  batch.execute('''
    CREATE TABLE IF NOT EXISTS analytics_definitions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      code TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      analytics_type TEXT NOT NULL,
      value_type TEXT,
      description TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');

  batch.execute('''
    CREATE TABLE IF NOT EXISTS analytics_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      activity_id INTEGER,
      student_id INTEGER,
      remote_activity_id TEXT NOT NULL,
      invenira_std_id TEXT NOT NULL,
      quant_analytics_json TEXT,
      qual_analytics_json TEXT,
      total_interactions INTEGER,
      activity_time_seconds INTEGER,
      student_profile TEXT,
      heatmap_url TEXT,
      fetched_at TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE SET NULL,
      FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE SET NULL,
      UNIQUE(remote_activity_id, invenira_std_id)
    )
  ''');

  batch.execute('''
    CREATE TABLE IF NOT EXISTS sync_queue (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      entity_type TEXT NOT NULL,
      entity_id INTEGER NOT NULL,
      operation TEXT NOT NULL,
      endpoint TEXT NOT NULL,
      method TEXT NOT NULL DEFAULT 'POST',
      payload_json TEXT NOT NULL,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      attempt_count INTEGER NOT NULL DEFAULT 0,
      last_error TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      next_retry_at TEXT,
      processed_at TEXT
    )
  ''');

  batch.execute('''
    CREATE TABLE IF NOT EXISTS app_settings (
      key TEXT PRIMARY KEY,
      value TEXT,
      value_type TEXT NOT NULL DEFAULT 'text',
      updated_at TEXT NOT NULL
    )
  ''');

  batch.execute(
    'CREATE INDEX IF NOT EXISTS idx_activities_remote_activity_id '
    'ON activities(remote_activity_id)',
  );
  batch.execute(
    'CREATE INDEX IF NOT EXISTS idx_activity_params_activity_id '
    'ON activity_params(activity_id)',
  );
  batch.execute(
    'CREATE INDEX IF NOT EXISTS idx_students_invenira_std_id '
    'ON students(invenira_std_id)',
  );
  batch.execute(
    'CREATE INDEX IF NOT EXISTS idx_submissions_activity_id '
    'ON submissions(activity_id)',
  );
  batch.execute(
    'CREATE INDEX IF NOT EXISTS idx_submissions_sync_status '
    'ON submissions(sync_status)',
  );
  batch.execute(
    'CREATE INDEX IF NOT EXISTS idx_submission_results_submission_id '
    'ON submission_results(submission_id)',
  );
  batch.execute(
    'CREATE INDEX IF NOT EXISTS idx_analytics_records_activity_student '
    'ON analytics_records(remote_activity_id, invenira_std_id)',
  );
  batch.execute(
    'CREATE INDEX IF NOT EXISTS idx_sync_queue_status '
    'ON sync_queue(sync_status)',
  );

  await batch.commit(noResult: true);
}

/// Alteração histórica v2 baseada no commit 6183236.
Future<void> _createV2Extras(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS local_private_notes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      note_text TEXT NOT NULL,
      scenario TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');

  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_local_private_notes_scenario '
    'ON local_private_notes(scenario)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_local_private_notes_updated_at '
    'ON local_private_notes(updated_at)',
  );
}

Future<void> _seedHistoricalData(Database db, int version) async {
  final now = DateTime.utc(2026, 5, 24, 12).toIso8601String();

  await db.insert('activities', {
    'id': _historicActivityId,
    'remote_activity_id': _historicRemoteActivityId,
    'title': 'Atividade histórica',
    'type': 'vocabulary',
    'scenario': 'arrival',
    'language_code': 'fr-FR',
    'difficulty': 'beginner',
    'activity_url': '/historic/activity',
    'source': 'remote',
    'is_cached': 1,
    'is_active': 1,
    'created_at': now,
    'updated_at': now,
    'last_opened_at': now,
  });

  await db.insert('activity_params', {
    'id': 1,
    'activity_id': _historicActivityId,
    'param_name': 'mode',
    'param_type': 'text',
    'param_value': 'historic',
    'is_required': 1,
    'sort_order': 1,
    'created_at': now,
    'updated_at': now,
  });

  await db.insert('students', {
    'id': _historicStudentId,
    'invenira_std_id': _historicStudentRemoteId,
    'display_name': 'Aluno Histórico',
    'class_name': 'Fase 0',
    'created_at': now,
    'updated_at': now,
    'last_seen_at': now,
  });

  await db.insert('submissions', {
    'id': _historicSubmissionId,
    'activity_id': _historicActivityId,
    'student_id': _historicStudentId,
    'remote_activity_id': _historicRemoteActivityId,
    'submission_json': '{"answers":[1,2,3],"score":0.8}',
    'sync_status': 'pending',
    'attempt_count': 2,
    'last_error': 'network-offline',
    'submitted_at': null,
    'created_at': now,
    'updated_at': now,
    'last_sync_at': null,
  });

  await db.insert('submission_results', {
    'id': 1,
    'submission_id': _historicSubmissionId,
    'remote_activity_id': _historicRemoteActivityId,
    'score': 0.8,
    'feedback_text': 'Resultado histórico',
    'feedback_url': null,
    'metrics_json': '{"correct":4,"total":5}',
    'created_at': now,
  });

  await db.insert('analytics_definitions', {
    'id': 1,
    'code': 'historic-score',
    'name': 'Historic score',
    'analytics_type': 'quantitative',
    'value_type': 'number',
    'description': 'Fixture Fase 0',
    'created_at': now,
    'updated_at': now,
  });

  await db.insert('analytics_records', {
    'id': 1,
    'activity_id': _historicActivityId,
    'student_id': _historicStudentId,
    'remote_activity_id': _historicRemoteActivityId,
    'invenira_std_id': _historicStudentRemoteId,
    'quant_analytics_json': '{"score":0.8}',
    'qual_analytics_json': '{"state":"historic"}',
    'total_interactions': 5,
    'activity_time_seconds': 120,
    'student_profile': 'student',
    'heatmap_url': null,
    'fetched_at': now,
    'created_at': now,
    'updated_at': now,
  });

  await db.insert('sync_queue', {
    'id': 1,
    'entity_type': 'submission',
    'entity_id': _historicSubmissionId,
    'operation': 'create',
    'endpoint': '/api/sync/progress',
    'method': 'POST',
    'payload_json': '{"historic":true}',
    'sync_status': 'pending',
    'attempt_count': 1,
    'last_error': 'offline',
    'created_at': now,
    'updated_at': now,
    'next_retry_at': null,
    'processed_at': null,
  });

  await db.insert('app_settings', {
    'key': 'default_language',
    'value': 'fr-FR',
    'value_type': 'text',
    'updated_at': now,
  });

  await db.insert('app_settings', {
    'key': 'database_version',
    'value': version.toString(),
    'value_type': 'number',
    'updated_at': now,
  });

  if (version >= 2) {
    await db.insert('local_private_notes', {
      'id': 1,
      'title': 'Nota privada histórica',
      'note_text': 'Conteúdo que nunca deve ser sincronizado',
      'scenario': 'arrival',
      'created_at': now,
      'updated_at': now,
    });
  }
}

Future<void> _assertHistoricDataPreserved(Database db) async {
  final activities = await db.query(
    'activities',
    where: 'id = ?',
    whereArgs: [_historicActivityId],
  );
  expect(activities, hasLength(1));
  expect(activities.single['remote_activity_id'], _historicRemoteActivityId);
  expect(activities.single['title'], 'Atividade histórica');

  final students = await db.query(
    'students',
    where: 'id = ?',
    whereArgs: [_historicStudentId],
  );
  expect(students, hasLength(1));
  expect(students.single['invenira_std_id'], _historicStudentRemoteId);
  expect(students.single['display_name'], 'Aluno Histórico');

  final params = await db.query(
    'activity_params',
    where: 'id = ?',
    whereArgs: [1],
  );
  expect(params, hasLength(1));
  expect(params.single['param_value'], 'historic');

  final submissions = await db.query(
    'submissions',
    where: 'id = ?',
    whereArgs: [_historicSubmissionId],
  );
  expect(submissions, hasLength(1));
  expect(
    submissions.single['submission_json'],
    '{"answers":[1,2,3],"score":0.8}',
  );
  expect(submissions.single['sync_status'], 'pending');
  expect(submissions.single['attempt_count'], 2);
  expect(submissions.single['last_error'], 'network-offline');

  final results = await db.query(
    'submission_results',
    where: 'submission_id = ?',
    whereArgs: [_historicSubmissionId],
  );
  expect(results, hasLength(1));
  expect(results.single['score'], 0.8);
  expect(results.single['feedback_text'], 'Resultado histórico');

  final analytics = await db.query(
    'analytics_records',
    where: 'id = ?',
    whereArgs: [1],
  );
  expect(analytics, hasLength(1));
  expect(analytics.single['total_interactions'], 5);
  expect(analytics.single['activity_time_seconds'], 120);

  final queue = await db.query('sync_queue', where: 'id = ?', whereArgs: [1]);
  expect(queue, hasLength(1));
  expect(queue.single['payload_json'], '{"historic":true}');
  expect(queue.single['sync_status'], 'pending');

  final language = await db.query(
    'app_settings',
    where: 'key = ?',
    whereArgs: ['default_language'],
  );
  expect(language, hasLength(1));
  expect(language.single['value'], 'fr-FR');
}

Future<void> _assertDatabaseVersionSetting(Database db, String value) async {
  final rows = await db.query(
    'app_settings',
    where: 'key = ?',
    whereArgs: ['database_version'],
  );

  expect(rows, hasLength(1));
  expect(rows.single['value'], value);
}

Future<bool> _foreignKeysEnabled(Database db) async {
  final rows = await db.rawQuery('PRAGMA foreign_keys');
  if (rows.isEmpty) return false;
  final value = rows.first.values.first;
  return value == 1;
}

Future<String> _integrityCheck(Database db) async {
  final rows = await db.rawQuery('PRAGMA integrity_check');
  return rows.first.values.first.toString();
}

Future<Set<String>> _userTables(Database db) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master "
    "WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
  );

  return rows.map((row) => row['name'].toString()).toSet();
}

Future<bool> _tableExists(Database db, String table) async {
  final rows = await db.rawQuery(
    "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
    [table],
  );
  return rows.isNotEmpty;
}

Future<bool> _indexExists(Database db, String index) async {
  final rows = await db.rawQuery(
    "SELECT 1 FROM sqlite_master WHERE type = 'index' AND name = ? LIMIT 1",
    [index],
  );
  return rows.isNotEmpty;
}

Future<bool> _columnExists(Database db, String table, String column) async {
  final rows = await db.rawQuery('PRAGMA table_info($table)');
  return rows.any((row) => row['name'] == column);
}
