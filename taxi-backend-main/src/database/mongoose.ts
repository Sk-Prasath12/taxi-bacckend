import mongoose from "mongoose";
import { MONGO_PASSWORD, MONGO_URI, MONGO_USER } from "../config/env";
import { logger } from "../config/logger";

const MAX_RETRIES = 5;
const RETRY_DELAY_MS = 5000;

const wait = async (ms: number): Promise<void> =>
  new Promise((resolve) => {
    setTimeout(resolve, ms);
  });

export const connectDatabase = async (): Promise<void> => {
  const onVercel = Boolean(process.env.VERCEL);
  const maxRetries = onVercel ? 2 : MAX_RETRIES;
  const retryDelayMs = onVercel ? 2000 : RETRY_DELAY_MS;
  let retries = 0;
  console.log("Mongo URI:", MONGO_URI.replace(/:[^:@/]+@/, ":****@"));
  console.log("Mongo auth mode:", MONGO_USER ? "user/password env" : "uri credentials");

  while (retries < maxRetries) {
    try {
      const options: mongoose.ConnectOptions = {
        serverSelectionTimeoutMS: onVercel ? 8000 : 30000,
        connectTimeoutMS: onVercel ? 8000 : 30000,
      };
      if (MONGO_USER && MONGO_PASSWORD) {
        options.user = MONGO_USER;
        options.pass = MONGO_PASSWORD;
      }
      await mongoose.connect(MONGO_URI, options);
      logger.info("MongoDB connected");
      return;
    } catch (error) {
      retries += 1;
      logger.error({ error, retries }, "MongoDB connection failed");

      if (retries >= maxRetries) {
        throw new Error("Unable to connect to MongoDB after retries");
      }

      await wait(retryDelayMs);
    }
  }
};

export const disconnectDatabase = async (): Promise<void> => {
  await mongoose.connection.close();
  logger.info("MongoDB disconnected");
};
