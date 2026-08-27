import { Hono, type Next } from "hono";
import { cors } from "hono/cors";
import {
  EnrolDeviceSessionRequest,
  ForgotPasswordRequest,
  LoginRequest,
  PreferencesRequest,
  RefreshSessionRequest,
  RegisterRequest,
  ResetPasswordRequest,
  SecureProgressBatch,
  SecureSyncEnvelopeRequest,
  SubmissionRequest,
  type AccessTokenClaims,
  type AuthenticatedUser,
  type Bindings,
  type Variables,
  type AppContext,
} from "./types";
import {
  randomBase64Url as securityRandomBase64Url,
  sha256Base64Url,
  utf8,
} from "./security/encoding";
import { verifyDpopProof, okpJwkThumbprint } from "./security/dpop";
import {
  decryptCompactJwe,
  encryptCompactJwe,
  parseOkpJwk,
  publicOnlyJwk,
  signCompactJws,
  verifyCompactJws,
  type OkpPrivateJwk,
  type OkpPublicJwk,
} from "./security/jose";
import { ensureSecuritySchema } from "./security/schema";

const app = new Hono<{ Bindings: Bindings; Variables: Variables }>();
const textEncoder = new TextEncoder();
const textDecoder = new TextDecoder();

type RuntimeEnvironment = "DEV" | "PRD";

const environmentHeaderName = "X-DailyTalk-Environment";

function firstHeaderValue(value: string | undefined): string | undefined {
  return value
    ?.split(",", 1)[0]
    ?.trim();
}

function isDevelopmentApiHost(host: string): boolean {
  return /^(localhost|127\.0\.0\.1|10\.0\.2\.2)(:\d+)?$/i.test(host);
}

function isProductionApiHost(host: string): boolean {
  return /^(www\.)?dailytalk\.pt(?::443)?$/i.test(host);
}

function environmentFromApiHost(host: string): RuntimeEnvironment | null {
  if (isDevelopmentApiHost(host)) return "DEV";
  if (isProductionApiHost(host)) return "PRD";
  return null;
}

function environmentFromOrigin(origin: string): RuntimeEnvironment | null {
  try {
    const parsed = new URL(origin);
    const host = parsed.host.toLowerCase();

    if (
      parsed.protocol === "http:" &&
      isDevelopmentApiHost(host)
    ) {
      return "DEV";
    }

    if (
      parsed.protocol === "https:" &&
      isProductionApiHost(host)
    ) {
      return "PRD";
    }

    return null;
  } catch (_) {
    return null;
  }
}

/**
 * O ambiente da API é definido pela configuração do processo, não pelo Host.
 *
 * - wrangler.jsonc -> DEV;
 * - wrangler.production.jsonc -> PRD.
 *
 * Desta forma, uma rota de produção nunca consegue transformar o Wrangler
 * local em PRD e um pedido do cliente nunca escolhe o ambiente do servidor.
 */
function requestEnvironment(c: AppContext): RuntimeEnvironment {
  const configured = c.env.APP_ENV?.trim().toUpperCase();

  if (configured === "DEV" || configured === "PRD") {
    return configured;
  }

  throw new Error("APP_ENV ausente ou inválido");
}

function tryRequestEnvironment(c: AppContext): RuntimeEnvironment | null {
  try {
    return requestEnvironment(c);
  } catch (_) {
    return null;
  }
}

function requestAuthority(c: AppContext): string {
  const forwardedHost = firstHeaderValue(
    c.req.header("X-Forwarded-Host"),
  );
  if (forwardedHost) return forwardedHost.toLowerCase();

  const hostHeader = firstHeaderValue(c.req.header("Host"));
  if (hostHeader) return hostHeader.toLowerCase();

  return new URL(c.req.url).host.toLowerCase();
}

function configuredCorsOrigins(c: AppContext): Set<string> {
  const environment = requestEnvironment(c);
  const defaults = environment === "PRD"
    ? ["https://dailytalk.pt", "https://www.dailytalk.pt"]
    : ["http://localhost:5555", "http://127.0.0.1:5555"];

  const configured = (c.env.CORS_ORIGIN ?? "")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);

  const accepted = new Set<string>();

  for (const value of [...defaults, ...configured]) {
    try {
      const origin = new URL(value).origin;
      if (environmentFromOrigin(origin) === environment) {
        accepted.add(origin);
      }
    } catch (_) {
      // Valores inválidos são ignorados. Os defaults seguros permanecem.
    }
  }

  return accepted;
}

function resolveCorsOrigin(origin: string, c: AppContext): string {
  const environment = tryRequestEnvironment(c);
  if (!environment) return "";

  let normalizedOrigin: string;
  try {
    normalizedOrigin = new URL(origin).origin;
  } catch (_) {
    return "";
  }

  if (environmentFromOrigin(normalizedOrigin) !== environment) {
    return "";
  }

  return configuredCorsOrigins(c).has(normalizedOrigin)
    ? normalizedOrigin
    : "";
}

function requiresEnvironmentDeclaration(c: AppContext): boolean {
  if (c.req.method.toUpperCase() === "OPTIONS") return false;

  const pathname = new URL(c.req.url).pathname;

  // Health e raiz podem ser consultados por ferramentas operacionais.
  if (pathname === "/" || pathname === "/api/health") return false;

  return pathname.startsWith("/api/");
}

/**
 * Reconstrói a URL pública exata do pedido para validar a claim DPoP htu.
 *
 * Em DEV Web, o hostname da origem da aplicação determina o alias local da
 * API: localhost permanece localhost e 127.0.0.1 permanece 127.0.0.1.
 * Em aplicações nativas, usa-se o Host efetivamente recebido.
 * Em PRD, a API é sempre https://dailytalk.pt.
 */
function dpopVerificationUrl(c: AppContext): string {
  const internalUrl = new URL(c.req.url);
  const environment = requestEnvironment(c);

  if (environment === "PRD") {
    return `https://dailytalk.pt${internalUrl.pathname}${internalUrl.search}`;
  }

  const origin = c.req.header("Origin");
  if (origin && environmentFromOrigin(origin) === "DEV") {
    const parsedOrigin = new URL(origin);
    return `http://${parsedOrigin.hostname}:8787${internalUrl.pathname}${internalUrl.search}`;
  }

  const authority = requestAuthority(c);
  if (environmentFromApiHost(authority) !== "DEV") {
    throw new Error(`Host DEV não autorizado: ${authority}`);
  }

  return `http://${authority}${internalUrl.pathname}${internalUrl.search}`;
}

function applicationBaseUrl(c: AppContext): string {
  const environment = requestEnvironment(c);

  if (environment === "PRD") {
    return "https://dailytalk.pt";
  }

  const origin = c.req.header("Origin");
  if (origin && environmentFromOrigin(origin) === "DEV") {
    return new URL(origin).origin;
  }

  const authority = requestAuthority(c);
  const hostname = authority.replace(/:\d+$/, "");

  return `http://${hostname}:5555`;
}

