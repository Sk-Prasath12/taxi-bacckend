import { Router } from "express";
import { requireAuth } from "../../middlewares/auth.middleware";
import { requireRole } from "../../middlewares/role.middleware";
import { validate } from "../../middlewares/validate.middleware";
import {
  getDriverProfileExtendedController,
  upsertDriverProfileController,
} from "./driver-profile.controller";
import { upsertDriverProfileSchema } from "./driver-profile.validation";

const driverProfileRouter = Router();

driverProfileRouter.post(
  "/profile",
  requireAuth,
  requireRole(["DRIVER"]),
  validate(upsertDriverProfileSchema),
  upsertDriverProfileController
);

driverProfileRouter.get(
  "/profile",
  requireAuth,
  requireRole(["DRIVER"]),
  getDriverProfileExtendedController
);

export default driverProfileRouter;
