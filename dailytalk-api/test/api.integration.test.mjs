import test from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { rm } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const ROOT = process.cwd();
const API_BASE = "http://127.0.0.1:8791";
const PERSIST_DIR = path.join(ROOT, ".wrangler", "phase0-test-state");
const CONFIG_FILE = "wrangler.test.jsonc";
const ENV_HEADER = "X-DailyTalk-Environment";
const TEST_PASSWORD = "Phase0-Test-Password-2026!";
const npxCommand = process.platform === "win32" ? "npx.cmd" : "npx";

let worker = null;
let workerLog = "";

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function appendWorkerLog(chunk) {
  workerLog += chunk.toString();
  if (workerLog.length > 20000) {
    workerLog = workerLog.slice(-20000);
  }
}

async function removePersistDir({ finalCleanup = false } = {}) {
  // Em Windows, Miniflare/SQLite pode manter o ficheiro de observabilidade
  // bloqueado por alguns instantes depois do encerramento do Worker.
  // fs.rm faz retry automático para EBUSY/EPERM/ENOTEMPTY quando recursive=true.
  try {
    await rm(PERSIST_DIR, {
      recursive: true,
      force: true,
      maxRetries: 20,
      retryDelay: 250,
    });
  } catch (error) {
    if (finalCleanup && error?.code === "EBUSY") {
      // O estado é exclusivamente temporário e é apagado obrigatoriamente
      // no início da próxima execução. Não transformar um teardown tardio do
      // Windows num falso negativo depois de todos os testes funcionais passarem.
      console.warn(
        `Aviso: Windows ainda mantém um ficheiro temporário bloqueado em ${PERSIST_DIR}. ` +
          "Será removido no início da próxima execução.",
      );
      return;
    }
    throw error;
  }
}

function runCommand(args, { timeoutMs = 60000 } = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(npxCommand, args, {
      cwd: ROOT,
      stdio: ["ignore", "pipe", "pipe"],
      shell: process.platform === "win32",
      windowsHide: true,
    });

    let stdout = "";
    let stderr = "";
    const timer = setTimeout(() => {
      child.kill();
      reject(
        new Error(
          `Timeout ao executar: npx ${args.join(" ")}\nSTDOUT:\n${stdout}\nSTDERR:\n${stderr}`,
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
            `Falha (${code}) ao executar: npx ${args.join(" ")}\nSTDOUT:\n${stdout}\nSTDERR:\n${stderr}`,
          ),
        );
      }
    });
  });
}

async function waitForExit(child, timeoutMs = 5000) {
  if (!child || child.exitCode !== null) return;

  await Promise.race([
    new Promise((resolve) => child.once("exit", resolve)),
    sleep(timeoutMs),
  ]);
}

async function stopWorker() {
  if (!worker) return;

  const currentWorker = worker;
  worker = null;

  if (currentWorker.exitCode !== null) return;

  if (process.platform === "win32" && currentWorker.pid) {
    await new Promise((resolve) => {
      const killer = spawn(
        "taskkill",
        ["/PID", String(currentWorker.pid), "/T", "/F"],
        { stdio: "ignore", windowsHide: true },
      );
      killer.on("exit", resolve);
      killer.on("error", resolve);
    });
  } else {
    currentWorker.kill("SIGTERM");
  }

  await waitForExit(currentWorker);
  await sleep(500);
}

async function waitForApi(timeoutMs = 60000) {
  const deadline = Date.now() + timeoutMs;
  let lastError = null;

  while (Date.now() < deadline) {
    try {
      const response = await fetch(`${API_BASE}/api/health`);
      if (response.ok) return;
      lastError = new Error(`health devolveu HTTP ${response.status}`);
    } catch (error) {
      lastError = error;
    }
    await sleep(500);
  }

  throw new Error(
    `A API de teste não ficou disponível em ${timeoutMs} ms.\n` +
      `Último erro: ${lastError?.message ?? "desconhecido"}\n` +
      `Log do Wrangler:\n${workerLog}`,
  );
}

async function startIsolatedWorker() {
  await stopWorker();
  await removePersistDir();

  await runCommand([
    "wrangler",
    "d1",
    "execute",
    "DB",
    "--config",
    CONFIG_FILE,
    "--local",
    "--persist-to",
    PERSIST_DIR,
    "--file",
    "schema.sql",
    "--yes",
  ]);

  workerLog = "";
  worker = spawn(
    npxCommand,
    [
      "wrangler",
      "dev",
      "--config",
      CONFIG_FILE,
      "--persist-to",
      PERSIST_DIR,
      "--log-level",
      "warn",
    ],
    {
      cwd: ROOT,
      stdio: ["ignore", "pipe", "pipe"],
      shell: process.platform === "win32",
      windowsHide: true,
    },
  );

  worker.stdout?.on("data", appendWorkerLog);
  worker.stderr?.on("data", appendWorkerLog);

  worker.on("error", (error) => {
    appendWorkerLog(`\nFalha ao iniciar Wrangler: ${error.message}\n`);
  });

  await waitForApi();
}