app.use(
  "*",
  cors({
    origin: resolveCorsOrigin,
    allowHeaders: [
      "Content-Type",
      "Authorization",
      "DPoP",
      environmentHeaderName,
    ],
    allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    exposeHeaders: [environmentHeaderName],
    maxAge: 86400,
  }),
);

app.use("*", async (c, next) => {
  const environment = tryRequestEnvironment(c);

  if (!environment) {
    return c.json(
      { error: "Ambiente da API não configurado" },
      500,
    );
  }

  const authority = requestAuthority(c);
  const authorityEnvironment = environmentFromApiHost(authority);

  if (authorityEnvironment !== environment) {
    console.warn("Host incompatível com o ambiente da API", {
      environment,
      authority,
      authorityEnvironment,
    });

    c.header(environmentHeaderName, environment);
    return c.json(
      { error: "Host incompatível com o ambiente da API" },
      421,
    );
  }

  const origin = c.req.header("Origin");
  if (origin) {
    const originEnvironment = environmentFromOrigin(origin);

    if (originEnvironment !== environment) {
      console.warn("Pedido entre ambientes rejeitado", {
        environment,
        origin,
        host: authority,
      });

      c.header(environmentHeaderName, environment);
      return c.json(
        { error: "Origem incompatível com o ambiente da API" },
        403,
      );
    }
  }

  if (requiresEnvironmentDeclaration(c)) {
    const declaredEnvironment = c.req
      .header(environmentHeaderName)
      ?.trim()
      .toUpperCase();

    if (declaredEnvironment !== environment) {
      console.warn("Declaração de ambiente rejeitada", {
        expected: environment,
        received: declaredEnvironment ?? null,
        host: authority,
        path: new URL(c.req.url).pathname,
      });

      c.header(environmentHeaderName, environment);
      return c.json(
        { error: "Ambiente do cliente incompatível com a API" },
        409,
      );
    }
  }

  c.header(environmentHeaderName, environment);
  await next();
  c.header(environmentHeaderName, environment);
});

app.use("*", async (c, next) => {
  await next();
  c.header("Cache-Control", "no-store");
  c.header("Pragma", "no-cache");
  c.header("X-Content-Type-Options", "nosniff");
  c.header("Referrer-Policy", "no-referrer");
});

app.get("/", (c) =>
  c.json({
    name: "DailyTalk.pt API",
    ok: true,
    endpoints: [
      "GET /api/health",
      "GET /api/json-params",
      "GET /api/deploy",
      "POST /api/auth/register",
      "POST /api/auth/login",
      "POST /api/auth/refresh",
      "POST /api/auth/forgot-password",
      "POST /api/auth/reset-password",
      "POST /api/devices/enrol-session",
      "GET /api/devices",
      "DELETE /api/devices/:id",
      "GET /api/security/sync-keys",
      "GET /api/me",
      "PUT /api/me/preferences",
      "POST /api/activities/submissions",
      "GET /api/activities/submissions/mine",
      "POST /api/sync/progress",
    ],
  }),
);

app.get("/api/health", (c) => c.json({ ok: true }));

app.get("/api/json-params", (c) =>
  c.json([
    { name: "scenario", type: "text/plain" },
    { name: "language", type: "text/plain" },
    { name: "difficulty", type: "text/plain" },
  ]),
);

app.get("/api/deploy", requireAuth, (c) => {
  const activityId = c.req.query("activityID") ?? crypto.randomUUID();
  const type = c.req.query("type") ?? "practice";

  return c.text(`${applicationBaseUrl(c)}/activity/${type}/${activityId}`);
});

app.post("/api/auth/register", async (c) => {
  const parsed = RegisterRequest.safeParse(await c.req.json().catch(() => null));

  if (!parsed.success) {
    return c.json({ error: "Dados de registo inválidos", details: parsed.error.flatten() }, 400);
  }

  const { name, email, password, role, device } = parsed.data;
  const existing = await c.env.DB.prepare("SELECT id FROM users WHERE email = ?")
    .bind(email)
    .first<{ id: string }>();

  if (existing) {
    return c.json({ error: "Email já registado" }, 409);
  }

  const id = crypto.randomUUID();
  const now = new Date().toISOString();
  const salt = randomBase64Url(16);
  const passwordHash = await hashPassword(password, salt);

  await c.env.DB.batch([
    c.env.DB.prepare(
      `INSERT INTO users (id, name, email, password_hash, password_salt, role, active, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)`,
    ).bind(id, name.trim(), email, passwordHash, salt, role, now, now),
    c.env.DB.prepare(
      `INSERT INTO user_preferences (user_id, selected_profile, created_at, updated_at)
       VALUES (?, ?, ?, ?)`,
    ).bind(id, role, now, now),
  ]);

  const user = await loadUserWithPreferences(c, id);
  const session = device
    ? await createDeviceSession(c, id, device)
    : { token: await signJwt(c, id) };

  return c.json({ success: true, ...session, user }, 201);
});

app.post("/api/auth/login", async (c) => {
  const parsed = LoginRequest.safeParse(await c.req.json().catch(() => null));

  if (!parsed.success) {
    return c.json({ error: "Dados de login inválidos", details: parsed.error.flatten() }, 400);
  }

  const { email, password, device } = parsed.data;
  const row = await c.env.DB.prepare(
    `SELECT id, password_hash, password_salt, active
     FROM users
     WHERE email = ?`,
  )
    .bind(email)
    .first<{ id: string; password_hash: string; password_salt: string; active: number }>();

  if (!row || row.active !== 1) {
    return c.json({ error: "Credenciais inválidas" }, 401);
  }

  const passwordHash = await hashPassword(password, row.password_salt);
  if (!constantTimeEqual(passwordHash, row.password_hash)) {
    return c.json({ error: "Credenciais inválidas" }, 401);
  }

  const user = await loadUserWithPreferences(c, row.id);
  const session = device
    ? await createDeviceSession(c, row.id, device)
    : { token: await signJwt(c, row.id) };

  return c.json({ success: true, ...session, user });
});

