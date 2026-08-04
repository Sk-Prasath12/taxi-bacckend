import fs from "fs";
import path from "path";
import mongoose from "mongoose";
import { Migration } from "./migration.types";
import { connectDatabase, disconnectDatabase } from "../src/database/mongoose";

const MIGRATIONS_COLLECTION = "migrations";
const MIGRATION_FILE_REGEX = /^\d{12,}-[a-z0-9-]+\.ts$/;

const getMigrationFiles = (): string[] => {
  return fs
    .readdirSync(__dirname)
    .filter((file) => file.endsWith(".ts"))
    .filter((file) => file !== "run-migrations.ts" && file !== "migration.types.ts")
    .filter((file) => MIGRATION_FILE_REGEX.test(file))
    .sort();
};

const getMigrationId = (fileName: string): string => fileName.replace(/\.ts$/, "");

const loadMigration = (fileName: string): { id: string; migration: Migration } => {
  const fullPath = path.join(__dirname, fileName);
  const id = getMigrationId(fileName);
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const module = require(fullPath);
  const migration = module.default as Migration | undefined;

  if (!migration || typeof migration.up !== "function") {
    throw new Error(`Invalid migration file: ${fileName}`);
  }

  return { id, migration };
};

const getDirection = (): "up" | "down" => {
  const downArg = process.argv.includes("--down");
  return downArg ? "down" : "up";
};

const getRollbackSteps = (): number => {
  const stepArg = process.argv.find((arg) => arg.startsWith("--steps="));
  if (!stepArg) {
    return 1;
  }

  const parsed = Number(stepArg.replace("--steps=", ""));
  return Number.isInteger(parsed) && parsed > 0 ? parsed : 1;
};

const runUpMigrations = async (
  tracker: mongoose.mongo.Collection,
  appliedSet: Set<string>
): Promise<void> => {
  const pendingMigrations = getMigrationFiles()
    .map(loadMigration)
    .filter(({ id }) => !appliedSet.has(id));

  if (pendingMigrations.length === 0) {
    console.log("Migrations already up to date");
    return;
  }

  const db = mongoose.connection.db;
  if (!db) {
    throw new Error("Database connection is not available");
  }

  for (const item of pendingMigrations) {
    console.log(`Running migration: ${item.id}`);
    await item.migration.up(db);
    await tracker.insertOne({ id: item.id, name: item.id, executed_at: new Date() });
    console.log(`Migration applied: ${item.id}`);
  }

  console.log("All pending migrations applied");
};

const runDownMigrations = async (
  tracker: mongoose.mongo.Collection,
  appliedSet: Set<string>
): Promise<void> => {
  const steps = getRollbackSteps();
  const files = getMigrationFiles().map(loadMigration);
  const rollbackCandidates = files
    .filter(({ id, migration }) => appliedSet.has(id) && typeof migration.down === "function")
    .sort((a, b) => (a.id < b.id ? 1 : -1))
    .slice(0, steps);

  if (rollbackCandidates.length === 0) {
    console.log("No applied migrations available to rollback");
    return;
  }

  const db = mongoose.connection.db;
  if (!db) {
    throw new Error("Database connection is not available");
  }

  for (const item of rollbackCandidates) {
    console.log(`Rolling back migration: ${item.id}`);
    await item.migration.down!(db);
    await tracker.deleteOne({ $or: [{ id: item.id }, { name: item.id }] });
    console.log(`Migration rolled back: ${item.id}`);
  }

  console.log("Rollback completed");
};

const run = async (): Promise<void> => {
  await connectDatabase();

  const db = mongoose.connection.db;
  if (!db) {
    throw new Error("Database connection is not available");
  }

  const tracker = db.collection(MIGRATIONS_COLLECTION);
  await tracker.createIndex({ id: 1 }, { unique: true });

  const applied = await tracker.find({}, { projection: { id: 1, name: 1 } }).toArray();
  const appliedSet = new Set(
    applied.flatMap((item) => [String(item.id || ""), String(item.name || "")]).filter(Boolean)
  );

  if (getDirection() === "down") {
    await runDownMigrations(tracker, appliedSet);
  } else {
    await runUpMigrations(tracker, appliedSet);
  }

  await disconnectDatabase();
};

run().catch(async (error) => {
  console.error("Migration runner failed", error);
  await disconnectDatabase();
  process.exit(1);
});
