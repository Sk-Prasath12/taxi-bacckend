import { Db } from "mongodb";
import { Migration } from "./migration.types";

const USERS_COLLECTION = "users";

/**
 * Older driver user documents were created before Mongoose added
 * is_driver_verified / driver_verification_status, so those keys were never
 * persisted. Backfill so every DRIVER document in MongoDB has explicit values.
 */
const up = async (db: Db): Promise<void> => {
  const users = db.collection(USERS_COLLECTION);

  const verified = await users.updateMany(
    { role: "DRIVER", is_driver_verified: { $exists: false } },
    { $set: { is_driver_verified: false } }
  );

  const status = await users.updateMany(
    { role: "DRIVER", driver_verification_status: { $exists: false } },
    { $set: { driver_verification_status: "PENDING" } }
  );

  console.log(
    `Backfilled driver verification fields: is_driver_verified set on ${verified.modifiedCount} docs, driver_verification_status on ${status.modifiedCount} docs`
  );
};

const migration: Migration = {
  up,
};

export default migration;
