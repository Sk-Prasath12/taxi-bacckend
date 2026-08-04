import { Router } from "express";
import { requireAuth } from "../../middlewares/auth.middleware";
import { requireRole } from "../../middlewares/role.middleware";
import { validate } from "../../middlewares/validate.middleware";
import {
  createOperationalZoneController,
  getOperationalZonesController,
  toggleOperationalZoneStatusController,
  updateOperationalZoneController,
} from "./operational-zone.controller";
import {
  createOperationalZoneSchema,
  toggleOperationalZoneStatusSchema,
  updateOperationalZoneSchema,
} from "./operational-zone.validation";

const operationalZoneRouter = Router();

operationalZoneRouter.post(
  "/api/admin/operational-zones",
  requireAuth,
  requireRole(["ADMIN"]),
  validate(createOperationalZoneSchema),
  createOperationalZoneController
);

operationalZoneRouter.get(
  "/api/admin/operational-zones",
  requireAuth,
  requireRole(["ADMIN"]),
  getOperationalZonesController
);

operationalZoneRouter.put(
  "/api/admin/operational-zones/:id",
  requireAuth,
  requireRole(["ADMIN"]),
  validate(updateOperationalZoneSchema),
  updateOperationalZoneController
);

operationalZoneRouter.patch(
  "/api/admin/operational-zones/:id/status",
  requireAuth,
  requireRole(["ADMIN"]),
  validate(toggleOperationalZoneStatusSchema),
  toggleOperationalZoneStatusController
);

export default operationalZoneRouter;
