import test from "node:test";
import assert from "node:assert/strict";
import { readFile, rm } from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { spawn } from "node:child_process";

const ROOT = process.cwd();
const CONFIG_FILE = "wrangler.test.jsonc";
const FRESH_DIR = path.join(ROOT, ".wrangler", "phase0-d1-migrations-fresh");
const ADOPT_DIR = path.join(ROOT, ".wrangler", "phase0-d1-migrations-adopt");
const wranglerCli = path.join(
  ROOT,
  "node_modules",
  "wrangler",
  "bin",
  "wrangler.js",
);

function runCommand(args, { timeoutMs = 90000 } = {}) {
  return new Promise((resolve, reject) => {
    assert.equal(
      args[0],
      "wrangler",
      `Comando inesperado no harness: ${args.join(" ")}`,
    );

    const wranglerArgs = args.slice(1);
    const child = spawn(process.execPath, [wranglerCli, ...wranglerArgs], {
      cwd: ROOT,
      stdio: ["ignore", "pipe", "pipe"],
      shell: false,
      windowsHide: true,
      env: { ...process.env, CI: "1" },
    });

    let stdout = "";
    let stderr = "";
    const timer = setTimeout(() => {
      child.kill();
      reject(
        new Error(
          `Timeout ao executar: ${args.join(" ")}\nSTDOUT:\n${stdout}\nSTDERR:\n${stderr}`,
        ),
      );
    }, timeoutMs);

    child.stdout?.on("data", (chunk) => {
      stdout += chunk.toString();
    });
    child.stderr?.on("data", (chunk) => {
      stderr += chunk.toString();
    });
    child.on("error", (error) => {
      clearTimeout(timer);
      reject(error);
    });
    child.on("exit", (code) => {
      clearTimeout(timer);
      if (code === 0) {
        resolve({ stdout, stderr });
      } else {
        reject(
          new Error(
            `Falha (${code}) ao executar: ${args.join(" ")}\nSTDOUT:\n${stdout}\nSTDERR:\n${stderr}`,
          ),
        );
      }
    });
  });
}

async function removeDir(target) {
  try {
    await rm(target, {
      recursive: true,
      force: true,
      maxRetries: 20,
      retryDelay: 250,
    });
  } catch (error) {
    if (error?.code !== "ENOENT") throw error;
  }
}

function wranglerBase(persistDir) {
  return [
    "wrangler",
    "d1",
    "execute",
    "DB",
    "--config",
    CONFIG_FILE,
    "--local",
    "--persist-to",
    persistDir,
  ];
}

async function executeSql(persistDir, sql) {
  const { stdout } = await runCommand([
    ...wranglerBase(persistDir),
    "--command",
    sql,
    "--json",
  ]);

  const text = stdout.trim();
  try {
    return JSON.parse(text);
  } catch {
    const first = text.indexOf("[");
    const last = text.lastIndexOf("]");
    if (first >= 0 && last > first) {
      return JSON.parse(text.slice(first, last + 1));
    }
    throw new Error(`Saída JSON inesperada do Wrangler:\n${stdout}`);
  }
}

async function executeFile(persistDir, file) {
  await runCommand([
    ...wranglerBase(persistDir),
    "--file",
    file,
    "--yes",
  ]);
}

async function migrationList(persistDir) {
  return runCommand([
    "wrangler",
    "d1",
    "migrations",
    "list",
    "DB",
    "--config",
    CONFIG_FILE,
    "--local",
    "--persist-to",
    persistDir,
  ]);
}

async function migrationApply(persistDir) {
  return runCommand([
    "wrangler",
    "d1",
    "migrations",
    "apply",
    "DB",
    "--config",
    CONFIG_FILE,
    "--local",
    "--persist-to",
    persistDir,
  ]);
}

function rows(result) {
  assert.ok(Array.isArray(result), "Wrangler --json deve devolver uma lista");
  const flattened = [];
  for (const item of result) {
    if (Array.isArray(item?.results)) flattened.push(...item.results);
  }
  return flattened;
}

async function verifyIntegrity(persistDir) {
  // Cloudflare D1 não autoriza PRAGMA integrity_check, mas documenta
  // PRAGMA quick_check e PRAGMA foreign_key_check como compatíveis.
  const quickResult = await executeSql(persistDir, "PRAGMA quick_check;");
  const quickRows = rows(quickResult);
  assert.ok(quickRows.length >= 1, "quick_check não devolveu resultado");
  assert.equal(
    String(quickRows[0].quick_check).toLowerCase(),
    "ok",
    "PRAGMA quick_check deve ser ok",
  );

  const foreignKeyResult = await executeSql(
    persistDir,
    "PRAGMA foreign_key_check;",
  );
  const foreignKeyRows = rows(foreignKeyResult);
  assert.equal(
    foreignKeyRows.length,
    0,
    "PRAGMA foreign_key_check não deve encontrar violações",
  );
}

