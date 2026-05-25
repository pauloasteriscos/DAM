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
  EMAIL?: SendEmailBinding;
  JWT_SECRET: string;
  JWT_EXPIRES_SECONDS?: string;
  CORS_ORIGIN?: string;
  PASSWORD_RESET_DEBUG?: string;
  PASSWORD_RESET_FROM_EMAIL?: string;
  PASSWORD_RESET_FROM_NAME?: string;
};

export type AuthenticatedUser = {
  id: string;
  name: string;
  email: string;
  role: "student" | "host" | "teacher";
};

export type Variables = {
  user: AuthenticatedUser;
};

export type AppContext = Context<{ Bindings: Bindings; Variables: Variables }>;

export const UserRole = z.enum(["student", "host", "teacher"]);

export const RegisterRequest = z.object({
  name: z.string().trim().min(2),
  email: z.email().transform((value) => value.trim().toLowerCase()),
  password: z.string().min(6),
  role: UserRole.default("student"),
});

export const LoginRequest = z.object({
  email: z.email().transform((value) => value.trim().toLowerCase()),
  password: z.string().min(1),
});

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
