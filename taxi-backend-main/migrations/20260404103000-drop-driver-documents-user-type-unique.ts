import { Db } from "mongodb";
import { Migration } from "./migration.types";

const COLLECTION = "driver_documents";
/** Mongoose default name for schema.index({ user_id: 1, document_type: 1 }, { unique: true }) */
const LEGACY_UNIQUE_INDEX = "user_id_1_document_type_1";

/**
 * Allow multiple driver_documents rows per (user_id, document_type).
 * POST /upload always creates a new doc; PUT /:id/reupload still replaces one row.
 */
const up = async (db: Db): Promise<void> => {
  const coll = db.collection(COLLECTION);
  const indexes = await coll.indexes();
  const names = indexes.map((i) => i.name).filter(Boolean) as string[];

  if (names.includes(LEGACY_UNIQUE_INDEX)) {
    await coll.dropIndex(LEGACY_UNIQUE_INDEX);
    console.log(`Dropped unique index ${LEGACY_UNIQUE_INDEX} on ${COLLECTION}`);
  } else {
    console.log(`Index ${LEGACY_UNIQUE_INDEX} not found on ${COLLECTION} (skipped)`);
  }

  await coll.createIndex({ user_id: 1, document_type: 1 });
  console.log(`Ensured non-unique compound index user_id + document_type on ${COLLECTION}`);
};

const down = async (db: Db): Promise<void> => {
  const coll = db.collection(COLLECTION);
  const dupes = await coll
    .aggregate<{ _id: { user_id: unknown; document_type: string }; n: number }>([
      { $group: { _id: { user_id: "$user_id", document_type: "$document_type" }, n: { $sum: 1 } } },
      { $match: { n: { $gt: 1 } } },
    ])
    .toArray();

  if (dupes.length > 0) {
    throw new Error(
      `Cannot restore unique index: ${dupes.length} duplicate (user_id, document_type) groups exist`
    );
  }

  await coll.dropIndex("user_id_1_document_type_1").catch(() => undefined);
  await coll.createIndex({ user_id: 1, document_type: 1 }, { unique: true });
  console.log(`Restored unique index on ${COLLECTION}`);
};

const migration: Migration = {
  up,
  down,
};

export default migration;
