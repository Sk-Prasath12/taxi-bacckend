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
  return res.status(200).json(successResponse("Service healthy"));
});

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
app.use(adminRatingRouter);

app.use(notFoundHandler);
app.use(globalErrorHandler);

export default app;
