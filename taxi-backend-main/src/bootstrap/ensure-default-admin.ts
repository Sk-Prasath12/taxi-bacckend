import { logger } from "../config/logger";
import { createUser, findUserByEmail } from "../modules/users/users.repository";
import { hashPassword } from "../utils/password.util";

const DEFAULT_ADMIN_EMAIL = (process.env.ADMIN_SEED_EMAIL ?? "admin@taxigo.com").toLowerCase().trim();
const DEFAULT_ADMIN_PASSWORD = process.env.ADMIN_SEED_PASSWORD ?? "admin123";

declare global {
  // eslint-disable-next-line no-var
  var __taxiAdminReady: Promise<void> | undefined;
}

async function ensureDefaultAdminOnce(): Promise<void> {
  const passwordHash = await hashPassword(DEFAULT_ADMIN_PASSWORD);
  const existing = await findUserByEmail(DEFAULT_ADMIN_EMAIL);

  if (existing) {
    if (existing.role !== "ADMIN") {
      existing.role = "ADMIN";
    }
    existing.password_hash = passwordHash;
    existing.is_active = true;
    existing.is_blocked = false;
    existing.name = existing.name || "Taxi Admin";
    await existing.save();
    logger.info({ email: DEFAULT_ADMIN_EMAIL }, "Default admin account synced");
    return;
  }

  await createUser({
    name: "Taxi Admin",
    email: DEFAULT_ADMIN_EMAIL,
    password_hash: passwordHash,
    role: "ADMIN",
    is_active: true,
    is_blocked: false,
  });
  logger.info({ email: DEFAULT_ADMIN_EMAIL }, "Default admin account created");
}

/** Idempotent — safe on every Vercel cold start and local Docker boot. */
export function ensureDefaultAdmin(): Promise<void> {
  if (!global.__taxiAdminReady) {
    global.__taxiAdminReady = ensureDefaultAdminOnce().catch((error) => {
      global.__taxiAdminReady = undefined;
      throw error;
    });
  }
  return global.__taxiAdminReady;
}
