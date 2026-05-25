import { Hono, type Next } from "hono";
import { cors } from "hono/cors";
import {
  ForgotPasswordRequest,
  LoginRequest,
  PreferencesRequest,
  RegisterRequest,
  ResetPasswordRequest,
  SubmissionRequest,
  type AuthenticatedUser,
  type Bindings,
  type Variables,
  type AppContext,
} from "./types";

const app = new Hono<{ Bindings: Bindings; Variables: Variables }>();
const textEncoder = new TextEncoder();
const textDecoder = new TextDecoder();

app.use(
  "*",
  cors({
    origin: (origin, c) => c.env.CORS_ORIGIN || origin || "*",
    allowHeaders: ["Content-Type", "Authorization"],
    allowMethods: ["GET", "POST", "PUT", "OPTIONS"],
  }),
);

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
      "POST /api/auth/forgot-password",
      "POST /api/auth/reset-password",
      "GET /api/me",
      "PUT /api/me/preferences",
      "POST /api/activities/submissions",
      "GET /api/activities/submissions/mine",
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

  return c.text(`https://dailytalk.pt/activity/${type}/${activityId}`);
});

app.post("/api/auth/register", async (c) => {
  const parsed = RegisterRequest.safeParse(await c.req.json().catch(() => null));

  if (!parsed.success) {
    return c.json({ error: "Dados de registo inválidos", details: parsed.error.flatten() }, 400);
  }

  const { name, email, password, role } = parsed.data;
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
  const token = await signJwt(c.env, id);

  return c.json({ success: true, token, user }, 201);
});

app.post("/api/auth/login", async (c) => {
  const parsed = LoginRequest.safeParse(await c.req.json().catch(() => null));

  if (!parsed.success) {
    return c.json({ error: "Dados de login inválidos", details: parsed.error.flatten() }, 400);
  }

  const { email, password } = parsed.data;
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
  const token = await signJwt(c.env, row.id);

  return c.json({ success: true, token, user });
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
    "Se existir uma conta associada a este email, enviaremos instruções de recuperação.";

  const row = await c.env.DB.prepare(
    `SELECT id, name, email, active
     FROM users
     WHERE email = ?`,
  )
    .bind(parsed.data.email)
    .first<{ id: string; name: string; email: string; active: number }>();

  if (!row || row.active !== 1) {
    // Não revelamos se o email existe ou não.
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
  if (c.env.PASSWORD_RESET_DEBUG === "true") {
    return c.json({
      success: true,
      debug: true,
      message:
        "Modo protótipo/debug: utiliza o código apresentado para redefinir a palavra-passe.",
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

async function requireAuth(c: AppContext, next: Next) {
  const header = c.req.header("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.substring(7) : header;

  if (!token) {
    return c.json({ error: "Token em falta" }, 401);
  }

  try {
    const payload = await verifyJwt(c.env, token);
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

    c.set("user", row);
    await next();
  } catch {
    return c.json({ error: "Não autorizado" }, 401);
  }
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

async function signJwt(env: Bindings, userId: string) {
  const now = Math.floor(Date.now() / 1000);
  const expiresIn = Number(env.JWT_EXPIRES_SECONDS ?? "7200");
  const header = { alg: "HS256", typ: "JWT" };
  const payload = { sub: userId, iat: now, exp: now + expiresIn, iss: "dailytalk-api" };
  const unsigned = `${base64UrlJson(header)}.${base64UrlJson(payload)}`;
  const signature = await hmacSha256(unsigned, env.JWT_SECRET);

  return `${unsigned}.${signature}`;
}

async function verifyJwt(env: Bindings, token: string) {
  const parts = token.split(".");
  if (parts.length !== 3) {
    throw new Error("Token inválido");
  }

  const [encodedHeader, encodedPayload, signature] = parts;
  const expected = await hmacSha256(`${encodedHeader}.${encodedPayload}`, env.JWT_SECRET);

  if (!constantTimeEqual(signature, expected)) {
    throw new Error("Assinatura inválida");
  }

  const header = JSON.parse(textDecoder.decode(base64UrlDecode(encodedHeader))) as { alg?: string };
  if (header.alg !== "HS256") {
    throw new Error("Algoritmo inválido");
  }

  const payload = JSON.parse(textDecoder.decode(base64UrlDecode(encodedPayload))) as { sub?: string; exp?: number };
  if (!payload.sub || !payload.exp || payload.exp < Math.floor(Date.now() / 1000)) {
    throw new Error("Token expirado");
  }

  return payload as { sub: string; exp: number };
}

async function hmacSha256(data: string, secret: string) {
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

export default app;