test(
  "DailyTalk D1 — Fase 0 — migrations versionadas",
  { timeout: 180000 },
  async (t) => {
    await removeDir(FRESH_DIR);
    await removeDir(ADOPT_DIR);

    t.after(async () => {
      await removeDir(FRESH_DIR);
      await removeDir(ADOPT_DIR);
    });

    await t.test("configurações D1 declaram diretório e tabela de migrations", async () => {
      for (const file of [
        "wrangler.jsonc",
        "wrangler.production.jsonc",
        "wrangler.test.jsonc",
      ]) {
        const raw = (await readFile(path.join(ROOT, file), "utf8")).replace(/^\uFEFF/, "");
        const config = JSON.parse(raw);
        assert.ok(Array.isArray(config.d1_databases));
        assert.ok(config.d1_databases.length >= 1);
        for (const db of config.d1_databases) {
          assert.equal(db.migrations_dir, "migrations", `${file}: migrations_dir`);
          assert.equal(db.migrations_table, "d1_migrations", `${file}: migrations_table`);
        }
      }
    });

    await t.test("baseline 0001 contém schema principal e password reset", async () => {
      const migration = await readFile(
        path.join(ROOT, "migrations", "0001_baseline.sql"),
        "utf8",
      );
      assert.match(migration, /CREATE TABLE IF NOT EXISTS users/i);
      assert.match(migration, /CREATE TABLE IF NOT EXISTS user_devices/i);
      assert.match(migration, /CREATE TABLE IF NOT EXISTS secure_sync_batches/i);
      assert.match(migration, /CREATE TABLE IF NOT EXISTS password_reset_tokens/i);
    });

    await t.test("base vazia lista 0001 como pendente", async () => {
      const { stdout, stderr } = await migrationList(FRESH_DIR);
      assert.match(`${stdout}\n${stderr}`, /0001_baseline\.sql/i);
    });

    await t.test("base vazia aplica 0001 e cria schema completo", async () => {
      await migrationApply(FRESH_DIR);

      const result = await executeSql(
        FRESH_DIR,
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;",
      );
      const names = new Set(rows(result).map((row) => String(row.name)));

      for (const name of [
        "users",
        "user_preferences",
        "activity_submissions",
        "user_devices",
        "auth_sessions",
        "dpop_replay",
        "secure_sync_batches",
        "secure_submission_receipts",
        "password_reset_tokens",
        "d1_migrations",
      ]) {
        assert.ok(names.has(name), `Tabela esperada não encontrada: ${name}`);
      }

      const migrationRows = rows(
        await executeSql(
          FRESH_DIR,
          "SELECT name FROM d1_migrations ORDER BY id;",
        ),
      );
      assert.deepEqual(
        migrationRows.map((row) => row.name),
        ["0001_baseline.sql"],
      );

      await verifyIntegrity(FRESH_DIR);
    });

    await t.test("segunda aplicação não duplica a migration", async () => {
      await migrationApply(FRESH_DIR);
      const countRows = rows(
        await executeSql(
          FRESH_DIR,
          "SELECT COUNT(*) AS total FROM d1_migrations;",
        ),
      );
      assert.equal(Number(countRows[0].total), 1);
      await verifyIntegrity(FRESH_DIR);
    });

    await t.test("adoção de base existente preserva utilizador, preferências e submissão", async () => {
      await executeFile(ADOPT_DIR, "schema.sql");
      await executeFile(ADOPT_DIR, "schema_password_reset.sql");

      const now = "2026-09-01T00:00:00.000Z";
      const markerSql = [
        `INSERT INTO users (id,name,email,password_hash,password_salt,role,active,created_at,updated_at)
         VALUES ('phase0-existing-user','Phase0 Existing','phase0-existing@example.com','hash','salt','student',1,'${now}','${now}')`,
        `INSERT INTO user_preferences (user_id,app_language_code,learning_language_code,selected_profile,difficulty_level,created_at,updated_at)
         VALUES ('phase0-existing-user','pt-PT','fr-FR','student','beginner','${now}','${now}')`,
        `INSERT INTO activity_submissions (id,user_id,remote_activity_id,activity_type,native_language_code,target_language_code,submission_json,created_at,updated_at)
         VALUES ('phase0-existing-submission','phase0-existing-user','phase0-existing-activity','vocabulary','pt-PT','fr-FR','{"phase0":true}','${now}','${now}')`,
      ].join(";");

      await executeSql(ADOPT_DIR, `${markerSql};`);
      await migrationApply(ADOPT_DIR);

      const users = rows(
        await executeSql(
          ADOPT_DIR,
          "SELECT id,email FROM users WHERE id='phase0-existing-user';",
        ),
      );
      assert.equal(users.length, 1);
      assert.equal(users[0].email, "phase0-existing@example.com");

      const preferences = rows(
        await executeSql(
          ADOPT_DIR,
          "SELECT learning_language_code FROM user_preferences WHERE user_id='phase0-existing-user';",
        ),
      );
      assert.equal(preferences.length, 1);
      assert.equal(preferences[0].learning_language_code, "fr-FR");

      const submissions = rows(
        await executeSql(
          ADOPT_DIR,
          "SELECT id,remote_activity_id FROM activity_submissions WHERE id='phase0-existing-submission';",
        ),
      );
      assert.equal(submissions.length, 1);
      assert.equal(
        submissions[0].remote_activity_id,
        "phase0-existing-activity",
      );

      const migrationRows = rows(
        await executeSql(
          ADOPT_DIR,
          "SELECT name FROM d1_migrations ORDER BY id;",
        ),
      );
      assert.deepEqual(
        migrationRows.map((row) => row.name),
        ["0001_baseline.sql"],
      );

      await verifyIntegrity(ADOPT_DIR);
    });
  },
);
