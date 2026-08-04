import { logger } from "../src/config/logger";
import { findUserByEmail, createUser } from "../src/modules/users/users.repository";
import { hashPassword } from "../src/utils/password.util";
import { Seed } from "./seed.types";

const ADMIN_EMAIL = "admin@taxigo.com";
const ADMIN_PASSWORD = "admin123";

const run = async (): Promise<void> => {
  const passwordHash = await hashPassword(ADMIN_PASSWORD);
  const existingAdmin = await findUserByEmail(ADMIN_EMAIL);

  if (existingAdmin) {
    existingAdmin.password_hash = passwordHash;
    existingAdmin.role = "ADMIN";
    existingAdmin.is_active = true;
    existingAdmin.is_blocked = false;
    existingAdmin.name = existingAdmin.name || "Taxi Admin";
    await existingAdmin.save();
    logger.info("Admin credentials synced for admin@taxigo.com");
    return;
  }

  await createUser({
    name: "Taxi Admin",
    email: ADMIN_EMAIL,
    password_hash: passwordHash,
    role: "ADMIN",
    is_active: true,
    is_blocked: false,
  });

  logger.info("Admin seeded successfully");
};

const seed: Seed = {
  name: "seed-admin",
  run,
};

export default seed;