app.post("/api/auth/refresh", async (c) => {
  const parsed = RefreshSessionRequest.safeParse(await c.req.json().catch(() => null));

  if (!parsed.success) {
    return c.json({ error: "Pedido de renovação inválido" }, 400);
  }

  await ensureSecuritySchema(c);
  const refreshTokenHash = await hashOpaqueToken(parsed.data.refreshToken);
  const now = new Date();
  const row = await c.env.DB.prepare(
    `SELECT s.id AS session_id, s.user_id, s.device_id, s.expires_at,
            d.signing_public_jwk, d.signing_jkt, d.active AS device_active,
            u.active AS user_active
     FROM auth_sessions s
     JOIN user_devices d ON d.id = s.device_id
     JOIN users u ON u.id = s.user_id
     WHERE s.refresh_token_hash = ? AND s.revoked_at IS NULL
     LIMIT 1`,
  )
    .bind(refreshTokenHash)
    .first<{
      session_id: string;
      user_id: string;
      device_id: string;
      expires_at: string;
      signing_public_jwk: string;
      signing_jkt: string;
      device_active: number;
      user_active: number;
    }>();

  if (
    !row ||
    row.device_active !== 1 ||
    row.user_active !== 1 ||
    new Date(row.expires_at).getTime() <= now.getTime()
  ) {
    return c.json({ error: "Sessão de dispositivo inválida" }, 401);
  }

  const proof = c.req.header("DPoP") ?? "";
  if (!proof) {
    return c.json({ error: "Prova DPoP em falta" }, 401);
  }

  try {
    const verified = await verifyDpopProof({
      proof,
      method: c.req.method,
      url: dpopVerificationUrl(c),
      expectedJkt: row.signing_jkt,
      expectedPublicJwk: publicOnlyJwk(
        parseOkpJwk(JSON.parse(row.signing_public_jwk) as JsonWebKey, "Ed25519", false),
      ),
      maxAgeSeconds: Number(c.env.DPOP_MAX_AGE_SECONDS ?? "300"),
    });
    await registerDpopJti(c, verified.jkt, verified.jti);
  } catch (error) {
    return c.json({ error: errorMessage(error, "Prova DPoP inválida") }, 401);
  }

  const expiresAt = deviceSessionExpiresAt(c.env, now);
  const updatedAt = now.toISOString();
  await c.env.DB.batch([
    c.env.DB.prepare(
      `UPDATE auth_sessions
       SET updated_at = ?, last_used_at = ?, expires_at = ?
       WHERE id = ?`,
    ).bind(updatedAt, updatedAt, expiresAt, row.session_id),
    c.env.DB.prepare(
      `UPDATE user_devices
       SET updated_at = ?, last_seen_at = ?
       WHERE id = ?`,
    ).bind(updatedAt, updatedAt, row.device_id),
  ]);

  const token = await signJwt(c, row.user_id, {
    sessionId: row.session_id,
    deviceId: row.device_id,
    jkt: row.signing_jkt,
  });

  return c.json({
    success: true,
    token,
    accessToken: token,
    accessTokenExpiresAt: accessTokenExpiresAt(c.env),
    deviceId: row.device_id,
  });
});

app.post("/api/devices/enrol-session", requireAuth, async (c) => {
  const parsed = EnrolDeviceSessionRequest.safeParse(await c.req.json().catch(() => null));

  if (!parsed.success) {
    return c.json({ error: "Dados do dispositivo inválidos", details: parsed.error.flatten() }, 400);
  }

  const claims = c.get("auth");
  if (claims.did && claims.cnf?.jkt) {
    return c.json({ error: "A sessão já está associada a um dispositivo" }, 409);
  }

  if (c.env.ALLOW_LEGACY_DEVICE_ENROLLMENT === "false") {
    return c.json({ error: "Migração de sessão desativada" }, 403);
  }

  const user = c.get("user");
  const session = await createDeviceSession(c, user.id, parsed.data.device);

  return c.json({ success: true, ...session });
});

app.get("/api/devices", requireAuth, async (c) => {
  await ensureSecuritySchema(c);
  const user = c.get("user");
  const rows = await c.env.DB.prepare(
    `SELECT id, name, platform, app_version, active, created_at, last_seen_at, revoked_at
     FROM user_devices
     WHERE user_id = ?
     ORDER BY created_at DESC`,
  )
    .bind(user.id)
    .all();

  return c.json({ success: true, devices: rows.results ?? [] });
});

app.delete("/api/devices/:id", requireAuth, async (c) => {
  await ensureSecuritySchema(c);
  const user = c.get("user");
  const deviceId = c.req.param("id");
  const now = new Date().toISOString();
  const result = await c.env.DB.batch([
    c.env.DB.prepare(
      `UPDATE user_devices
       SET active = 0, revoked_at = ?, updated_at = ?
       WHERE id = ? AND user_id = ? AND active = 1`,
    ).bind(now, now, deviceId, user.id),
    c.env.DB.prepare(
      `UPDATE auth_sessions
       SET revoked_at = ?, updated_at = ?
       WHERE device_id = ? AND user_id = ? AND revoked_at IS NULL`,
    ).bind(now, now, deviceId, user.id),
  ]);

  const changed = Number((result[0]?.meta as { changes?: number } | undefined)?.changes ?? 0);
  if (changed === 0) {
    return c.json({ error: "Dispositivo não encontrado" }, 404);
  }

  return c.json({ success: true });
});

app.get("/api/security/sync-keys", (c) => {
  try {
    const signingKey = publicOnlyJwk(
      parseOkpJwk(c.env.SYNC_SERVER_SIGNING_PUBLIC_JWK, "Ed25519", false),
    );
    const agreementKey = publicOnlyJwk(
      parseOkpJwk(c.env.SYNC_SERVER_AGREEMENT_PUBLIC_JWK, "X25519", false),
    );

    return c.json({
      success: true,
      version: 1,
      signingKey: {
        ...signingKey,
        kid: c.env.SYNC_SERVER_SIGNING_KEY_ID ?? signingKey.kid ?? "sync-sign-v1",
      },
      agreementKey: {
        ...agreementKey,
        kid: c.env.SYNC_SERVER_AGREEMENT_KEY_ID ?? agreementKey.kid ?? "sync-enc-v1",
      },
    });
  } catch (error) {
    return c.json({ error: errorMessage(error, "Chaves de sincronização indisponíveis") }, 503);
  }
});

app.post("/api/auth/forgot-password", async (c) => {
  const parsed = ForgotPasswordRequest.safeParse(
    await c.req.json().catch(() => null),
  );

  if (!parsed.success) {
    return c.json(
      {
        error: "Pedido inválido",
        details: parsed.error.flatten(),
      },
      400,
    );
  }

  const genericMessage =
    "Se existir uma conta associada a este email, serão disponibilizadas instruções de recuperação.";

  const row = await c.env.DB.prepare(
    `SELECT id, name, email, active
     FROM users
     WHERE email = ?`,
  )
    .bind(parsed.data.email)
    .first<{ id: string; name: string; email: string; active: number }>();

  const isPasswordResetDebug = c.env.PASSWORD_RESET_DEBUG === "true";

  if (!row || row.active !== 1) {
    // Em produção, não revelamos se o email existe ou não.
    // Em modo protótipo/debug, damos feedback explícito para evitar avançar
    // para a tela seguinte sem código de recuperação.
    if (isPasswordResetDebug) {
      return c.json({
        success: true,
        debug: true,
        message:
          "Modo protótipo ativo, mas este email não corresponde a uma conta ativa neste ambiente. Cria uma conta primeiro ou usa o email de uma conta já registada nesta base de dados.",
        resetToken: null,
      });
    }

    return c.json({
      success: true,
      message: genericMessage,
    });
  }

  const now = new Date().toISOString();
  const expiresAt = new Date(Date.now() + 15 * 60 * 1000).toISOString();
  const resetToken = randomNumericCode(6);
  const tokenHash = await hashResetToken(resetToken);
  const id = crypto.randomUUID();

  await ensurePasswordResetSchema(c);

  await c.env.DB.batch([
    c.env.DB.prepare(
      `UPDATE password_reset_tokens
       SET used_at = ?
       WHERE user_id = ? AND used_at IS NULL`,
    ).bind(now, row.id),
    c.env.DB.prepare(
      `INSERT INTO password_reset_tokens (id, user_id, token_hash, expires_at, created_at)
       VALUES (?, ?, ?, ?, ?)`,
    ).bind(id, row.id, tokenHash, expiresAt, now),
  ]);

  // Modo protótipo/debug:
  // O Cloudflare Email Sending exige plano Workers Paid.
  // Por isso, neste modo, não tentamos enviar email.
  // Apenas devolvemos o código para a app demonstrar o fluxo.
  if (isPasswordResetDebug) {
    return c.json({
      success: true,
      debug: true,
      message:
        "Modo protótipo: o plano gratuito da Cloudflare não envia emails. Utiliza o código apresentado para redefinir a palavra-passe.",
      resetToken,
      expiresAt,
    });
  }

  if (!c.env.EMAIL) {
    console.error("Binding EMAIL não configurado.");
    return c.json(
      {
        error: "Envio de email não configurado.",
      },
      500,
    );
  }

  try {
    await sendPasswordResetEmail(c.env, {
      to: row.email,
      name: row.name,
      resetToken,
      expiresAt,
    });

    return c.json({
      success: true,
      message: genericMessage,
      emailSent: true,
      expiresAt,
    });
  } catch (error) {
    console.error("Erro ao enviar email de recuperacao", {
      name: error instanceof Error ? error.name : "UnknownError",
      message: error instanceof Error ? error.message : String(error),
      code:
        typeof error === "object" && error !== null && "code" in error
          ? String((error as { code?: unknown }).code)
          : null,
      stack: error instanceof Error ? error.stack : null,
    });

    return c.json(
      {
        error: "Não foi possível enviar o email de recuperação.",
      },
      500,
    );
  }
});

