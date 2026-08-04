import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../../middlewares/auth.middleware";
import { requireRole } from "../../middlewares/role.middleware";
import { validate } from "../../middlewares/validate.middleware";
import {
  getAdminInvoicesController,
  getCustomerInvoiceController,
  getDriverInvoiceController,
} from "./invoice.controller";

const rideIdParamSchema = z.object({
  params: z.object({
    rideId: z.string().regex(/^[a-fA-F0-9]{24}$/, "Invalid ride id"),
  }),
  body: z.object({}).optional(),
  query: z.object({}).optional(),
});

const invoiceRouter = Router();

invoiceRouter.get(
  "/api/customer/invoices/:rideId",
  requireAuth,
  requireRole(["CUSTOMER"]),
  validate(rideIdParamSchema),
  getCustomerInvoiceController
);

invoiceRouter.get(
  "/api/driver/invoices/:rideId",
  requireAuth,
  requireRole(["DRIVER"]),
  validate(rideIdParamSchema),
  getDriverInvoiceController
);

invoiceRouter.get(
  "/api/admin/invoices",
  requireAuth,
  requireRole(["ADMIN"]),
  getAdminInvoicesController
);

invoiceRouter.get(
  "/api/v1/admin/invoices",
  requireAuth,
  requireRole(["ADMIN"]),
  getAdminInvoicesController
);

export default invoiceRouter;

