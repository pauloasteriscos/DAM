CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  password_salt TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'student',
  active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS user_preferences (
  user_id TEXT PRIMARY KEY,
  app_language_code TEXT NOT NULL DEFAULT 'pt-PT',
  learning_language_code TEXT NOT NULL DEFAULT 'it-IT',
  selected_profile TEXT NOT NULL DEFAULT 'student',
  difficulty_level TEXT NOT NULL DEFAULT 'beginner',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS activity_submissions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  remote_activity_id TEXT NOT NULL,
  activity_type TEXT,
  native_language_code TEXT,
  target_language_code TEXT,
  answer_text TEXT,
  score REAL,
  feedback TEXT,
  metrics_json TEXT,
  submission_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_activity_submissions_user_id
  ON activity_submissions(user_id);

CREATE INDEX IF NOT EXISTS idx_activity_submissions_remote_activity_id
  ON activity_submissions(remote_activity_id);
