-- DailyTalk.pt
-- Fase 3.5 - feed monotónico para convergência multi-dispositivo.
--
-- Não alterar migrations publicadas 0001 e 0002.
--
-- learning_progress_completions continua a ser a fonte autoritativa
-- dos factos. Esta tabela fornece apenas uma ordem monotónica e
-- estável para pull incremental.
--
-- seq é global, mas o consumo é sempre filtrado por user_id.

CREATE TABLE IF NOT EXISTS learning_progress_sync_feed (
  seq INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL,
  completion_id TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (completion_id)
    REFERENCES learning_progress_completions(id)
    ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_learning_progress_sync_feed_user_seq
  ON learning_progress_sync_feed(user_id, seq);

-- Backfill determinístico das conclusões existentes da Fase 3.4.
INSERT OR IGNORE INTO learning_progress_sync_feed (
  user_id,
  completion_id,
  created_at
)
SELECT
  user_id,
  id,
  created_at
FROM learning_progress_completions
ORDER BY created_at ASC, id ASC;