import mongoose from "mongoose";
import { MONGO_URI } from "../config/env";
import { logger } from "../config/logger";

const MAX_RETRIES = 5;
const RETRY_DELAY_MS = 5000;

const wait = async (ms: number): Promise<void> =>
  new Promise((resolve) => {
    setTimeout(resolve, ms);
  });

export const connectDatabase = async (): Promise<void> => {
  let retries = 0;
  console.log("Mongo URI:", MONGO_URI);

  while (retries < MAX_RETRIES) {
    try {
      await mongoose.connect(MONGO_URI);
      logger.info("MongoDB connected");
      return;
    } catch (error) {
      retries += 1;
      logger.error({ error, retries }, "MongoDB connection failed");

      if (retries >= MAX_RETRIES) {
        throw new Error("Unable to connect to MongoDB after retries");
      }

      await wait(RETRY_DELAY_MS);
    }
  }
};

export const disconnectDatabase = async (): Promise<void> => {
  await mongoose.connection.close();
  logger.info("MongoDB disconnected");
};