app.post("/api/auth/reset-password", async (c) => {
  const parsed = ResetPasswordRequest.safeParse(await c.req.json().catch(() => null));

  if (!parsed.success) {
    return c.json({ error: "Pedido inválido", details: parsed.error.flatten() }, 400);
  }

  const { email, token, newPassword } = parsed.data;
  const user = await c.env.DB.prepare(
    `SELECT id, active
     FROM users
     WHERE email = ?`,
  )
    .bind(email)
    .first<{ id: string; active: number }>();

  if (!user || user.active !== 1) {
    return c.json({ error: "Código inválido ou expirado" }, 400);
  }

  const now = new Date().toISOString();
  const tokenHash = await hashResetToken(token);

  await ensurePasswordResetSchema(c);

  const reset = await c.env.DB.prepare(
    `SELECT id
     FROM password_reset_tokens
     WHERE user_id = ?
       AND token_hash = ?
       AND used_at IS NULL
       AND expires_at > ?
     ORDER BY created_at DESC
     LIMIT 1`,
  )
    .bind(user.id, tokenHash, now)
    .first<{ id: string }>();

  if (!reset) {
    return c.json({ error: "Código inválido ou expirado" }, 400);
  }

  const salt = randomBase64Url(16);
  const passwordHash = await hashPassword(newPassword, salt);

  await ensureSecuritySchema(c);
  await c.env.DB.batch([
    c.env.DB.prepare(
      `UPDATE users
       SET password_hash = ?, password_salt = ?, updated_at = ?
       WHERE id = ?`,
    ).bind(passwordHash, salt, now, user.id),
    c.env.DB.prepare(
      `UPDATE password_reset_tokens
       SET used_at = ?
       WHERE user_id = ? AND used_at IS NULL`,
    ).bind(now, user.id),
    c.env.DB.prepare(
      `UPDATE auth_sessions
       SET revoked_at = ?, updated_at = ?
       WHERE user_id = ? AND revoked_at IS NULL`,
    ).bind(now, now, user.id),
  ]);

  return c.json({ success: true, message: "Palavra-passe alterada com sucesso" });
});

app.get("/api/me", requireAuth, async (c) => {
  const user = c.get("user");
  const detailedUser = await loadUserWithPreferences(c, user.id);

  return c.json({ success: true, user: detailedUser });
});

app.put("/api/me/preferences", requireAuth, async (c) => {
  const parsed = PreferencesRequest.safeParse(await c.req.json().catch(() => null));

  if (!parsed.success) {
    return c.json({ error: "Preferências inválidas", details: parsed.error.flatten() }, 400);
  }

  const user = c.get("user");
  const current = await loadUserWithPreferences(c, user.id);
  const now = new Date().toISOString();

  const appLanguageCode = parsed.data.appLanguageCode ?? current.preferences.appLanguageCode;
  const learningLanguageCode = parsed.data.learningLanguageCode ?? current.preferences.learningLanguageCode;
  const selectedProfile = parsed.data.selectedProfile ?? current.preferences.selectedProfile;
  const difficultyLevel = parsed.data.difficultyLevel ?? current.preferences.difficultyLevel;

  await c.env.DB.prepare(
    `INSERT INTO user_preferences (
       user_id, app_language_code, learning_language_code, selected_profile, difficulty_level, created_at, updated_at
     ) VALUES (?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(user_id) DO UPDATE SET
       app_language_code = excluded.app_language_code,
       learning_language_code = excluded.learning_language_code,
       selected_profile = excluded.selected_profile,
       difficulty_level = excluded.difficulty_level,
       updated_at = excluded.updated_at`,
  )
    .bind(user.id, appLanguageCode, learningLanguageCode, selectedProfile, difficultyLevel, now, now)
    .run();

  const updatedUser = await loadUserWithPreferences(c, user.id);

  return c.json({ success: true, user: updatedUser });
});

