import dotenv from "dotenv";
import { z } from "zod";

dotenv.config({ path: ".env.local" });

const booleanFromEnv = z.preprocess((value) => {
  if (typeof value === "boolean") {
    return value;
  }

  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    if (["true", "1", "yes", "y", "on"].includes(normalized)) {
      return true;
    }
    if (["false", "0", "no", "n", "off"].includes(normalized)) {
      return false;
    }
  }

  return value;
}, z.boolean());

const envSchema = z.object({
  NODE_ENV: z.enum(["development", "production", "test"]).default("development"),
  HOST: z.string().default("0.0.0.0"),
  PORT: z.coerce.number().default(3000),
  /** Comma-separated allowed browser origins (admin React). Empty = permissive in dev. */
  CORS_ORIGINS: z.string().optional(),
  /** Public HTTPS API root shown in logs/docs, e.g. https://api.example.com */
  PUBLIC_API_URL: z.string().optional(),
  /**
   * Long-running socket host (Railway/Render/VPS) for Vercel REST → socket bridge.
   * Example: https://taxi-socket.railway.app
   */
  SOCKET_BRIDGE_URL: z.string().optional(),
  /** Shared secret for POST /internal/socket-bridge/emit */
  SOCKET_BRIDGE_SECRET: z.string().optional(),
  MONGO_URI: z.string().min(1),
  /** Optional: avoid URL-encoding issues with special chars in Atlas passwords on Vercel. */
  MONGO_USER: z.string().optional(),
  MONGO_PASSWORD: z.string().optional(),
  JWT_ACCESS_SECRET: z.string().min(16),
  JWT_REFRESH_SECRET: z.string().min(16),
  JWT_ACCESS_EXPIRES_IN: z.string().default("15m"),
  JWT_REFRESH_EXPIRES_IN: z.string().default("7d"),
  BCRYPT_SALT_ROUNDS: z.coerce.number().min(8).max(15).default(10),
  SMTP_HOST: z.string().min(1),
  SMTP_PORT: z.coerce.number().min(1),
  SMTP_USER: z.string().min(1),
  SMTP_PASSWORD: z.string().min(1),
  SMTP_FROM_EMAIL: z.string().min(1),
  SMTP_TLS_REJECT_UNAUTHORIZED: booleanFromEnv.default(true),
  OSRM_URL: z.string().min(1),
  RAZORPAY_KEY_ID: z.string().min(1),
  RAZORPAY_KEY_SECRET: z.string().min(1),
  AWS_ACCESS_KEY_ID: z.string().optional(),
  AWS_SECRET_ACCESS_KEY: z.string().optional(),
  AWS_REGION: z.string().optional(),
  /** Default S3 bucket; also fallback when AWS_S3_BUCKET_DOCUMENTS is unset. */
  AWS_S3_BUCKET: z.string().optional(),
  /** Dedicated bucket for driver/taxi document uploads (recommended). Overrides AWS_S3_BUCKET for file storage when set. */
  AWS_S3_BUCKET_DOCUMENTS: z.string().optional(),
});

const parsedEnv = envSchema.safeParse(process.env);

if (!parsedEnv.success) {
  throw new Error(`Invalid environment configuration: ${parsedEnv.error.message}`);
}

export const env = parsedEnv.data;
const isTest = process.env.NODE_ENV === "test";

export const MONGO_URI = isTest
  ? "mongodb://127.0.0.1:27017/taxi_app"
  : env.MONGO_URI;

export const MONGO_USER = isTest ? undefined : env.MONGO_USER;
export const MONGO_PASSWORD = isTest ? undefined : env.MONGO_PASSWORD;
