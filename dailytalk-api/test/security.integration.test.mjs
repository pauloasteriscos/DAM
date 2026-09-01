import test from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { rm, writeFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const ROOT = process.cwd();
const API_BASE = "http://127.0.0.1:8792";
const PERSIST_DIR = path.join(ROOT, ".wrangler", "phase0-security-test-state");
const CONFIG_FILE = path.join(ROOT, "wrangler.security.test.generated.jsonc");
const ENV_HEADER = "X-DailyTalk-Environment";
const TEST_PASSWORD = "Phase0-Security-Test-Password-2026!";
const SERVER_SIGNING_KID = "phase0-server-signing-v1";
const SERVER_AGREEMENT_KID = "phase0-server-agreement-v1";
const wranglerCli = path.join(
  ROOT,
  "node_modules",
  "wrangler",
  "bin",
  "wrangler.js",
);
const encoder = new TextEncoder();
const decoder = new TextDecoder();

let worker = null;
let workerLog = "";
let serverKeys = null;

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function utf8(value) {
  return encoder.encode(value);
}

function decodeUtf8(value) {
  return decoder.decode(value);
}

function base64UrlEncode(value) {
  const bytes = value instanceof Uint8Array ? value : new Uint8Array(value);
  return Buffer.from(bytes)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function base64UrlDecode(value) {
  if (!/^[A-Za-z0-9_-]*$/.test(value)) {
    throw new Error("Base64url inválido");
  }
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  return new Uint8Array(Buffer.from(padded, "base64"));
}

function base64UrlJson(value) {
  return base64UrlEncode(utf8(JSON.stringify(value)));
}

function parseBase64UrlJson(value) {
  return JSON.parse(decodeUtf8(base64UrlDecode(value)));
}

function concatBytes(...parts) {
  const arrays = parts.map((part) =>
    part instanceof Uint8Array ? part : new Uint8Array(part),
  );
  const length = arrays.reduce((total, part) => total + part.length, 0);
  const output = new Uint8Array(length);
  let offset = 0;
  for (const part of arrays) {
    output.set(part, offset);
    offset += part.length;
  }
  return output;
}

function uint32(value) {
  const output = new Uint8Array(4);
  new DataView(output.buffer).setUint32(0, value, false);
  return output;
}

function lengthPrefixed(value) {
  return concatBytes(uint32(value.length), value);
}

async function sha256(value) {
  return new Uint8Array(await crypto.subtle.digest("SHA-256", value));
}

async function sha256Base64Url(value) {
  return base64UrlEncode(await sha256(value));
}

function publicOnlyJwk(jwk) {
  const result = {
    kty: "OKP",
    crv: jwk.crv,
    x: jwk.x,
  };
  if (jwk.kid) result.kid = jwk.kid;
  return result;
}

function privateOnlyJwk(jwk) {
  return {
    kty: "OKP",
    crv: jwk.crv,
    x: jwk.x,
    d: jwk.d,
  };
}

async function generateOkpPair(curve) {
  const usages = curve === "Ed25519"
    ? ["sign", "verify"]
    : ["deriveBits"];

  const pair = await crypto.subtle.generateKey(
    { name: curve },
    true,
    usages,
  );

  const publicJwk = publicOnlyJwk(
    await crypto.subtle.exportKey("jwk", pair.publicKey),
  );
  // Node 22 pode exportar metadados adicionais como alg/key_ops/ext.
  // Para os fixtures JOSE usamos apenas os membros RFC 8037 necessários,
  // evitando diferenças de importação entre Node e workerd/WebCrypto.
  const privateJwk = privateOnlyJwk(
    await crypto.subtle.exportKey("jwk", pair.privateKey),
  );

  return {
    pair,
    publicJwk,
    privateJwk,
  };
}

async function okpThumbprint(jwk) {
  const canonical = JSON.stringify({
    crv: jwk.crv,
    kty: jwk.kty,
    x: jwk.x,
  });
  return sha256Base64Url(utf8(canonical));
}

async function makeDpopProof({
  signingPair,
  publicJwk,
  method,
  route,
  accessToken,
  jti = crypto.randomUUID(),
  htuOverride,
  htmOverride,
  athOverride,
  iatOverride,
}) {
  const header = {
    typ: "dpop+jwt",
    alg: "EdDSA",
    jwk: publicOnlyJwk(publicJwk),
  };

  const claims = {
    jti,
    htm: htmOverride ?? method.toUpperCase(),
    htu: htuOverride ?? `${API_BASE}${new URL(`${API_BASE}${route}`).pathname}`,
    iat: iatOverride ?? Math.floor(Date.now() / 1000),
  };

  if (accessToken !== undefined) {
    claims.ath = athOverride ?? await sha256Base64Url(utf8(accessToken));
  } else if (athOverride !== undefined) {
    claims.ath = athOverride;
  }

  const protectedPart = base64UrlJson(header);
  const payloadPart = base64UrlJson(claims);
  const signature = await crypto.subtle.sign(
    "Ed25519",
    signingPair.privateKey,
    utf8(`${protectedPart}.${payloadPart}`),
  );

  return `${protectedPart}.${payloadPart}.${base64UrlEncode(signature)}`;
}

async function signCompactJws({
  payload,
  signingPair,
  keyId,
  type,
}) {
  const header = {
    alg: "EdDSA",
    typ: type,
    kid: keyId,
  };
  const protectedPart = base64UrlJson(header);
  const payloadPart = base64UrlEncode(payload);
  const signature = await crypto.subtle.sign(
    "Ed25519",
    signingPair.privateKey,
    utf8(`${protectedPart}.${payloadPart}`),
  );

  return `${protectedPart}.${payloadPart}.${base64UrlEncode(signature)}`;
}

async function verifyCompactJws({
  compact,
  publicJwk,
  expectedKeyId,
  expectedType,
}) {
  const parts = compact.split(".");
  assert.equal(parts.length, 3, "JWS Compact deve ter 3 partes");
  const [protectedPart, payloadPart, signaturePart] = parts;

  const header = parseBase64UrlJson(protectedPart);
  assert.equal(header.alg, "EdDSA");
  assert.equal(header.typ, expectedType);
  assert.equal(header.kid, expectedKeyId);

  const publicKey = await crypto.subtle.importKey(
    "jwk",
    publicOnlyJwk(publicJwk),
    { name: "Ed25519" },
    false,
    ["verify"],
  );

  const valid = await crypto.subtle.verify(
    "Ed25519",
    publicKey,
    base64UrlDecode(signaturePart),
    utf8(`${protectedPart}.${payloadPart}`),
  );

  assert.equal(valid, true, "Assinatura JWS da resposta é inválida");
  return base64UrlDecode(payloadPart);
}

async function deriveX25519Secret(privateJwk, publicJwk) {
  const privateKey = await crypto.subtle.importKey(
    "jwk",
    privateJwk,
    { name: "X25519" },
    false,
    ["deriveBits"],
  );
  const publicKey = await crypto.subtle.importKey(
    "jwk",
    publicOnlyJwk(publicJwk),
    { name: "X25519" },
    false,
    [],
  );

  return new Uint8Array(
    await crypto.subtle.deriveBits(
      { name: "X25519", public: publicKey },
      privateKey,
      256,
    ),
  );
}

async function concatKdfA256Gcm(sharedSecret, senderParty, recipientParty) {
  const algorithmId = utf8("A256GCM");
  const otherInfo = concatBytes(
    lengthPrefixed(algorithmId),
    lengthPrefixed(utf8(senderParty)),
    lengthPrefixed(utf8(recipientParty)),
    uint32(256),
  );

  return sha256(concatBytes(uint32(1), sharedSecret, otherInfo));
}

async function encryptCompactJwe({
  plaintext,
  recipientPublicJwk,
  recipientKeyId,
  senderParty,
  recipientParty,
  type,
}) {
  const ephemeral = await generateOkpPair("X25519");
  const sharedSecret = await deriveX25519Secret(
    ephemeral.privateJwk,
    recipientPublicJwk,
  );
  const contentKeyBytes = await concatKdfA256Gcm(
    sharedSecret,
    senderParty,
    recipientParty,
  );

  const header = {
    alg: "ECDH-ES",
    enc: "A256GCM",
    typ: type,
    cty: "JOSE",
    kid: recipientKeyId,
    epk: publicOnlyJwk(ephemeral.publicJwk),
    apu: base64UrlEncode(utf8(senderParty)),
    apv: base64UrlEncode(utf8(recipientParty)),
  };

  const protectedPart = base64UrlJson(header);
  const nonce = crypto.getRandomValues(new Uint8Array(12));
  const aesKey = await crypto.subtle.importKey(
    "raw",
    contentKeyBytes,
    { name: "AES-GCM" },
    false,
    ["encrypt"],
  );

  const cipherAndTag = new Uint8Array(
    await crypto.subtle.encrypt(
      {
        name: "AES-GCM",
        iv: nonce,
        additionalData: utf8(protectedPart),
        tagLength: 128,
      },
      aesKey,
      plaintext,
    ),
  );

  const cipherText = cipherAndTag.slice(0, -16);
  const tag = cipherAndTag.slice(-16);

  return [
    protectedPart,
    "",
    base64UrlEncode(nonce),
    base64UrlEncode(cipherText),
    base64UrlEncode(tag),
  ].join(".");
}

async function decryptCompactJwe({
  compact,
  recipientPrivateJwk,
  expectedRecipientKeyId,
  expectedSenderParty,
  expectedRecipientParty,
  expectedType,
}) {
  const parts = compact.split(".");
  assert.equal(parts.length, 5, "JWE Compact deve ter 5 partes");

  const [protectedPart, encryptedKeyPart, ivPart, cipherPart, tagPart] = parts;
  assert.equal(encryptedKeyPart, "", "ECDH-ES não deve transportar encrypted key");

  const header = parseBase64UrlJson(protectedPart);
  assert.equal(header.alg, "ECDH-ES");
  assert.equal(header.enc, "A256GCM");
  assert.equal(header.typ, expectedType);
  assert.equal(header.cty, "JOSE");
  assert.equal(header.kid, expectedRecipientKeyId);
  assert.equal(decodeUtf8(base64UrlDecode(header.apu)), expectedSenderParty);
  assert.equal(decodeUtf8(base64UrlDecode(header.apv)), expectedRecipientParty);

  const sharedSecret = await deriveX25519Secret(
    recipientPrivateJwk,
    header.epk,
  );
  const contentKeyBytes = await concatKdfA256Gcm(
    sharedSecret,
    expectedSenderParty,
    expectedRecipientParty,
  );

  const aesKey = await crypto.subtle.importKey(
    "raw",
    contentKeyBytes,
    { name: "AES-GCM" },
    false,
    ["decrypt"],
  );

  const plaintext = await crypto.subtle.decrypt(
    {
      name: "AES-GCM",
      iv: base64UrlDecode(ivPart),
      additionalData: utf8(protectedPart),
      tagLength: 128,
    },
    aesKey,
    concatBytes(base64UrlDecode(cipherPart), base64UrlDecode(tagPart)),
  );

  return new Uint8Array(plaintext);
}

function decodeJwtPayload(token) {
  const parts = token.split(".");
  assert.equal(parts.length, 3);
  return parseBase64UrlJson(parts[1]);
}

function appendWorkerLog(chunk) {
  workerLog += chunk.toString();
  if (workerLog.length > 30000) {
    workerLog = workerLog.slice(-30000);
  }
}

function runCommand(args, { timeoutMs = 60000 } = {}) {
  return new Promise((resolve, reject) => {
    if (args[0] !== "wrangler") {
      throw new Error(`Comando inesperado no harness: ${args.join(" ")}`);
    }

    const wranglerArgs = args.slice(1);
    const child = spawn(process.execPath, [wranglerCli, ...wranglerArgs], {
      cwd: ROOT,
      stdio: ["ignore", "pipe", "pipe"],
      shell: false,
      windowsHide: true,
    });

    let stdout = "";
    let stderr = "";

    const timer = setTimeout(() => {
      child.kill();
      reject(
        new Error(
          `Timeout ao executar npx ${args.join(" ")}\nSTDOUT:\n${stdout}\nSTDERR:\n${stderr}`,
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
            `Falha (${code}) ao executar npx ${args.join(" ")}\nSTDOUT:\n${stdout}\nSTDERR:\n${stderr}`,
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

  const current = worker;
  worker = null;

  if (current.exitCode === null) {
    if (process.platform === "win32" && current.pid) {
      await new Promise((resolve) => {
        const killer = spawn(
          "taskkill",
          ["/PID", String(current.pid), "/T", "/F"],
          { stdio: "ignore", windowsHide: true },
        );
        killer.on("exit", resolve);
        killer.on("error", resolve);
      });
    } else {
      current.kill("SIGTERM");
    }

    await waitForExit(current);
    await sleep(500);
  }
}

async function removePath(target, { finalCleanup = false } = {}) {
  try {
    await rm(target, {
      recursive: true,
      force: true,
      maxRetries: 20,
      retryDelay: 250,
    });
  } catch (error) {
    if (finalCleanup && error?.code === "EBUSY") {
      console.warn(
        `Aviso: Windows ainda mantém um recurso temporário bloqueado: ${target}`,
      );
      return;
    }
    throw error;
  }
}

async function writeSecurityConfig() {
  const serverSigning = await generateOkpPair("Ed25519");
  const serverAgreement = await generateOkpPair("X25519");

  serverKeys = {
    signing: serverSigning,
    agreement: serverAgreement,
  };

  const config = {
    "$schema": "node_modules/wrangler/config-schema.json",
    name: "dailytalk-api-phase0-security-test",
    main: "src/index.ts",
    compatibility_date: "2026-05-24",
    compatibility_flags: ["nodejs_compat"],
    dev: {
      ip: "127.0.0.1",
      port: 8792,
      local_protocol: "http",
    },
    observability: {
      enabled: false,
    },
    vars: {
      APP_ENV: "DEV",
      JWT_SECRET:
        "phase0-security-test-only-secret-do-not-use-outside-tests-2026",
      JWT_EXPIRES_SECONDS: "900",
      DEVICE_SESSION_EXPIRES_DAYS: "730",
      DPOP_MAX_AGE_SECONDS: "300",
      AUTO_CREATE_SECURITY_SCHEMA: "false",
      ALLOW_LEGACY_DEVICE_ENROLLMENT: "true",
      SYNC_MAX_BATCH_SIZE: "50",
      SYNC_SERVER_SIGNING_KEY_ID: SERVER_SIGNING_KID,
      SYNC_SERVER_AGREEMENT_KEY_ID: SERVER_AGREEMENT_KID,
      SYNC_SERVER_SIGNING_PRIVATE_JWK: JSON.stringify(
        serverSigning.privateJwk,
      ),
      SYNC_SERVER_SIGNING_PUBLIC_JWK: JSON.stringify(
        serverSigning.publicJwk,
      ),
      SYNC_SERVER_AGREEMENT_PRIVATE_JWK: JSON.stringify(
        serverAgreement.privateJwk,
      ),
      SYNC_SERVER_AGREEMENT_PUBLIC_JWK: JSON.stringify(
        serverAgreement.publicJwk,
      ),
      CORS_ORIGIN: "http://localhost:5555,http://127.0.0.1:5555",
      PASSWORD_RESET_DEBUG: "false",
    },
    d1_databases: [
      {
        binding: "DB",
        database_name: "dailytalk-security-test",
        database_id: "00000000-0000-0000-0000-000000000002",
      },
    ],
  };

  await writeFile(CONFIG_FILE, JSON.stringify(config, null, 2), "utf8");
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
    `A API de segurança não ficou disponível.\n` +
      `Último erro: ${lastError?.message ?? "desconhecido"}\n` +
      `Log do Wrangler:\n${workerLog}`,
  );
}

async function startWorker() {
  await stopWorker();
  await removePath(PERSIST_DIR);
  await removePath(CONFIG_FILE);
  await writeSecurityConfig();

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
    process.execPath,
    [
      wranglerCli,
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
      shell: false,
      windowsHide: true,
    },
  );

  worker.stdout?.on("data", appendWorkerLog);
  worker.stderr?.on("data", appendWorkerLog);
  worker.on("error", (error) => appendWorkerLog(String(error)));

  await waitForApi();
}

async function apiRequest(
  route,
  {
    method = "GET",
    body,
    token,
    dpop,
    authorizationScheme = "Bearer",
    environment = "DEV",
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

  if (token) {
    headers.set("Authorization", `${authorizationScheme} ${token}`);
  }
  if (dpop) {
    headers.set("DPoP", dpop);
  }

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

async function boundRequest({
  route,
  method = "GET",
  token,
  deviceKeys,
  body,
  jti,
}) {
  const proof = await makeDpopProof({
    signingPair: deviceKeys.signing.pair,
    publicJwk: deviceKeys.signing.publicJwk,
    method,
    route,
    accessToken: token,
    jti,
  });

  return apiRequest(route, {
    method,
    body,
    token,
    dpop: proof,
    authorizationScheme: "DPoP",
  });
}

async function makeSyncEnvelope({
  batch,
  deviceId,
  deviceKeys,
  signingPair = deviceKeys.signing.pair,
}) {
  const signed = await signCompactJws({
    payload: utf8(JSON.stringify(batch)),
    signingPair,
    keyId: deviceId,
    type: "dailytalk-sync+jws",
  });

  return encryptCompactJwe({
    plaintext: utf8(signed),
    recipientPublicJwk: serverKeys.agreement.publicJwk,
    recipientKeyId: SERVER_AGREEMENT_KID,
    senderParty: deviceId,
    recipientParty: SERVER_AGREEMENT_KID,
    type: "dailytalk-sync+jwe",
  });
}

async function decodeSyncResponse(envelope, deviceId, deviceKeys) {
  const signedResponse = await decryptCompactJwe({
    compact: envelope,
    recipientPrivateJwk: deviceKeys.agreement.privateJwk,
    expectedRecipientKeyId: deviceId,
    expectedSenderParty: SERVER_AGREEMENT_KID,
    expectedRecipientParty: deviceId,
    expectedType: "dailytalk-sync-response+jwe",
  });

  const payload = await verifyCompactJws({
    compact: decodeUtf8(signedResponse),
    publicJwk: serverKeys.signing.publicJwk,
    expectedKeyId: SERVER_SIGNING_KID,
    expectedType: "dailytalk-sync-response+jws",
  });

  return JSON.parse(decodeUtf8(payload));
}

test(
  "DailyTalk API — Fase 0 — segurança DPoP/JWS/JWE",
  { timeout: 180000 },
  async (t) => {
    await startWorker();

    t.after(async () => {
      await stopWorker();
      await removePath(PERSIST_DIR, { finalCleanup: true });
      await removePath(CONFIG_FILE, { finalCleanup: true });
    });

    const deviceKeys = {
      signing: await generateOkpPair("Ed25519"),
      agreement: await generateOkpPair("X25519"),
    };
    const attackerKeys = {
      signing: await generateOkpPair("Ed25519"),
      agreement: await generateOkpPair("X25519"),
    };

    let accessToken = "";
    let refreshToken = "";
    let deviceId = "";
    let userEmail = "";
    let firstSyncEnvelope = "";
    let firstSyncResponse = "";
    let firstSyncBatch = null;

    await t.test("registo com dispositivo cria sessão vinculada", async () => {
      userEmail = `phase0-security-${Date.now()}@example.com`;

      const { response, payload } = await apiRequest("/api/auth/register", {
        method: "POST",
        body: {
          name: "Phase Zero Security",
          email: userEmail,
          password: TEST_PASSWORD,
          role: "student",
          device: {
            installationId: `phase0-security-installation-${Date.now()}`,
            name: "Phase0 Security Device",
            platform: "windows-test",
            appVersion: "phase0",
            signingPublicJwk: deviceKeys.signing.publicJwk,
            agreementPublicJwk: deviceKeys.agreement.publicJwk,
          },
        },
      });

      assert.equal(response.status, 201);
      assert.equal(payload.success, true);
      assert.equal(typeof payload.accessToken, "string");
      assert.equal(typeof payload.refreshToken, "string");
      assert.equal(typeof payload.deviceId, "string");

      accessToken = payload.accessToken;
      refreshToken = payload.refreshToken;
      deviceId = payload.deviceId;

      const claims = decodeJwtPayload(accessToken);
      assert.equal(claims.did, deviceId);
      assert.equal(typeof claims.sid, "string");
      assert.equal(claims.env, "DEV");
      assert.equal(
        claims.cnf?.jkt,
        await okpThumbprint(deviceKeys.signing.publicJwk),
      );
    });

    await t.test("token vinculado não aceita esquema Bearer", async () => {
      const { response, payload } = await apiRequest("/api/me", {
        token: accessToken,
        authorizationScheme: "Bearer",
      });

      assert.equal(response.status, 401);
      assert.match(
        String(payload.error),
        /Sessão vinculada exige autenticação DPoP/i,
      );
    });

    await t.test("token vinculado sem prova DPoP é rejeitado", async () => {
      const { response } = await apiRequest("/api/me", {
        token: accessToken,
        authorizationScheme: "DPoP",
      });
      assert.equal(response.status, 401);
    });

    await t.test("prova DPoP válida autoriza /api/me", async () => {
      const { response, payload } = await boundRequest({
        route: "/api/me",
        token: accessToken,
        deviceKeys,
      });

      assert.equal(response.status, 200);
      assert.equal(payload.success, true);
      assert.equal(payload.user.email, userEmail);
    });

    await t.test("replay do mesmo jti DPoP é rejeitado", async () => {
      const jti = crypto.randomUUID();
      const proof = await makeDpopProof({
        signingPair: deviceKeys.signing.pair,
        publicJwk: deviceKeys.signing.publicJwk,
        method: "GET",
        route: "/api/me",
        accessToken,
        jti,
      });

      const first = await apiRequest("/api/me", {
        token: accessToken,
        dpop: proof,
        authorizationScheme: "DPoP",
      });
      assert.equal(first.response.status, 200);

      const replay = await apiRequest("/api/me", {
        token: accessToken,
        dpop: proof,
        authorizationScheme: "DPoP",
      });
      assert.equal(replay.response.status, 401);
    });

    await t.test("DPoP com método HTTP incorreto é rejeitado", async () => {
      const proof = await makeDpopProof({
        signingPair: deviceKeys.signing.pair,
        publicJwk: deviceKeys.signing.publicJwk,
        method: "GET",
        route: "/api/me",
        accessToken,
        htmOverride: "POST",
      });

      const { response } = await apiRequest("/api/me", {
        token: accessToken,
        dpop: proof,
        authorizationScheme: "DPoP",
      });

      assert.equal(response.status, 401);
    });

    await t.test("DPoP com htu incorreto é rejeitado", async () => {
      const proof = await makeDpopProof({
        signingPair: deviceKeys.signing.pair,
        publicJwk: deviceKeys.signing.publicJwk,
        method: "GET",
        route: "/api/me",
        accessToken,
        htuOverride: `${API_BASE}/api/rota-errada`,
      });

      const { response } = await apiRequest("/api/me", {
        token: accessToken,
        dpop: proof,
        authorizationScheme: "DPoP",
      });

      assert.equal(response.status, 401);
    });

    await t.test("DPoP com ath incorreto é rejeitado", async () => {
      const proof = await makeDpopProof({
        signingPair: deviceKeys.signing.pair,
        publicJwk: deviceKeys.signing.publicJwk,
        method: "GET",
        route: "/api/me",
        accessToken,
        athOverride: await sha256Base64Url(utf8("token-incorreto")),
      });

      const { response } = await apiRequest("/api/me", {
        token: accessToken,
        dpop: proof,
        authorizationScheme: "DPoP",
      });

      assert.equal(response.status, 401);
    });

    await t.test("DPoP assinado por outra chave é rejeitado", async () => {
      const proof = await makeDpopProof({
        signingPair: attackerKeys.signing.pair,
        publicJwk: attackerKeys.signing.publicJwk,
        method: "GET",
        route: "/api/me",
        accessToken,
      });

      const { response } = await apiRequest("/api/me", {
        token: accessToken,
        dpop: proof,
        authorizationScheme: "DPoP",
      });

      assert.equal(response.status, 401);
    });

    await t.test("refresh sem DPoP é rejeitado", async () => {
      const { response, payload } = await apiRequest("/api/auth/refresh", {
        method: "POST",
        body: { refreshToken },
      });

      assert.equal(response.status, 401);
      assert.match(String(payload.error), /Prova DPoP em falta/i);
    });

    await t.test("refresh com DPoP válido renova access token", async () => {
      const proof = await makeDpopProof({
        signingPair: deviceKeys.signing.pair,
        publicJwk: deviceKeys.signing.publicJwk,
        method: "POST",
        route: "/api/auth/refresh",
      });

      const { response, payload } = await apiRequest("/api/auth/refresh", {
        method: "POST",
        dpop: proof,
        body: { refreshToken },
      });

      assert.equal(response.status, 200);
      assert.equal(payload.success, true);
      assert.equal(payload.deviceId, deviceId);
      assert.equal(typeof payload.accessToken, "string");

      accessToken = payload.accessToken;
      const claims = decodeJwtPayload(accessToken);
      assert.equal(claims.did, deviceId);
      assert.equal(
        claims.cnf?.jkt,
        await okpThumbprint(deviceKeys.signing.publicJwk),
      );
    });

    await t.test("lista de dispositivos funciona com DPoP", async () => {
      const { response, payload } = await boundRequest({
        route: "/api/devices",
        token: accessToken,
        deviceKeys,
      });

      assert.equal(response.status, 200);
      assert.equal(payload.success, true);
      assert.ok(Array.isArray(payload.devices));
      assert.ok(
        payload.devices.some(
          (device) => device.id === deviceId && Number(device.active) === 1,
        ),
      );
    });

    await t.test("endpoint público expõe somente chaves públicas de sync", async () => {
      const { response, payload } = await apiRequest(
        "/api/security/sync-keys",
      );

      assert.equal(response.status, 200);
      assert.equal(payload.success, true);
      assert.equal(payload.version, 1);
      assert.equal(payload.signingKey.kid, SERVER_SIGNING_KID);
      assert.equal(payload.signingKey.crv, "Ed25519");
      assert.equal(payload.signingKey.d, undefined);
      assert.equal(payload.agreementKey.kid, SERVER_AGREEMENT_KID);
      assert.equal(payload.agreementKey.crv, "X25519");
      assert.equal(payload.agreementKey.d, undefined);
      assert.equal(
        payload.signingKey.x,
        serverKeys.signing.publicJwk.x,
      );
      assert.equal(
        payload.agreementKey.x,
        serverKeys.agreement.publicJwk.x,
      );
    });

    await t.test("secure sync JWS+JWE aceita lote e cifra/assina resposta", async () => {
      const now = new Date();
      const batch = {
        version: 1,
        batchId: `phase0-batch-${crypto.randomUUID()}`,
        deviceId,
        issuedAt: now.toISOString(),
        expiresAt: new Date(now.getTime() + 5 * 60 * 1000).toISOString(),
        sequence: 1,
        items: [
          {
            clientSubmissionId: `phase0-client-${crypto.randomUUID()}`,
            remoteActivityId: "phase0-secure-vocabulary-001",
            createdAt: now.toISOString(),
            submission: {
              activityType: "vocabulary",
              nativeLanguageCode: "pt-PT",
              targetLanguageCode: "fr-FR",
              answers: [
                {
                  value:
                    "Resposta suficientemente longa para validar a sincronização segura.",
                },
              ],
            },
          },
        ],
      };

      firstSyncBatch = batch;
      firstSyncEnvelope = await makeSyncEnvelope({
        batch,
        deviceId,
        deviceKeys,
      });

      const { response, payload } = await boundRequest({
        route: "/api/sync/progress",
        method: "POST",
        token: accessToken,
        deviceKeys,
        body: { envelope: firstSyncEnvelope },
      });

      assert.equal(
        response.status,
        200,
        `Secure sync devolveu HTTP ${response.status}. Payload: ${JSON.stringify(payload)}\n` +
          `Último log do Worker:\n${workerLog}`,
      );
      assert.equal(payload.success, true);
      assert.equal(typeof payload.envelope, "string");

      firstSyncResponse = payload.envelope;
      const decoded = await decodeSyncResponse(
        payload.envelope,
        deviceId,
        deviceKeys,
      );

      assert.equal(decoded.version, 1);
      assert.equal(decoded.batchId, batch.batchId);
      assert.equal(decoded.deviceId, deviceId);
      assert.equal(decoded.sequence, 1);
      assert.equal(decoded.results.length, 1);
      assert.equal(decoded.results[0].status, "accepted");
      assert.equal(
        decoded.results[0].clientSubmissionId,
        batch.items[0].clientSubmissionId,
      );

      firstSyncBatch = batch;
    });

    await t.test("retry do mesmo batch é idempotente", async () => {
      const batch = firstSyncBatch;
      assert.ok(batch, "Batch inicial não foi criado");
      const retryEnvelope = await makeSyncEnvelope({
        batch,
        deviceId,
        deviceKeys,
      });

      const { response, payload } = await boundRequest({
        route: "/api/sync/progress",
        method: "POST",
        token: accessToken,
        deviceKeys,
        body: { envelope: retryEnvelope },
      });

      assert.equal(response.status, 200);
      assert.equal(payload.success, true);
      assert.equal(payload.envelope, firstSyncResponse);
    });

    await t.test("batchId reutilizado com conteúdo diferente é rejeitado", async () => {
      const original = firstSyncBatch;
      assert.ok(original, "Batch inicial não foi criado");
      const changedBatch = {
        ...original,
        items: [
          {
            ...original.items[0],
            remoteActivityId: "phase0-secure-content-changed",
          },
        ],
      };

      const envelope = await makeSyncEnvelope({
        batch: changedBatch,
        deviceId,
        deviceKeys,
      });

      const { response, payload } = await boundRequest({
        route: "/api/sync/progress",
        method: "POST",
        token: accessToken,
        deviceKeys,
        body: { envelope },
      });

      assert.equal(response.status, 409);
      assert.match(
        String(payload.error),
        /batchId reutilizado com conteúdo diferente/i,
      );
    });

    await t.test("nova batch com sequence repetida é rejeitada", async () => {
      const original = firstSyncBatch;
      assert.ok(original, "Batch inicial não foi criado");
      const repeatedSequence = {
        ...original,
        batchId: `phase0-batch-${crypto.randomUUID()}`,
      };

      const envelope = await makeSyncEnvelope({
        batch: repeatedSequence,
        deviceId,
        deviceKeys,
      });

      const { response, payload } = await boundRequest({
        route: "/api/sync/progress",
        method: "POST",
        token: accessToken,
        deviceKeys,
        body: { envelope },
      });

      assert.equal(response.status, 409);
      assert.match(
        String(payload.error),
        /Sequência de sincronização repetida/i,
      );
    });

    await t.test("clientSubmissionId repetido em sequência nova retorna duplicate", async () => {
      const original = firstSyncBatch;
      assert.ok(original, "Batch inicial não foi criado");
      const now = new Date();
      const duplicateClient = {
        ...original,
        batchId: `phase0-batch-${crypto.randomUUID()}`,
        sequence: 2,
        issuedAt: now.toISOString(),
        expiresAt: new Date(now.getTime() + 5 * 60 * 1000).toISOString(),
      };

      const envelope = await makeSyncEnvelope({
        batch: duplicateClient,
        deviceId,
        deviceKeys,
      });

      const { response, payload } = await boundRequest({
        route: "/api/sync/progress",
        method: "POST",
        token: accessToken,
        deviceKeys,
        body: { envelope },
      });

      assert.equal(response.status, 200);
      const decoded = await decodeSyncResponse(
        payload.envelope,
        deviceId,
        deviceKeys,
      );

      assert.equal(decoded.sequence, 2);
      assert.equal(decoded.results[0].status, "duplicate");
    });

    await t.test("JWS de sync assinado por chave errada é rejeitado", async () => {
      const now = new Date();
      const batch = {
        version: 1,
        batchId: `phase0-batch-${crypto.randomUUID()}`,
        deviceId,
        issuedAt: now.toISOString(),
        expiresAt: new Date(now.getTime() + 5 * 60 * 1000).toISOString(),
        sequence: 3,
        items: [
          {
            clientSubmissionId: `phase0-client-${crypto.randomUUID()}`,
            remoteActivityId: "phase0-invalid-signature",
            createdAt: now.toISOString(),
            submission: {
              answers: [{ value: "Resposta válida mas assinada por chave errada." }],
            },
          },
        ],
      };

      const envelope = await makeSyncEnvelope({
        batch,
        deviceId,
        deviceKeys,
        signingPair: attackerKeys.signing.pair,
      });

      const { response, payload } = await boundRequest({
        route: "/api/sync/progress",
        method: "POST",
        token: accessToken,
        deviceKeys,
        body: { envelope },
      });

      assert.equal(response.status, 400);
      assert.match(
        String(payload.error),
        /Pedido de sincronização segura inválido/i,
      );
    });

    await t.test("JWE adulterado é rejeitado pelo AES-GCM", async () => {
      const parts = firstSyncEnvelope.split(".");
      assert.equal(parts.length, 5);

      const cipher = parts[3];
      const last = cipher.at(-1);
      parts[3] = `${cipher.slice(0, -1)}${last === "A" ? "B" : "A"}`;
      const tamperedEnvelope = parts.join(".");

      const { response } = await boundRequest({
        route: "/api/sync/progress",
        method: "POST",
        token: accessToken,
        deviceKeys,
        body: { envelope: tamperedEnvelope },
      });

      assert.equal(response.status, 400);
    });

    await t.test("revogação do dispositivo invalida token e refresh", async () => {
      const revoke = await boundRequest({
        route: `/api/devices/${deviceId}`,
        method: "DELETE",
        token: accessToken,
        deviceKeys,
      });

      assert.equal(revoke.response.status, 200);
      assert.equal(revoke.payload.success, true);

      const afterRevoke = await boundRequest({
        route: "/api/me",
        token: accessToken,
        deviceKeys,
      });
      assert.equal(afterRevoke.response.status, 401);

      const refreshProof = await makeDpopProof({
        signingPair: deviceKeys.signing.pair,
        publicJwk: deviceKeys.signing.publicJwk,
        method: "POST",
        route: "/api/auth/refresh",
      });

      const refreshAfterRevoke = await apiRequest("/api/auth/refresh", {
        method: "POST",
        dpop: refreshProof,
        body: { refreshToken },
      });

      assert.equal(refreshAfterRevoke.response.status, 401);
    });
  },
);
