import { Db } from "mongodb";
import { Migration } from "./migration.types";

const RIDES_COLLECTION = "rides";

const up = async (db: Db): Promise<void> => {
  const existingCollections = await db.listCollections({ name: RIDES_COLLECTION }).toArray();

  if (existingCollections.length === 0) {
    await db.createCollection(RIDES_COLLECTION, {
      validator: {
        $jsonSchema: {
          bsonType: "object",
          required: [
            "customer_id",
            "pickup",
            "drop",
            "distance_km",
            "fare",
            "otp",
            "otp_verified",
            "status",
            "createdAt",
            "updatedAt",
          ],
          properties: {
            customer_id: { bsonType: "objectId" },
            pickup: {
              bsonType: "object",
              required: ["lat", "lng"],
              properties: {
                lat: { bsonType: ["double", "int", "long", "decimal"] },
                lng: { bsonType: ["double", "int", "long", "decimal"] },
                address: { bsonType: "string" },
              },
            },
            drop: {
              bsonType: "object",
              required: ["lat", "lng"],
              properties: {
                lat: { bsonType: ["double", "int", "long", "decimal"] },
                lng: { bsonType: ["double", "int", "long", "decimal"] },
                address: { bsonType: "string" },
              },
            },
            distance_km: { bsonType: ["double", "int", "long", "decimal"] },
            fare: { bsonType: ["double", "int", "long", "decimal"] },
            otp: { bsonType: ["int", "long"] },
            otp_verified: { bsonType: "bool" },
            status: {
              enum: [
                "PENDING_CONFIRMATION",
                "SEARCHING_DRIVER",
                "DRIVER_ASSIGNED",
                "ARRIVED_AT_PICKUP",
                "PICKED_UP",
                "IN_TRANSIT",
                "STARTED",
                "COMPLETED",
                "CANCELLED",
              ],
            },
            driver_id: { bsonType: ["objectId", "null"] },
            createdAt: { bsonType: "date" },
            updatedAt: { bsonType: "date" },
          },
        },
      },
    });
    console.log("rides collection created");
  } else {
    console.log("rides collection already exists");
  }

  const ridesCollection = db.collection(RIDES_COLLECTION);
  const existingIndexes = await ridesCollection.indexes();
  const hasCustomerCreatedAtIndex = existingIndexes.some(
    (index) => index.key?.customer_id === 1 && index.key?.createdAt === -1
  );
  const hasStatusIndex = existingIndexes.some((index) => index.key?.status === 1);

  if (!hasCustomerCreatedAtIndex) {
    await ridesCollection.createIndex({ customer_id: 1, createdAt: -1 });
  }

  if (!hasStatusIndex) {
    await ridesCollection.createIndex({ status: 1 });
  }

  console.log("rides indexes ensured");
};

const down = async (db: Db): Promise<void> => {
  const existingCollections = await db.listCollections({ name: RIDES_COLLECTION }).toArray();
  if (existingCollections.length === 0) {
    console.log("rides collection does not exist, nothing to rollback");
    return;
  }

  await db.collection(RIDES_COLLECTION).drop();
  console.log("rides collection dropped");
};

const migration: Migration = {
  up,
  down,
};

export default migration;
