import express from "express";
import cors from "cors";
import pinoHttp from "pino-http";
import { env } from "./config/env";
import { logger } from "./config/logger";
import { successResponse } from "./utils/api-response";
import authRouter from "./modules/auth/auth.routes";
import adminRouter from "./modules/admin/admin.routes";
import usersRouter from "./modules/users/users.routes";
import customerRouter from "./modules/customer/customer.routes";
import driverRouter from "./modules/driver/driver.routes";
import vehicleTypeRouter from "./modules/vehicle-type/vehicle-type.routes";
import paymentRouter from "./modules/payment/payment.routes";
import withdrawRouter from "./modules/withdraw/withdraw.routes";
import invoiceRouter from "./modules/invoice/invoice.routes";
import driverAppRouter from "./modules/driver-app/driver-app.routes";
import { adminSupportRouter, supportRouter } from "./modules/support/ticket.routes";
import { adminRatingRouter, ratingRouter } from "./modules/rating/rating.routes";
import operationalZoneRouter from "./modules/operational-zone/operational-zone.routes";
import notificationRouter from "./modules/notification/notification.routes";
import {
  driverDocumentsAdminRouter,
  driverDocumentsDriverRouter,
} from "./modules/driver-documents/driver-document.routes";
import driverProfileRouter from "./modules/driver-profile/driver-profile.routes";
import { globalErrorHandler, notFoundHandler } from "./middlewares/error.middleware";
import socketBridgeRouter from "./modules/internal/socket-bridge.routes";


export const app = express();

const corsOrigins = env.CORS_ORIGINS?.split(",")
  .map((s) => s.trim())
  .filter(Boolean);
app.use(
  cors(
    corsOrigins && corsOrigins.length > 0
      ? { origin: corsOrigins, credentials: true }
      : undefined,
  ),
);
app.use(express.json());
app.use(pinoHttp({ logger }));

app.get("/api/v1/health", (_req, res) => {
  return res.status(200).json(
    successResponse("Service healthy", {
      socket: env.SOCKET_BRIDGE_URL ? "bridge" : "local_or_polling",
    })
  );
});

/** Public root — HTML for browsers/Vercel preview; JSON for API clients. */
app.get(["/", "/api"], (req, res) => {
  const wantsJson = req.query.format === "json";
  const wantsHtml =
    !wantsJson &&
    ((req.headers.accept ?? "").includes("text/html") || req.query.view === "html");

  if (wantsHtml) {
    res.setHeader("Content-Type", "text/html; charset=utf-8");
    return res.status(200).send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Taxi Backend API</title>
  <style>
    :root { color-scheme: dark; }
    body {
      margin: 0; min-height: 100vh; display: grid; place-items: center;
      font-family: Segoe UI, system-ui, sans-serif;
      background: radial-gradient(1200px 600px at 20% 0%, #1e3a8a 0%, #0b1220 55%, #020617 100%);
      color: #e2e8f0;
    }
    .card {
      width: min(520px, 92vw); padding: 28px 28px 24px;
      border: 1px solid rgba(148,163,184,.25); border-radius: 18px;
      background: rgba(15,23,42,.78); backdrop-filter: blur(10px);
      box-shadow: 0 20px 60px rgba(0,0,0,.35);
    }
    .badge {
      display: inline-flex; align-items: center; gap: 8px;
      font-size: 12px; font-weight: 700; letter-spacing: .04em;
      color: #86efac; background: rgba(22,163,74,.15);
      border: 1px solid rgba(74,222,128,.35); border-radius: 999px;
      padding: 6px 12px; margin-bottom: 14px;
    }
    .dot { width: 8px; height: 8px; border-radius: 50%; background: #4ade80; box-shadow: 0 0 0 4px rgba(74,222,128,.15); }
    h1 { margin: 0 0 8px; font-size: 28px; color: #f8fafc; }
    p { margin: 0 0 18px; color: #94a3b8; line-height: 1.5; }
    ul { margin: 0; padding-left: 18px; color: #cbd5e1; }
    li { margin: 6px 0; }
    a { color: #93c5fd; text-decoration: none; }
    a:hover { text-decoration: underline; }
  </style>
</head>
<body>
  <main class="card">
    <div class="badge"><span class="dot"></span> PRODUCTION ONLINE</div>
    <h1>Taxi Backend API</h1>
    <p>Server is live. Apps use these endpoints for auth, rides, OTP, and payments.</p>
    <ul>
      <li><a href="/api/v1/health">/api/v1/health</a></li>
      <li><a href="/api/vehicle-types/active">/api/vehicle-types/active</a></li>
      <li><a href="/?format=json">JSON status</a></li>
    </ul>
  </main>
</body>
</html>`);
  }

  return res.status(200).json(
    successResponse("Taxi API is online", {
      health: "/api/v1/health",
      vehicles: "/api/vehicle-types/active",
      docs: "Use /api/customers/* and /api/drivers/* endpoints",
    })
  );
});

app.use("/internal/socket-bridge", socketBridgeRouter);

app.use("/api/v1/auth", authRouter);
app.use("/api/v1/admin", adminRouter);
app.use("/api/admin", adminRouter);
app.use("/api/v1/users", usersRouter);
app.use("/api/users", usersRouter);
app.use(customerRouter);
app.use(driverRouter);
app.use(driverDocumentsDriverRouter);
app.use("/api/v1/driver", driverProfileRouter);
app.use("/api/v1/admin", driverDocumentsAdminRouter);
app.use("/api/admin", driverDocumentsAdminRouter);
app.use(operationalZoneRouter);
app.use("/api/vehicle-types", vehicleTypeRouter);
app.use(notificationRouter);
app.use(paymentRouter);
app.use(withdrawRouter);
app.use(invoiceRouter);
app.use("/api/driver-app", driverAppRouter);
app.use("/api/support", supportRouter);
app.use("/api/admin", adminSupportRouter);
app.use(ratingRouter);
app.use("/api/admin", adminRatingRouter);

app.use(notFoundHandler);
app.use(globalErrorHandler);

export default app;
