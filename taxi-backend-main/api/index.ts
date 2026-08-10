import type { Request, Response } from "express";

import "../src/config/firebase";
import app from "../src/app";
import { ensureDefaultAdmin } from "../src/bootstrap/ensure-default-admin";
import { ensureRideBootstrap } from "../src/bootstrap/ensure-ride-bootstrap";
import { connectDatabase } from "../src/database/mongoose";

declare global {
  // eslint-disable-next-line no-var
  var __taxiMongoReady: Promise<void> | undefined;
}

function ensureDatabase(): Promise<void> {
  if (!global.__taxiMongoReady) {
    global.__taxiMongoReady = connectDatabase();
  }
  return global.__taxiMongoReady;
}

/** Vercel serverless entry — REST API only (Socket.IO needs Railway/Render/VPS). */
export default async function handler(req: Request, res: Response) {
  try {
    await ensureDatabase();
    await ensureDefaultAdmin();
    await ensureRideBootstrap();
  } catch {
    res.status(503).json({
      success: false,
      message: "Database unavailable. Check MONGO_URI on Vercel.",
    });
    return;
  }

  return app(req, res);
}