app.post("/api/activities/submissions", requireAuth, async (c) => {
  const parsed = SubmissionRequest.safeParse(await c.req.json().catch(() => null));

  if (!parsed.success) {
    return c.json({ error: "Submissão inválida", details: parsed.error.flatten() }, 400);
  }

  const user = c.get("user");
  const body = parsed.data;
  const submission = body.submission;
  const remoteActivityId = body.activityID ?? body.activityId ?? body.remoteActivityId;

  if (!remoteActivityId) {
    return c.json({ error: "activityID é obrigatório" }, 400);
  }

  const answers = Array.isArray(submission.answers) ? submission.answers : [];
  const answerText = answers.length > 0 && answers[0] && typeof answers[0] === "object"
    ? String((answers[0] as Record<string, unknown>).value ?? "")
    : "";

  const score = answerText.trim().length >= 20 ? 90 : 70;
  const feedback = score >= 80
    ? "Boa resposta. A comunicacao esta clara e adequada ao contexto."
    : "Resposta válida, mas pode ser melhorada com mais detalhe e vocabulário.";

  const metrics = {
    totalInteractions: 1,
    answerLength: answerText.length,
    evaluatedBy: "dailytalk-api",
  };

  const id = crypto.randomUUID();
  const now = new Date().toISOString();

  await c.env.DB.prepare(
    `INSERT INTO activity_submissions (
       id, user_id, remote_activity_id, activity_type, native_language_code, target_language_code,
       answer_text, score, feedback, metrics_json, submission_json, created_at, updated_at
     ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  )
    .bind(
      id,
      user.id,
      remoteActivityId,
      asOptionalString(submission.activityType),
      asOptionalString(submission.nativeLanguageCode),
      asOptionalString(submission.targetLanguageCode),
      answerText,
      score,
      feedback,
      JSON.stringify(metrics),
      JSON.stringify(submission),
      now,
      now,
    )
    .run();

  return c.json({
    success: true,
    submissionId: id,
    activityID: remoteActivityId,
    score,
    feedback,
    metrics,
  });
});

app.get("/api/activities/submissions/mine", requireAuth, async (c) => {
  const user = c.get("user");
  const rows = await c.env.DB.prepare(
    `SELECT id, remote_activity_id, activity_type, native_language_code, target_language_code,
            answer_text, score, feedback, metrics_json, created_at
     FROM activity_submissions
     WHERE user_id = ?
     ORDER BY created_at DESC
     LIMIT 50`,
  )
    .bind(user.id)
    .all();

  return c.json({ success: true, submissions: rows.results ?? [] });
});


app.post(
  "/api/sync/progress",
  requireAuth,
  requireBoundDevice,
  async (c) => {
    const envelopeRequest = SecureSyncEnvelopeRequest.safeParse(
      await c.req.json().catch(() => null),
    );

    if (!envelopeRequest.success) {
      return c.json({ error: "Envelope de sincronização inválido" }, 400);
    }

    await ensureSecuritySchema(c);
    const user = c.get("user");
    const claims = c.get("auth");
    const deviceId = claims.did!;
    const now = new Date();
    const nowIso = now.toISOString();

    const device = await c.env.DB.prepare(
      `SELECT id, signing_public_jwk, agreement_public_jwk, last_sequence, active
       FROM user_devices
       WHERE id = ? AND user_id = ?
       LIMIT 1`,
    )
      .bind(deviceId, user.id)
      .first<{
        id: string;
        signing_public_jwk: string;
        agreement_public_jwk: string;
        last_sequence: number;
        active: number;
      }>();

    if (!device || device.active !== 1) {
      return c.json({ error: "Dispositivo inválido ou revogado" }, 401);
    }

    try {
      const serverAgreementPrivate = parseOkpJwk(
        c.env.SYNC_SERVER_AGREEMENT_PRIVATE_JWK,
        "X25519",
        true,
      ) as OkpPrivateJwk;
      const serverSigningPrivate = parseOkpJwk(
        c.env.SYNC_SERVER_SIGNING_PRIVATE_JWK,
        "Ed25519",
        true,
      ) as OkpPrivateJwk;
      const deviceSigningPublic = publicOnlyJwk(
        parseOkpJwk(JSON.parse(device.signing_public_jwk) as JsonWebKey, "Ed25519", false),
      );
      const deviceAgreementPublic = publicOnlyJwk(
        parseOkpJwk(JSON.parse(device.agreement_public_jwk) as JsonWebKey, "X25519", false),
      );
      const serverAgreementKeyId =
        c.env.SYNC_SERVER_AGREEMENT_KEY_ID ?? "sync-enc-v1";
      const serverSigningKeyId =
        c.env.SYNC_SERVER_SIGNING_KEY_ID ?? "sync-sign-v1";

      const signedRequest = await decryptCompactJwe({
        compact: envelopeRequest.data.envelope,
        recipientPrivateJwk: serverAgreementPrivate,
        expectedRecipientKeyId: serverAgreementKeyId,
        expectedSenderParty: deviceId,
        expectedRecipientParty: serverAgreementKeyId,
        expectedType: "dailytalk-sync+jwe",
      });
      const requestPayload = await verifyCompactJws({
        compact: new TextDecoder().decode(signedRequest),
        publicJwk: deviceSigningPublic,
        expectedKeyId: deviceId,
        expectedType: "dailytalk-sync+jws",
      });
      const parsedBatch = SecureProgressBatch.safeParse(
        JSON.parse(new TextDecoder().decode(requestPayload)),
      );

      if (!parsedBatch.success) {
        return c.json(
          { error: "Lote de progresso inválido", details: parsedBatch.error.flatten() },
          400,
        );
      }

      const batch = parsedBatch.data;
      const issuedAt = new Date(batch.issuedAt).getTime();
      const expiresAt = new Date(batch.expiresAt).getTime();
      const maximumItems = Math.max(
        1,
        Math.min(100, Number(c.env.SYNC_MAX_BATCH_SIZE ?? "50")),
      );

      if (
        batch.deviceId !== deviceId ||
        batch.items.length > maximumItems ||
        issuedAt > now.getTime() + 60_000 ||
        issuedAt < now.getTime() - 10 * 60_000 ||
        expiresAt <= now.getTime() ||
        expiresAt - issuedAt > 10 * 60_000
      ) {
        return c.json({ error: "Contexto ou validade do lote inválidos" }, 400);
      }

      const requestHash = await sha256Base64Url(requestPayload);
      const existingBatch = await c.env.DB.prepare(
        `SELECT request_hash, response_envelope, status, sequence
         FROM secure_sync_batches
         WHERE user_id = ? AND device_id = ? AND batch_id = ?
         LIMIT 1`,
      )
        .bind(user.id, deviceId, batch.batchId)
        .first<{
          request_hash: string;
          response_envelope: string | null;
          status: string;
          sequence: number;
        }>();

      if (existingBatch) {
        if (
          existingBatch.request_hash !== requestHash ||
          existingBatch.sequence !== batch.sequence
        ) {
          return c.json({ error: "batchId reutilizado com conteúdo diferente" }, 409);
        }

        if (existingBatch.response_envelope) {
          return c.json({ success: true, envelope: existingBatch.response_envelope });
        }
      } else {
        if (batch.sequence <= Number(device.last_sequence ?? 0)) {
          return c.json({ error: "Sequência de sincronização repetida" }, 409);
        }

        const inserted = await c.env.DB.prepare(
          `INSERT OR IGNORE INTO secure_sync_batches (
             id, user_id, device_id, batch_id, sequence, request_hash,
             response_envelope, status, created_at, completed_at
           ) VALUES (?, ?, ?, ?, ?, ?, NULL, 'processing', ?, NULL)`,
        )
          .bind(
            crypto.randomUUID(),
            user.id,
            deviceId,
            batch.batchId,
            batch.sequence,
            requestHash,
            nowIso,
          )
          .run();

        if (Number(inserted.meta?.changes ?? 0) === 0) {
          return c.json({ error: "Lote ou sequência já em processamento" }, 409);
        }
      }

      const itemStatements: D1PreparedStatement[] = [];
      const preparedItems: Array<{
        localId: string;
        serverId: string;
        remoteActivityId: string;
        score: number;
        feedback: string;
        metrics: Record<string, unknown>;
      }> = [];

      for (const item of batch.items) {
        const evaluation = evaluateSubmission(item.submission);
        const serverId = await deterministicSubmissionId(user.id, item.clientSubmissionId);
        const createdAt = new Date(item.createdAt).toISOString();

        preparedItems.push({
          localId: item.clientSubmissionId,
          serverId,
          remoteActivityId: item.remoteActivityId,
          ...evaluation,
        });
        itemStatements.push(
          c.env.DB.prepare(
            `INSERT OR IGNORE INTO activity_submissions (
               id, user_id, remote_activity_id, activity_type, native_language_code,
               target_language_code, answer_text, score, feedback, metrics_json,
               submission_json, created_at, updated_at
             ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          ).bind(
            serverId,
            user.id,
            item.remoteActivityId,
            asOptionalString(item.submission.activityType),
            asOptionalString(item.submission.nativeLanguageCode),
            asOptionalString(item.submission.targetLanguageCode),
            evaluation.answerText,
            evaluation.score,
            evaluation.feedback,
            JSON.stringify(evaluation.metrics),
            JSON.stringify(item.submission),
            createdAt,
            nowIso,
          ),
          c.env.DB.prepare(
            `INSERT OR IGNORE INTO secure_submission_receipts (
               submission_id, user_id, device_id, client_submission_id, batch_id, created_at
             ) VALUES (?, ?, ?, ?, ?, ?)`,
          ).bind(
            serverId,
            user.id,
            deviceId,
            item.clientSubmissionId,
            batch.batchId,
            nowIso,
          ),
        );
      }

      const itemResults = itemStatements.length > 0
        ? await c.env.DB.batch(itemStatements)
        : [];
      const results = preparedItems.map((item, index) => {
        const insertionResult = itemResults[index * 2];
        const inserted = Number(insertionResult?.meta?.changes ?? 0) > 0;

        return {
          clientSubmissionId: item.localId,
          submissionId: item.serverId,
          status: inserted ? "accepted" : "duplicate",
          remoteActivityId: item.remoteActivityId,
          score: item.score,
          feedback: item.feedback,
          metrics: item.metrics,
        };
      });
      const responsePayload = utf8(JSON.stringify({
        version: 1,
        batchId: batch.batchId,
        deviceId,
        sequence: batch.sequence,
        processedAt: new Date().toISOString(),
        results,
      }));
      const signedResponse = await signCompactJws({
        payload: responsePayload,
        privateJwk: serverSigningPrivate,
        keyId: serverSigningKeyId,
        type: "dailytalk-sync-response+jws",
      });
      const responseEnvelope = await encryptCompactJwe({
        plaintext: utf8(signedResponse),
        recipientPublicJwk: deviceAgreementPublic,
        recipientKeyId: deviceId,
        senderParty: serverAgreementKeyId,
        recipientParty: deviceId,
        type: "dailytalk-sync-response+jwe",
      });
      const completedAt = new Date().toISOString();

      await c.env.DB.batch([
        c.env.DB.prepare(
          `UPDATE user_devices
           SET last_sequence = CASE WHEN last_sequence < ? THEN ? ELSE last_sequence END,
               last_seen_at = ?, updated_at = ?
           WHERE id = ? AND user_id = ?`,
        ).bind(batch.sequence, batch.sequence, completedAt, completedAt, deviceId, user.id),
        c.env.DB.prepare(
          `UPDATE secure_sync_batches
           SET response_envelope = ?, status = 'completed', completed_at = ?
           WHERE user_id = ? AND device_id = ? AND batch_id = ? AND request_hash = ?`,
        ).bind(
          responseEnvelope,
          completedAt,
          user.id,
          deviceId,
          batch.batchId,
          requestHash,
        ),
      ]);

      return c.json({ success: true, envelope: responseEnvelope });
    } catch (error) {
      console.error("Falha na sincronização segura", {
        userId: user.id,
        deviceId,
        message: error instanceof Error ? error.message : String(error),
      });
      return c.json({ error: "Pedido de sincronização segura inválido" }, 400);
    }
  },
);


