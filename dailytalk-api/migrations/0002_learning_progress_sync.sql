-- DailyTalk.pt
-- Fase 3.4 - secure sync de conclusoes pedagogicas.
--
-- 0001 e uma migration publicada e nao deve ser alterada.
--
-- client_completion_id identifica a ocorrencia criada offline.
-- fact_hash impede reutilizacao da mesma identidade com outro facto.
--
-- A convergencia pedagogica entre dispositivos permanece para a Fase 3.5.

CREATE TABLE IF NOT EXISTS learning_progress_completions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  source_device_id TEXT NOT NULL,
  first_batch_id TEXT NOT NULL,
  client_completion_id TEXT NOT NULL,
  learning_path_id TEXT NOT NULL,
  activity_id TEXT NOT NULL,
  revision_id TEXT NOT NULL,
  package_version INTEGER NOT NULL CHECK (package_version > 0),
  completed_at TEXT NOT NULL,
  fact_hash TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (source_device_id) REFERENCES user_devices(id),
  UNIQUE(user_id, client_completion_id)
);

CREATE INDEX IF NOT EXISTS idx_learning_progress_completions_user_path
  ON learning_progress_completions(user_id, learning_path_id);

CREATE INDEX IF NOT EXISTS idx_learning_progress_completions_user_activity
  ON learning_progress_completions(user_id, activity_id);

CREATE INDEX IF NOT EXISTS idx_learning_progress_completions_completed_at
  ON learning_progress_completions(user_id, completed_at);
