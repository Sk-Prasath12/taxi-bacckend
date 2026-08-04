import fs from "fs";
import path from "path";
import { connectDatabase, disconnectDatabase } from "../src/database/mongoose";
import { Seed } from "./seed.types";

const getSeedFiles = (): string[] => {
  return fs
    .readdirSync(__dirname)
    .filter((file) => file.endsWith(".ts"))
    .filter((file) => file !== "run-seeds.ts" && file !== "seed.types.ts")
    .sort();
};

const loadSeed = (fileName: string): Seed => {
  const fullPath = path.join(__dirname, fileName);
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const module = require(fullPath);
  const seed = module.default as Seed | undefined;

  if (!seed || !seed.name || typeof seed.run !== "function") {
    throw new Error(`Invalid seed file: ${fileName}`);
  }

  return seed;
};

const getOnlySeedArg = (): string | null => {
  const arg = process.argv.find((value) => value.startsWith("--only="));
  return arg ? arg.replace("--only=", "").trim() : null;
};

const run = async (): Promise<void> => {
  const onlySeed = getOnlySeedArg();
  await connectDatabase();

  const seeds = getSeedFiles().map(loadSeed);
  const targetSeeds = onlySeed ? seeds.filter((seed) => seed.name === onlySeed) : seeds;

  if (targetSeeds.length === 0) {
    console.log(onlySeed ? `No seed found for '${onlySeed}'` : "No seed files found");
    await disconnectDatabase();
    return;
  }

  for (const seed of targetSeeds) {
    console.log(`Running seed: ${seed.name}`);
    await seed.run();
    console.log(`Seed completed: ${seed.name}`);
  }

  console.log("All seed files executed");
  await disconnectDatabase();
};

run().catch(async (error) => {
  console.error("Seed runner failed", error);
  await disconnectDatabase();
  process.exit(1);
});
