import type { Context } from "hono";
import { z } from "zod";

type EmailAddress = string | { email: string; name?: string };

type EmailMessage = {
  to: string | string[];
  from: EmailAddress;
  subject: string;
  html?: string;
  text?: string;
  replyTo?: EmailAddress;
};

type EmailSendResult = {
  messageId: string;
};

export type SendEmailBinding = {
  send(message: EmailMessage): Promise<EmailSendResult>;
};

export type Bindings = {
  DB: D1Database;
  APP_ENV: "DEV" | "PRD";
  EMAIL?: SendEmailBinding;
  JWT_SECRET: string;
  JWT_EXPIRES_SECONDS?: string;
  DEVICE_SESSION_EXPIRES_DAYS?: string;
  DPOP_MAX_AGE_SECONDS?: string;
  AUTO_CREATE_SECURITY_SCHEMA?: string;
  CORS_ORIGIN?: string;
  PASSWORD_RESET_DEBUG?: string;
  PASSWORD_RESET_FROM_EMAIL?: string;
  PASSWORD_RESET_FROM_NAME?: string;
  ALLOW_LEGACY_DEVICE_ENROLLMENT?: string;
  SYNC_MAX_BATCH_SIZE?: string;
  SYNC_SERVER_SIGNING_PRIVATE_JWK?: string;
  SYNC_SERVER_SIGNING_PUBLIC_JWK?: string;
  SYNC_SERVER_AGREEMENT_PRIVATE_JWK?: string;
  SYNC_SERVER_AGREEMENT_PUBLIC_JWK?: string;
  SYNC_SERVER_SIGNING_KEY_ID?: string;
  SYNC_SERVER_AGREEMENT_KEY_ID?: string;
};

export type AuthenticatedUser = {
  id: string;
  name: string;
  email: string;
  role: "student" | "host" | "teacher";
};

export type AccessTokenClaims = {
  sub: string;
  iat: number;
  exp: number;
  iss: "dailytalk-api";
  aud: "dailytalk-api";
  env: "DEV" | "PRD";
  sid?: string;
  did?: string;
  cnf?: {
    jkt: string;
  };
};

export type Variables = {
  user: AuthenticatedUser;
  auth: AccessTokenClaims;
};

export type AppContext = Context<{ Bindings: Bindings; Variables: Variables }>;

export const UserRole = z.enum(["student", "host", "teacher"]);

const Ed25519PublicJwk = z.object({
  kty: z.literal("OKP"),
  crv: z.literal("Ed25519"),
  x: z.string().min(40).max(60),
  kid: z.string().trim().min(1).max(200).optional(),
}).strict();

const X25519PublicJwk = z.object({
  kty: z.literal("OKP"),
  crv: z.literal("X25519"),
  x: z.string().min(40).max(60),
  kid: z.string().trim().min(1).max(200).optional(),
}).strict();

export const DeviceRegistrationRequest = z.object({
  installationId: z.string().trim().min(16).max(200),
  name: z.string().trim().min(1).max(100).optional(),
  platform: z.string().trim().min(1).max(40).optional(),
  appVersion: z.string().trim().min(1).max(40).optional(),
  signingPublicJwk: Ed25519PublicJwk,
  agreementPublicJwk: X25519PublicJwk,
}).strict();

export const RegisterRequest = z.object({
  name: z.string().trim().min(2),
  email: z.email().transform((value) => value.trim().toLowerCase()),
  password: z.string().min(6),
  role: UserRole.default("student"),
  device: DeviceRegistrationRequest.optional(),
});

export const LoginRequest = z.object({
  email: z.email().transform((value) => value.trim().toLowerCase()),
  password: z.string().min(1),
  device: DeviceRegistrationRequest.optional(),
});

export const RefreshSessionRequest = z.object({
  refreshToken: z.string().min(32).max(512),
}).strict();

export const EnrolDeviceSessionRequest = z.object({
  device: DeviceRegistrationRequest,
}).strict();

export const ForgotPasswordRequest = z.object({
  email: z.email().transform((value) => value.trim().toLowerCase()),
});

export const ResetPasswordRequest = z.object({
  email: z.email().transform((value) => value.trim().toLowerCase()),
  token: z.string().trim().min(6),
  newPassword: z.string().min(6),
});

export const PreferencesRequest = z.object({
  appLanguageCode: z.string().trim().min(2).optional(),
  learningLanguageCode: z.string().trim().min(2).optional(),
  selectedProfile: UserRole.optional(),
  difficultyLevel: z.string().trim().optional(),
});

export const SubmissionRequest = z.object({
  activityID: z.string().trim().min(1).optional(),
  activityId: z.string().trim().min(1).optional(),
  remoteActivityId: z.string().trim().min(1).optional(),
  submission: z.record(z.string(), z.unknown()),
});

export const SecureSyncEnvelopeRequest = z.object({
  envelope: z.string().min(20).max(512 * 1024),
}).strict();

export const SecureProgressItem = z.object({
  clientSubmissionId: z.string().trim().min(16).max(200),
  remoteActivityId: z.string().trim().min(1).max(300),
  createdAt: z.string().datetime({ offset: true }).or(z.string().datetime()),
  submission: z.record(z.string(), z.unknown()),
}).strict();

export const SecureProgressBatch = z.object({
  version: z.literal(1),
  batchId: z.string().trim().min(16).max(200),
  deviceId: z.string().uuid(),
  issuedAt: z.string().datetime({ offset: true }).or(z.string().datetime()),
  expiresAt: z.string().datetime({ offset: true }).or(z.string().datetime()),
  sequence: z.number().int().positive(),
  items: z.array(SecureProgressItem).min(1).max(100),
}).strict();
