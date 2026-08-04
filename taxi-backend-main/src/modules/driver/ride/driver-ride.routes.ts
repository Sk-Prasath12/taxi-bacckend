import { Router } from "express";
import { validate } from "../../../middlewares/validate.middleware";
import {
  acceptIncomingRideByBodyController,
  acceptIncomingRideController,
  getDriverActiveRideController,
  getDriverRideByIdController,
  getDriverRideHistoryController,
  getIncomingRidesController,
  markRideArrivedAtPickupController,
  completeRideController,
  confirmCashReceivedController,
  markRideDroppedController,
  markRideInTransitController,
  markRidePickedUpController,
  rejectIncomingRideController,
  updateRideStatusController,
  verifyDropOtpController,
  verifyRideOtpController,
} from "./driver-ride.controller";
import {
  acceptRideBodySchema,
  driverRideIdParamSchema,
  dropReachedBodySchema,
  updateRideStatusSchema,
  verifyRideOtpSchema,
} from "./driver-ride.validator";

const driverRideRouter = Router();

driverRideRouter.get("/api/drivers/rides/active", getDriverActiveRideController);
driverRideRouter.get("/api/drivers/rides/incoming", getIncomingRidesController);
driverRideRouter.get("/api/drivers/rides/history", getDriverRideHistoryController);
driverRideRouter.get(
  "/api/drivers/rides/:rideId",
  validate(driverRideIdParamSchema),
  getDriverRideByIdController
);
driverRideRouter.post(
  "/api/drivers/rides/:rideId/accept",
  validate(driverRideIdParamSchema),
  acceptIncomingRideController
);
driverRideRouter.post(
  "/api/drivers/rides/:rideId/reject",
  validate(driverRideIdParamSchema),
  rejectIncomingRideController
);
driverRideRouter.post(
  "/api/drivers/rides/accept",
  validate(acceptRideBodySchema),
  acceptIncomingRideByBodyController
);
driverRideRouter.post(
  "/api/drivers/rides/:rideId/arrived",
  validate(driverRideIdParamSchema),
  markRideArrivedAtPickupController
);
driverRideRouter.post(
  "/api/drivers/rides/:rideId/picked-up",
  validate(driverRideIdParamSchema),
  markRidePickedUpController
);
driverRideRouter.post(
  "/api/drivers/rides/:rideId/verify-otp",
  validate(verifyRideOtpSchema),
  verifyRideOtpController
);
driverRideRouter.post(
  "/api/drivers/rides/:rideId/in-transit",
  validate(driverRideIdParamSchema),
  markRideInTransitController
);
driverRideRouter.post(
  "/api/drivers/rides/:rideId/dropped",
  validate(dropReachedBodySchema),
  markRideDroppedController
);
driverRideRouter.post(
  "/api/drivers/rides/:rideId/verify-drop-otp",
  validate(verifyRideOtpSchema),
  verifyDropOtpController
);
driverRideRouter.post(
  "/api/drivers/rides/:rideId/cash-received",
  validate(driverRideIdParamSchema),
  confirmCashReceivedController
);
driverRideRouter.post(
  "/api/drivers/rides/:rideId/complete",
  validate(driverRideIdParamSchema),
  completeRideController
);
driverRideRouter.patch("/api/rides/:rideId/status", validate(updateRideStatusSchema), updateRideStatusController);

export default driverRideRouter;
