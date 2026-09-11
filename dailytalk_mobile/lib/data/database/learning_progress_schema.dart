import 'package:sqflite/sqflite.dart';

/// Schema local do progresso pedagógico do DailyTalk.pt.
///
/// Os factos de conclusão e evidência são a fonte durável.
/// A projeção é derivada pelo ProgressionEngine e pode ser reconstruída.
///
/// A rede não participa da transação local de conclusão.
abstract final class LearningProgressSchema {
  static const List<String> _tableStatements = <String>[
    '''
    CREATE TABLE IF NOT EXISTS learning_progress_completions (
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
    ''',
    '''
    CREATE TABLE IF NOT EXISTS learning_competency_evidence (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      completion_id INTEGER NOT NULL,
      competency_id TEXT NOT NULL,
      evidence_type TEXT NOT NULL DEFAULT 'activity_completion',
      created_at TEXT NOT NULL,
      FOREIGN KEY (completion_id)
        REFERENCES learning_progress_completions(id)
        ON DELETE CASCADE,
      UNIQUE(completion_id, competency_id, evidence_type)
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS learning_progress_projection (
      account_id TEXT NOT NULL,
      learning_path_id TEXT NOT NULL,
      path_element_id TEXT NOT NULL,
      activity_id TEXT,
      state TEXT NOT NULL
        CHECK(state IN ('locked', 'available', 'inProgress', 'completed')),
      reason TEXT NOT NULL,
      recommendation_rank INTEGER,
      package_version INTEGER NOT NULL,
      updated_at TEXT NOT NULL,
      PRIMARY KEY (account_id, learning_path_id, path_element_id)
    )
    ''',
  ];

  static const List<String> _indexStatements = <String>[
    '''
    CREATE INDEX IF NOT EXISTS
      idx_learning_progress_completions_account_path
    ON learning_progress_completions(account_id, learning_path_id)
    ''',
    '''
    CREATE INDEX IF NOT EXISTS
      idx_learning_progress_completions_activity
    ON learning_progress_completions(account_id, learning_path_id, activity_id)
    ''',
    '''
    CREATE INDEX IF NOT EXISTS
      idx_learning_competency_evidence_completion
    ON learning_competency_evidence(completion_id)
    ''',
    '''
    CREATE INDEX IF NOT EXISTS
      idx_learning_competency_evidence_competency
    ON learning_competency_evidence(competency_id)
    ''',
    '''
    CREATE INDEX IF NOT EXISTS
      idx_learning_progress_projection_state
    ON learning_progress_projection(
      account_id,
      learning_path_id,
      state
    )
    ''',

    // A sync_queue existente passa a funcionar como outbox.
    //
    // Nesta primeira entrega ainda não alteramos o protocolo remoto.
    // Apenas impedimos que a mesma conclusão local produza duas
    // operações equivalentes na fila.
    '''
    CREATE UNIQUE INDEX IF NOT EXISTS
      idx_sync_queue_learning_completion_once
    ON sync_queue(entity_type, entity_id, operation)
    WHERE entity_type = 'learning_progress_completion'
    ''',
  ];

  /// Usado na criação de uma base nova.
  static void addToBatch(Batch batch) {
    for (final statement in _tableStatements) {
      batch.execute(statement);
    }

    for (final statement in _indexStatements) {
      batch.execute(statement);
    }
  }

  /// Usado na migration de uma base existente.
  static Future<void> create(DatabaseExecutor db) async {
    for (final statement in _tableStatements) {
      await db.execute(statement);
    }

    for (final statement in _indexStatements) {
      await db.execute(statement);
    }
  }
}
