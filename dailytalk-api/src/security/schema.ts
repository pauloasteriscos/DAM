import type { AppContext } from "../types";

let schemaInitialization: Promise<void> | null = null;

/// Criação automática apenas para desenvolvimento controlado.
///
/// Em produção, o schema é aplicado previamente através de uma migração D1.
/// Evita executar instruções DDL no caminho crítico de cada pedido.
export async function ensureSecuritySchema(c: AppContext): Promise<void> {
  if (c.env.AUTO_CREATE_SECURITY_SCHEMA !== "true") {
    return;
  }

  schemaInitialization ??= createSecuritySchema(c).catch((error) => {
    schemaInitialization = null;
    throw error;
  });

  await schemaInitialization;
}

async function createSecuritySchema(c: AppContext): Promise<void> {
  await c.env.DB.batch([
    c.env.DB.prepare(`
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
      )
    `),
    c.env.DB.prepare(`
      CREATE INDEX IF NOT EXISTS idx_user_devices_user_id
      ON user_devices(user_id)
    `),
    c.env.DB.prepare(`
      CREATE INDEX IF NOT EXISTS idx_user_devices_signing_jkt
      ON user_devices(signing_jkt)
    `),
    c.env.DB.prepare(`
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
      )
    `),
    c.env.DB.prepare(`
      CREATE INDEX IF NOT EXISTS idx_auth_sessions_user_device
      ON auth_sessions(user_id, device_id)
    `),
    c.env.DB.prepare(`
      CREATE TABLE IF NOT EXISTS dpop_replay (
        jkt TEXT NOT NULL,
        jti TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        PRIMARY KEY (jkt, jti)
      )
    `),
    c.env.DB.prepare(`
      CREATE INDEX IF NOT EXISTS idx_dpop_replay_expires_at
      ON dpop_replay(expires_at)
    `),
    c.env.DB.prepare(`
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
      )
    `),
    c.env.DB.prepare(`
      CREATE INDEX IF NOT EXISTS idx_secure_sync_batches_user_device
      ON secure_sync_batches(user_id, device_id, created_at)
    `),
    c.env.DB.prepare(`
      CREATE UNIQUE INDEX IF NOT EXISTS idx_secure_sync_batches_sequence
      ON secure_sync_batches(user_id, device_id, sequence)
    `),
    c.env.DB.prepare(`
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
      )
    `),
  ]);
}
