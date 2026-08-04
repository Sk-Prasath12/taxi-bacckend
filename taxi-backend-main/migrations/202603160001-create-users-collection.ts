import { Db } from "mongodb";
import { Migration } from "./migration.types";

const USERS_COLLECTION = "users";

const up = async (db: Db): Promise<void> => {
  const existingCollections = await db.listCollections({ name: USERS_COLLECTION }).toArray();

  if (existingCollections.length === 0) {
    await db.createCollection(USERS_COLLECTION, {
      validator: {
        $jsonSchema: {
          bsonType: "object",
          required: ["name", "email", "password_hash", "role", "is_active", "is_blocked"],
          properties: {
            name: { bsonType: "string" },
            email: { bsonType: "string" },
            phone: { bsonType: "string" },
            password_hash: { bsonType: "string" },
            role: { enum: ["ADMIN", "CUSTOMER", "DRIVER"] },
            is_active: { bsonType: "bool" },
            is_blocked: { bsonType: "bool" },
            created_at: { bsonType: "date" },
            updated_at: { bsonType: "date" },
          },
        },
      },
    });
    console.log("users collection created");
  } else {
    console.log("users collection already exists");
  }

  const usersCollection = db.collection(USERS_COLLECTION);
  const existingIndexes = await usersCollection.indexes();
  const hasEmailIndex = existingIndexes.some((index) => index.key?.email === 1);
  const hasRoleIndex = existingIndexes.some((index) => index.key?.role === 1);

  if (!hasEmailIndex) {
    await usersCollection.createIndex({ email: 1 }, { unique: true });
  }

  if (!hasRoleIndex) {
    await usersCollection.createIndex({ role: 1 });
  }

  console.log("users indexes ensured");
};

const down = async (db: Db): Promise<void> => {
  const existingCollections = await db.listCollections({ name: USERS_COLLECTION }).toArray();
  if (existingCollections.length === 0) {
    console.log("users collection does not exist, nothing to rollback");
    return;
  }

  await db.collection(USERS_COLLECTION).drop();
  console.log("users collection dropped");
};

const migration: Migration = {
  up,
  down,
};

export default migration;
