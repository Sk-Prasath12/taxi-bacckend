import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../../middlewares/auth.middleware";
import { requireRole } from "../../middlewares/role.middleware";
import { validate } from "../../middlewares/validate.middleware";
import {
  adminPaymentHistoryController,
  createPaymentOrderController,
  customerPaymentHistoryController,
  driverPaymentHistoryController,
  verifyPaymentController,
} from "./payment.controller";

const createOrderSchema = z.object({
  body: z.object({
    ride_id: z.string().regex(/^[a-fA-F0-9]{24}$/, "Invalid ride id"),
  }),
  params: z.object({}),
  query: z.object({}),
});

const verifyPaymentSchema = z.object({
  body: z.object({
    ride_id: z.string().regex(/^[a-fA-F0-9]{24}$/, "Invalid ride id"),
    order_id: z.string().min(1, "order_id is required"),
    payment_id: z.string().min(1, "payment_id is required"),
    signature: z.string().min(1, "signature is required"),
  }),
  params: z.object({}),
  query: z.object({}),
});

const paymentRouter = Router();

paymentRouter.post(
  "/api/payments/create-order",
  requireAuth,
  requireRole(["CUSTOMER"]),
  validate(createOrderSchema),
  createPaymentOrderController
);
paymentRouter.post(
  "/api/payments/verify",
  requireAuth,
  requireRole(["CUSTOMER"]),
  validate(verifyPaymentSchema),
  verifyPaymentController
);
paymentRouter.get(
  "/api/payments/history",
  requireAuth,
  requireRole(["CUSTOMER"]),
  customerPaymentHistoryController
);
paymentRouter.get(
  "/api/drivers/payments/history",
  requireAuth,
  requireRole(["DRIVER"]),
  driverPaymentHistoryController
);
paymentRouter.get(
  "/api/admin/payments/history",
  requireAuth,
  requireRole(["ADMIN"]),
  adminPaymentHistoryController
);

export default paymentRouter;