async function apiRequest(
  route,
  {
    method = "GET",
    body,
    token,
    environment = "DEV",
    origin,
    includeEnvironment = true,
  } = {},
) {
  const headers = new Headers();

  if (
    includeEnvironment &&
    route.startsWith("/api/") &&
    route !== "/api/health"
  ) {
    headers.set(ENV_HEADER, environment);
  }

  if (origin) headers.set("Origin", origin);
  if (token) headers.set("Authorization", `Bearer ${token}`);

  let requestBody;
  if (body !== undefined) {
    headers.set("Content-Type", "application/json");
    requestBody = JSON.stringify(body);
  }

  const response = await fetch(`${API_BASE}${route}`, {
    method,
    headers,
    body: requestBody,
  });

  const contentType = response.headers.get("content-type") ?? "";
  const payload = contentType.includes("application/json")
    ? await response.json()
    : await response.text();

  return { response, payload };
}

test(
  "DailyTalk API — Fase 0 — integração local isolada",
  { timeout: 120000 },
  async (t) => {
    await startIsolatedWorker();

    t.after(async () => {
      await stopWorker();
      await removePersistDir({ finalCleanup: true });
    });

    let userToken = "";
    let userEmail = "";
    let submissionId = "";

    await t.test("health responde e aplica headers operacionais", async () => {
      const { response, payload } = await apiRequest("/api/health");
      assert.equal(response.status, 200);
      assert.deepEqual(payload, { ok: true });
      assert.equal(response.headers.get(ENV_HEADER), "DEV");
      assert.equal(response.headers.get("cache-control"), "no-store");
      assert.equal(response.headers.get("pragma"), "no-cache");
      assert.equal(response.headers.get("x-content-type-options"), "nosniff");
      assert.equal(response.headers.get("referrer-policy"), "no-referrer");
    });

    await t.test("raiz expõe a API DailyTalk", async () => {
      const { response, payload } = await apiRequest("/");
      assert.equal(response.status, 200);
      assert.equal(payload.ok, true);
      assert.equal(payload.name, "DailyTalk.pt API");
      assert.ok(Array.isArray(payload.endpoints));
      assert.ok(payload.endpoints.includes("GET /api/health"));
    });

    await t.test("endpoint protegido exige declaração explícita DEV", async () => {
      const { response, payload } = await apiRequest("/api/me", {
        includeEnvironment: false,
      });
      assert.equal(response.status, 409);
      assert.match(String(payload.error), /Ambiente do cliente incompatível/i);
    });

    await t.test("declaração PRD é rejeitada pelo Worker DEV", async () => {
      const { response, payload } = await apiRequest("/api/me", {
        environment: "PRD",
      });
      assert.equal(response.status, 409);
      assert.match(String(payload.error), /Ambiente do cliente incompatível/i);
      assert.equal(response.headers.get(ENV_HEADER), "DEV");
    });

    await t.test("origem PRD é rejeitada pelo Worker DEV", async () => {
      const { response, payload } = await apiRequest("/api/me", {
        origin: "https://dailytalk.pt",
      });
      assert.equal(response.status, 403);
      assert.match(String(payload.error), /Origem incompatível/i);
    });

    await t.test("CORS aceita origem local autorizada", async () => {
      const { response } = await apiRequest("/api/health", {
        origin: "http://localhost:5555",
      });
      assert.equal(response.status, 200);
      assert.equal(
        response.headers.get("access-control-allow-origin"),
        "http://localhost:5555",
      );
    });

    await t.test("rota autenticada rejeita ausência de token", async () => {
      const { response, payload } = await apiRequest("/api/me");
      assert.equal(response.status, 401);
      assert.match(String(payload.error), /Token em falta/i);
    });

    await t.test("registo inválido é rejeitado", async () => {
      const { response } = await apiRequest("/api/auth/register", {
        method: "POST",
        body: {
          name: "P",
          email: "email-invalido",
          password: "123",
          role: "student",
        },
      });
      assert.equal(response.status, 400);
    });

    await t.test("registo válido cria utilizador e token legado", async () => {
      userEmail = `phase0-${Date.now()}@example.com`;

      const { response, payload } = await apiRequest("/api/auth/register", {
        method: "POST",
        body: {
          name: "Phase Zero",
          email: userEmail,
          password: TEST_PASSWORD,
          role: "student",
        },
      });

      assert.equal(response.status, 201);
      assert.equal(payload.success, true);
      assert.equal(payload.user.email, userEmail);
      assert.equal(payload.user.role, "student");
      assert.equal(payload.user.preferences.selectedProfile, "student");
      assert.equal(typeof payload.token, "string");
      assert.equal(payload.token.split(".").length, 3);

      userToken = payload.token;
    });

    await t.test("email duplicado é rejeitado", async () => {
      const { response, payload } = await apiRequest("/api/auth/register", {
        method: "POST",
        body: {
          name: "Phase Zero Duplicado",
          email: userEmail,
          password: TEST_PASSWORD,
          role: "student",
        },
      });

      assert.equal(response.status, 409);
      assert.match(String(payload.error), /Email já registado/i);
    });

    await t.test("login rejeita palavra-passe errada", async () => {
      const { response, payload } = await apiRequest("/api/auth/login", {
        method: "POST",
        body: {
          email: userEmail,
          password: "palavra-passe-errada",
        },
      });

      assert.equal(response.status, 401);
      assert.match(String(payload.error), /Credenciais inválidas/i);
    });

    await t.test("login válido emite token utilizável", async () => {
      const { response, payload } = await apiRequest("/api/auth/login", {
        method: "POST",
        body: {
          email: userEmail,
          password: TEST_PASSWORD,
        },
      });

      assert.equal(response.status, 200);
      assert.equal(payload.success, true);
      assert.equal(payload.user.email, userEmail);
      assert.equal(typeof payload.token, "string");
      userToken = payload.token;
    });

    await t.test("/api/me devolve apenas o utilizador autenticado", async () => {
      const { response, payload } = await apiRequest("/api/me", {
        token: userToken,
      });

      assert.equal(response.status, 200);
      assert.equal(payload.success, true);
      assert.equal(payload.user.email, userEmail);
      assert.equal(payload.user.role, "student");
    });

    await t.test("token adulterado é rejeitado", async () => {
      const tampered = `${userToken.slice(0, -1)}${
        userToken.endsWith("A") ? "B" : "A"
      }`;
      const { response } = await apiRequest("/api/me", { token: tampered });
      assert.equal(response.status, 401);
    });

    await t.test("preferências são persistidas", async () => {
      const { response, payload } = await apiRequest("/api/me/preferences", {
        method: "PUT",
        token: userToken,
        body: {
          appLanguageCode: "pt-PT",
          learningLanguageCode: "fr-FR",
          selectedProfile: "student",
          difficultyLevel: "beginner",
        },
      });

      assert.equal(response.status, 200);
      assert.equal(payload.success, true);
      assert.equal(payload.user.preferences.appLanguageCode, "pt-PT");
      assert.equal(payload.user.preferences.learningLanguageCode, "fr-FR");
      assert.equal(payload.user.preferences.selectedProfile, "student");
      assert.equal(payload.user.preferences.difficultyLevel, "beginner");
    });

    await t.test("submissão válida é persistida", async () => {
      const { response, payload } = await apiRequest(
        "/api/activities/submissions",
        {
          method: "POST",
          token: userToken,
          body: {
            activityID: "phase0-vocabulary-001",
            submission: {
              activityType: "vocabulary",
              nativeLanguageCode: "pt-PT",
              targetLanguageCode: "fr-FR",
              answers: [
                {
                  value:
                    "Esta é uma resposta suficientemente longa para o teste.",
                },
              ],
            },
          },
        },
      );

      assert.equal(response.status, 200);
      assert.equal(payload.success, true);
      assert.equal(payload.activityID, "phase0-vocabulary-001");
      assert.equal(payload.score, 90);
      assert.equal(typeof payload.submissionId, "string");

      submissionId = payload.submissionId;
    });

    await t.test("utilizador recupera as próprias submissões", async () => {
      const { response, payload } = await apiRequest(
        "/api/activities/submissions/mine",
        { token: userToken },
      );

      assert.equal(response.status, 200);
      assert.equal(payload.success, true);
      assert.ok(Array.isArray(payload.submissions));
      assert.ok(
        payload.submissions.some(
          (item) =>
            item.id === submissionId &&
            item.remote_activity_id === "phase0-vocabulary-001",
        ),
      );
    });

    await t.test("submissões permanecem isoladas entre utilizadores", async () => {
      const otherEmail = `phase0-other-${Date.now()}@example.com`;
      const registered = await apiRequest("/api/auth/register", {
        method: "POST",
        body: {
          name: "Other User",
          email: otherEmail,
          password: TEST_PASSWORD,
          role: "student",
        },
      });

      assert.equal(registered.response.status, 201);
      const otherToken = registered.payload.token;

      const mine = await apiRequest("/api/activities/submissions/mine", {
        token: otherToken,
      });

      assert.equal(mine.response.status, 200);
      assert.equal(mine.payload.success, true);
      assert.ok(Array.isArray(mine.payload.submissions));
      assert.equal(mine.payload.submissions.length, 0);
    });
  },
);