async function ensurePasswordResetSchema(c: AppContext) {
  await c.env.DB.batch([
    c.env.DB.prepare(
      `CREATE TABLE IF NOT EXISTS password_reset_tokens (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        token_hash TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        used_at TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )`,
    ),
    c.env.DB.prepare(
      `CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_user_id
       ON password_reset_tokens(user_id)`,
    ),
    c.env.DB.prepare(
      `CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_token_hash
       ON password_reset_tokens(token_hash)`,
    ),
  ]);
}

async function requireAuth(c: AppContext, next: Next) {
  const header = c.req.header("Authorization") ?? "";
  const [scheme, value] = header.split(" ", 2);
  const token = value && (scheme === "Bearer" || scheme === "DPoP")
    ? value
    : scheme && !value
      ? scheme
      : "";

  if (!token) {
    return c.json({ error: "Token em falta" }, 401);
  }

  try {
    const payload = await verifyJwt(c, token);

    if (payload.did || payload.cnf?.jkt || payload.sid) {
      if (!payload.did || !payload.cnf?.jkt || !payload.sid || scheme !== "DPoP") {
        return c.json({ error: "Sessão vinculada exige autenticação DPoP" }, 401);
      }

      await ensureSecuritySchema(c);
      const device = await c.env.DB.prepare(
        `SELECT d.signing_public_jwk, d.signing_jkt, d.active AS device_active,
                s.revoked_at, s.expires_at
         FROM user_devices d
         JOIN auth_sessions s ON s.device_id = d.id
         WHERE d.id = ? AND d.user_id = ? AND s.id = ? AND s.user_id = ?
         LIMIT 1`,
      )
        .bind(payload.did, payload.sub, payload.sid, payload.sub)
        .first<{
          signing_public_jwk: string;
          signing_jkt: string;
          device_active: number;
          revoked_at: string | null;
          expires_at: string;
        }>();

      if (
        !device ||
        device.device_active !== 1 ||
        device.revoked_at ||
        new Date(device.expires_at).getTime() <= Date.now() ||
        device.signing_jkt !== payload.cnf.jkt
      ) {
        return c.json({ error: "Sessão de dispositivo inválida" }, 401);
      }

      const proof = c.req.header("DPoP") ?? "";
      const verified = await verifyDpopProof({
        proof,
        method: c.req.method,
        url: dpopVerificationUrl(c),
        expectedJkt: payload.cnf.jkt,
        expectedPublicJwk: publicOnlyJwk(
          parseOkpJwk(
            JSON.parse(device.signing_public_jwk) as JsonWebKey,
            "Ed25519",
            false,
          ),
        ),
        accessToken: token,
        maxAgeSeconds: Number(c.env.DPOP_MAX_AGE_SECONDS ?? "300"),
      });
      await registerDpopJti(c, verified.jkt, verified.jti);
    } else if (scheme !== "Bearer") {
      return c.json({ error: "Sessão antiga exige Bearer" }, 401);
    }

    const row = await c.env.DB.prepare(
      `SELECT id, name, email, role
       FROM users
       WHERE id = ? AND active = 1`,
    )
      .bind(payload.sub)
      .first<AuthenticatedUser>();

    if (!row) {
      return c.json({ error: "Utilizador inválido" }, 401);
    }

    c.set("auth", payload);
    c.set("user", row);
    await next();
  } catch (error) {
    console.warn("Autenticação rejeitada", {
      message: error instanceof Error ? error.message : String(error),
    });
    return c.json({ error: "Não autorizado" }, 401);
  }
}

