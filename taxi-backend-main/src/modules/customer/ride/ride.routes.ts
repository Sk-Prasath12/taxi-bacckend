import { Router } from "express";
import { requireAuth } from "../../../middlewares/auth.middleware";
import { requireRole } from "../../../middlewares/role.middleware";
import { validate } from "../../../middlewares/validate.middleware";
import {
  abandonActiveRideController,
  cancelRideController,
  confirmRideController,
  getActiveRideController,
  getRideHistoryByIdController,
  getRideHistoryController,
  getRideInvoiceController,
  getRideStatusController,
  requestRideController,
  triggerRideEmergencyController,
} from "./ride.controller";
import { confirmRideSchema, requestRideSchema, rideIdParamSchema } from "./ride.validator";

const customerRideRouter = Router();

customerRideRouter.use("/api/customers/rides", requireAuth, requireRole(["CUSTOMER"]));
customerRideRouter.use("/api/rides", requireAuth, requireRole(["CUSTOMER"]));

customerRideRouter.post("/api/customers/rides/request", validate(requestRideSchema), requestRideController);
customerRideRouter.post("/api/rides/request", validate(requestRideSchema), requestRideController);
customerRideRouter.post("/api/customers/rides/confirm", validate(confirmRideSchema), confirmRideController);
customerRideRouter.get("/api/customers/rides/active", getActiveRideController);
customerRideRouter.post("/api/customers/rides/active/abandon", abandonActiveRideController);
customerRideRouter.get(
  "/api/customers/rides/:rideId/status",
  validate(rideIdParamSchema),
  getRideStatusController
);
customerRideRouter.post(
  "/api/customers/rides/:rideId/cancel",
  validate(rideIdParamSchema),
  cancelRideController
);
customerRideRouter.get("/api/customers/rides/history", getRideHistoryController);
customerRideRouter.get(
  "/api/customers/rides/history/:rideId",
  validate(rideIdParamSchema),
  getRideHistoryByIdController
);
customerRideRouter.get(
  "/api/customers/rides/:rideId/invoice",
  validate(rideIdParamSchema),
  getRideInvoiceController
);
customerRideRouter.post(
  "/api/customers/rides/:rideId/emergency",
  validate(rideIdParamSchema),
  triggerRideEmergencyController
);

export default customerRideRouter;
