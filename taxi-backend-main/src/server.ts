import http from "http";
import app from "./app";
import "./config/firebase";
import { env } from "./config/env";
import { logger } from "./config/logger";
import { connectDatabase, disconnectDatabase } from "./database/mongoose";
import { DriverDocumentModel } from "./modules/driver-documents/driver-document.model";
import { LocationModel } from "./modules/locations/location.model";
import { UserModel } from "./modules/users/users.model";
import { initializeSocketServer } from "./socket/socket";

const startServer = async () => {
  await connectDatabase();
  const indexDiff = await DriverDocumentModel.syncIndexes();
  if (indexDiff.length > 0) {
    logger.info({ indexDiff }, "driver_documents indexes synced");
  }
  await LocationModel.syncIndexes();
  await UserModel.syncIndexes();

  const server = http.createServer(app);
  initializeSocketServer(server);

  server.listen(env.PORT, env.HOST, () => {
    logger.info(`Server running on ${env.HOST}:${env.PORT}`);
  });

  const shutdown = async (signal: string) => {
    logger.info(`${signal} received. Starting graceful shutdown...`);
    server.close(async () => {
      await disconnectDatabase();
      process.exit(0);
    });
  };

  process.on("SIGINT", () => {
    void shutdown("SIGINT");
  });
  process.on("SIGTERM", () => {
    void shutdown("SIGTERM");
  });
};

if (process.env.NODE_ENV !== "test") {
  startServer().catch((error) => {
    logger.error({ error }, "Server startup failed");
    process.exit(1);
  });
}