async function requireBoundDevice(c: AppContext, next: Next) {
  const claims = c.get("auth");

  if (!claims.did || !claims.sid || !claims.cnf?.jkt) {
    return c.json({ error: "Este endpoint exige um dispositivo registado" }, 401);
  }

  await next();
}


async function loadUserWithPreferences(c: AppContext, userId: string) {
  const row = await c.env.DB.prepare(
    `SELECT u.id, u.name, u.email, u.role,
            COALESCE(p.app_language_code, 'pt-PT') AS app_language_code,
            COALESCE(p.learning_language_code, 'it-IT') AS learning_language_code,
            COALESCE(p.selected_profile, u.role) AS selected_profile,
            COALESCE(p.difficulty_level, 'beginner') AS difficulty_level
     FROM users u
     LEFT JOIN user_preferences p ON p.user_id = u.id
     WHERE u.id = ? AND u.active = 1`,
  )
    .bind(userId)
    .first<{
      id: string;
      name: string;
      email: string;
      role: "student" | "host" | "teacher";
      app_language_code: string;
      learning_language_code: string;
      selected_profile: "student" | "host" | "teacher";
      difficulty_level: string;
    }>();

  if (!row) {
    throw new Error("Utilizador não encontrado");
  }

  return {
    id: row.id,
    name: row.name,
    email: row.email,
    role: row.role,
    preferences: {
      appLanguageCode: row.app_language_code,
      learningLanguageCode: row.learning_language_code,
      selectedProfile: row.selected_profile,
      difficultyLevel: row.difficulty_level,
    },
  };
}

async function hashPassword(password: string, salt: string) {
  const key = await crypto.subtle.importKey(
    "raw",
    textEncoder.encode(password),
    "PBKDF2",
    false,
    ["deriveBits"],
  );

  const bits = await crypto.subtle.deriveBits(
    {
      name: "PBKDF2",
      salt: textEncoder.encode(salt),
      iterations: 100000,
      hash: "SHA-256",
    },
    key,
    256,
  );

  return base64Url(new Uint8Array(bits));
}

async function sendPasswordResetEmail(
  env: Bindings,
  input: { to: string; name: string; resetToken: string; expiresAt: string },
) {
  if (!env.EMAIL) {
    throw new Error("Binding EMAIL nao configurado");
  }

  const fromEmail = env.PASSWORD_RESET_FROM_EMAIL || "no-reply@dailytalk.pt";

  const text = [
    `Ola ${input.name || ""},`.trim(),
    "",
    "Recebemos um pedido para recuperar a palavra-passe da tua conta DailyTalk.pt.",
    "",
    `Codigo de recuperacao: ${input.resetToken}`,
    "",
    "Este codigo expira em 15 minutos.",
    "",
    "Se nao foste tu a pedir esta recuperacao, podes ignorar este email.",
    "",
    "DailyTalk.pt",
  ].join("\n");

  const result = await env.EMAIL.send({
    to: input.to,
    from: fromEmail,
    subject: "Codigo de recuperacao DailyTalk.pt",
    text,
  });

  console.log("Email de recuperacao enviado", result);

  return result;
}

function randomNumericCode(length: number) {
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  let code = "";

  for (const byte of bytes) {
    code += String(byte % 10);
  }

  return code;
}

function escapeHtml(value: string) {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

async function hashResetToken(token: string) {
  const digest = await crypto.subtle.digest("SHA-256", textEncoder.encode(token));
  return base64Url(new Uint8Array(digest));
}

async function signJwt(
  c: AppContext,
  userId: string,
  binding?: { sessionId: string; deviceId: string; jkt: string },
) {
  const now = Math.floor(Date.now() / 1000);
  const expiresIn = Number(c.env.JWT_EXPIRES_SECONDS ?? "900");
  const header = { alg: "HS256", typ: "JWT" };
  const payload: AccessTokenClaims = {
    sub: userId,
    iat: now,
    exp: now + expiresIn,
    iss: "dailytalk-api",
    aud: "dailytalk-api",
    env: requestEnvironment(c),
    ...(binding
      ? {
          sid: binding.sessionId,
          did: binding.deviceId,
          cnf: { jkt: binding.jkt },
        }
      : {}),
  };
  const unsigned = `${base64UrlJson(header)}.${base64UrlJson(payload)}`;
  const signature = await hmacSha256(unsigned, c.env.JWT_SECRET);

  return `${unsigned}.${signature}`;
}

async function verifyJwt(c: AppContext, token: string): Promise<AccessTokenClaims> {
  const parts = token.split(".");
  if (parts.length !== 3) {
    throw new Error("Token inválido");
  }

  const encodedHeader = parts[0];
  const encodedPayload = parts[1];
  const signature = parts[2];
  if (!encodedHeader || !encodedPayload || !signature) {
    throw new Error("Token inválido");
  }
  const expected = await hmacSha256(`${encodedHeader}.${encodedPayload}`, c.env.JWT_SECRET);

  if (!constantTimeEqual(signature, expected)) {
    throw new Error("Assinatura inválida");
  }

  const header = JSON.parse(textDecoder.decode(base64UrlDecode(encodedHeader))) as {
    alg?: string;
    typ?: string;
  };
  if (header.alg !== "HS256" || header.typ !== "JWT") {
    throw new Error("Algoritmo inválido");
  }

  const payload = JSON.parse(
    textDecoder.decode(base64UrlDecode(encodedPayload)),
  ) as Partial<AccessTokenClaims>;
  const now = Math.floor(Date.now() / 1000);

  if (
    !payload.sub ||
    !payload.iat ||
    !payload.exp ||
    payload.exp < now ||
    payload.iat > now + 60 ||
    payload.iss !== "dailytalk-api" ||
    payload.aud !== "dailytalk-api" ||
    payload.env !== requestEnvironment(c)
  ) {
    throw new Error("Token expirado ou inválido");
  }

  if (
    (payload.sid || payload.did || payload.cnf) &&
    (!payload.sid || !payload.did || !payload.cnf?.jkt)
  ) {
    throw new Error("Vinculação do token incompleta");
  }

  return payload as AccessTokenClaims;
}


async function hmacSha256(data: string, secret: string) {
  if (textEncoder.encode(secret).length < 32) {
    throw new Error("JWT_SECRET deve possuir pelo menos 32 bytes");
  }

  const key = await crypto.subtle.importKey(
    "raw",
    textEncoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign("HMAC", key, textEncoder.encode(data));
  return base64Url(new Uint8Array(signature));
}

function base64UrlJson(value: unknown) {
  return base64Url(textEncoder.encode(JSON.stringify(value)));
}

function base64Url(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function base64UrlDecode(value: string) {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(value.length / 4) * 4, "=");
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);

  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }

  return bytes;
}

function randomBase64Url(length: number) {
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  return base64Url(bytes);
}

function constantTimeEqual(a: string, b: string) {
  if (a.length !== b.length) {
    return false;
  }

  let result = 0;
  for (let index = 0; index < a.length; index += 1) {
    result |= a.charCodeAt(index) ^ b.charCodeAt(index);
  }

  return result === 0;
}

