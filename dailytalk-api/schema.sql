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

-- Segurança de produção - dispositivos, sessões DPoP e sincronização cifrada.
CREATE TABLE IF NOT EXISTS user_devices (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  installation_id TEXT NOT NULL,
  name TEXT,
  platform TEXT,
  app_version TEXT,
  signing_public_jwk TEXT NOT NULL,
  agreement_public_jwk TEXT NOT NULL,
  signing_jkt TEXT NOT NULL,
  active INTEGER NOT NULL DEFAULT 1,
  last_sequence INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  last_seen_at TEXT,
  revoked_at TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(user_id, installation_id)
);

CREATE INDEX IF NOT EXISTS idx_user_devices_user_id
  ON user_devices(user_id);
CREATE INDEX IF NOT EXISTS idx_user_devices_signing_jkt
  ON user_devices(signing_jkt);

CREATE TABLE IF NOT EXISTS auth_sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  refresh_token_hash TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  last_used_at TEXT,
  expires_at TEXT NOT NULL,
  revoked_at TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (device_id) REFERENCES user_devices(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_auth_sessions_user_device
  ON auth_sessions(user_id, device_id);

CREATE TABLE IF NOT EXISTS dpop_replay (
  jkt TEXT NOT NULL,
  jti TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (jkt, jti)
);

CREATE INDEX IF NOT EXISTS idx_dpop_replay_expires_at
  ON dpop_replay(expires_at);

CREATE TABLE IF NOT EXISTS secure_sync_batches (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  batch_id TEXT NOT NULL,
  sequence INTEGER NOT NULL,
  request_hash TEXT NOT NULL,
  response_envelope TEXT,
  status TEXT NOT NULL,
  created_at TEXT NOT NULL,
  completed_at TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (device_id) REFERENCES user_devices(id) ON DELETE CASCADE,
  UNIQUE(user_id, device_id, batch_id)
);

CREATE INDEX IF NOT EXISTS idx_secure_sync_batches_user_device
  ON secure_sync_batches(user_id, device_id, created_at);
CREATE UNIQUE INDEX IF NOT EXISTS idx_secure_sync_batches_sequence
  ON secure_sync_batches(user_id, device_id, sequence);

CREATE TABLE IF NOT EXISTS secure_submission_receipts (
  submission_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  client_submission_id TEXT NOT NULL,
  batch_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (device_id) REFERENCES user_devices(id) ON DELETE CASCADE,
  UNIQUE(user_id, client_submission_id)
);