function asOptionalString(value: unknown) {
  if (value === undefined || value === null) {
    return null;
  }

  return String(value);
}


async function createDeviceSession(
  c: AppContext,
  userId: string,
  deviceInput: {
    installationId: string;
    name?: string;
    platform?: string;
    appVersion?: string;
    signingPublicJwk: JsonWebKey;
    agreementPublicJwk: JsonWebKey;
  },
) {
  await ensureSecuritySchema(c);
  const signingPublicJwk = publicOnlyJwk(
    parseOkpJwk(deviceInput.signingPublicJwk, "Ed25519", false),
  );
  const agreementPublicJwk = publicOnlyJwk(
    parseOkpJwk(deviceInput.agreementPublicJwk, "X25519", false),
  );
  const signingJkt = await okpJwkThumbprint(signingPublicJwk);
  const now = new Date();
  const nowIso = now.toISOString();
  const existing = await c.env.DB.prepare(
    `SELECT id FROM user_devices
     WHERE user_id = ? AND installation_id = ?
     LIMIT 1`,
  )
    .bind(userId, deviceInput.installationId)
    .first<{ id: string }>();
  const deviceId = existing?.id ?? crypto.randomUUID();
  const sessionId = crypto.randomUUID();
  const refreshToken = securityRandomBase64Url(48);
  const refreshTokenHash = await hashOpaqueToken(refreshToken);
  const expiresAt = deviceSessionExpiresAt(c.env, now);

  await c.env.DB.batch([
    c.env.DB.prepare(
      `INSERT INTO user_devices (
         id, user_id, installation_id, name, platform, app_version,
         signing_public_jwk, agreement_public_jwk, signing_jkt, active,
         last_sequence, created_at, updated_at, last_seen_at, revoked_at
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 0, ?, ?, ?, NULL)
       ON CONFLICT(user_id, installation_id) DO UPDATE SET
         name = excluded.name,
         platform = excluded.platform,
         app_version = excluded.app_version,
         signing_public_jwk = excluded.signing_public_jwk,
         agreement_public_jwk = excluded.agreement_public_jwk,
         signing_jkt = excluded.signing_jkt,
         active = 1,
         last_sequence = CASE
           WHEN user_devices.signing_jkt = excluded.signing_jkt
             THEN user_devices.last_sequence
           ELSE 0
         END,
         updated_at = excluded.updated_at,
         last_seen_at = excluded.last_seen_at,
         revoked_at = NULL`,
    ).bind(
      deviceId,
      userId,
      deviceInput.installationId,
      deviceInput.name ?? null,
      deviceInput.platform ?? null,
      deviceInput.appVersion ?? null,
      JSON.stringify(signingPublicJwk),
      JSON.stringify(agreementPublicJwk),
      signingJkt,
      nowIso,
      nowIso,
      nowIso,
    ),
    c.env.DB.prepare(
      `UPDATE auth_sessions
       SET revoked_at = ?, updated_at = ?
       WHERE user_id = ? AND device_id = ? AND revoked_at IS NULL`,
    ).bind(nowIso, nowIso, userId, deviceId),
    c.env.DB.prepare(
      `INSERT INTO auth_sessions (
         id, user_id, device_id, refresh_token_hash, created_at, updated_at,
         last_used_at, expires_at, revoked_at
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL)`,
    ).bind(
      sessionId,
      userId,
      deviceId,
      refreshTokenHash,
      nowIso,
      nowIso,
      nowIso,
      expiresAt,
    ),
  ]);

  const token = await signJwt(c, userId, {
    sessionId,
    deviceId,
    jkt: signingJkt,
  });

  return {
    token,
    accessToken: token,
    refreshToken,
    accessTokenExpiresAt: accessTokenExpiresAt(c.env),
    deviceId,
  };
}

function accessTokenExpiresAt(env: Bindings): string {
  const seconds = Number(env.JWT_EXPIRES_SECONDS ?? "900");
  return new Date(Date.now() + seconds * 1000).toISOString();
}

function deviceSessionExpiresAt(env: Bindings, from = new Date()): string {
  const days = Number(env.DEVICE_SESSION_EXPIRES_DAYS ?? "730");
  return new Date(from.getTime() + days * 24 * 60 * 60 * 1000).toISOString();
}

async function hashOpaqueToken(token: string): Promise<string> {
  return sha256Base64Url(utf8(token));
}

async function registerDpopJti(
  c: AppContext,
  jkt: string,
  jti: string,
): Promise<void> {
  await ensureSecuritySchema(c);
  const now = new Date();
  const expiresAt = new Date(
    now.getTime() + Number(c.env.DPOP_MAX_AGE_SECONDS ?? "300") * 1000 + 60_000,
  ).toISOString();

  const result = await c.env.DB.prepare(
    `INSERT OR IGNORE INTO dpop_replay (jkt, jti, expires_at, created_at)
     VALUES (?, ?, ?, ?)`,
  )
    .bind(jkt, jti, expiresAt, now.toISOString())
    .run();

  if (Number(result.meta?.changes ?? 0) === 0) {
    throw new Error("Prova DPoP repetida");
  }

  // Limpeza probabilística fora do caminho crítico. Os jti são aleatórios e
  // expiram rapidamente; não é necessário bloquear cada pedido com DELETE.
  const sample = new Uint8Array(1);
  crypto.getRandomValues(sample);
  if ((sample[0] ?? 255) < 4) {
    c.executionCtx.waitUntil(
      c.env.DB.prepare("DELETE FROM dpop_replay WHERE expires_at <= ?")
        .bind(now.toISOString())
        .run()
        .then(() => undefined)
        .catch((error) => {
          console.warn("Limpeza DPoP adiada", {
            message: error instanceof Error ? error.message : String(error),
          });
        }),
    );
  }
}

function evaluateSubmission(submission: Record<string, unknown>) {
  const answers = Array.isArray(submission.answers) ? submission.answers : [];
  const first = answers.length > 0 && answers[0] && typeof answers[0] === "object"
    ? answers[0] as Record<string, unknown>
    : null;
  const answerText = first ? String(first.value ?? "") : "";
  const score = answerText.trim().length >= 20 ? 90 : 70;
  const feedback = score >= 80
    ? "Boa resposta. A comunicacao esta clara e adequada ao contexto."
    : "Resposta válida, mas pode ser melhorada com mais detalhe e vocabulário.";
  const metrics: Record<string, unknown> = {
    totalInteractions: 1,
    answerLength: answerText.length,
    evaluatedBy: "dailytalk-api-secure-sync",
  };

  return { answerText, score, feedback, metrics };
}

async function deterministicSubmissionId(
  userId: string,
  clientSubmissionId: string,
): Promise<string> {
  return sha256Base64Url(
    utf8(`dailytalk-submission:v1:${userId}:${clientSubmissionId}`),
  );
}

function errorMessage(error: unknown, fallback: string): string {
  if (error instanceof Error && error.message.trim()) {
    return error.message;
  }

  return fallback;
}

export default app;
