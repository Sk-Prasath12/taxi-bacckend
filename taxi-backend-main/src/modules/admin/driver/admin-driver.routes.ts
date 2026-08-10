import { Router } from "express";
import { getVerifiedDriversController } from "../admin.controller";
import { adminListDriversVerificationController } from "../../driver-documents/driver-document.controller";
import {
  adminApproveDriverAccountController,
  adminApproveDriverByEmailController,
  getAdminDriverDetailsController,
  getAdminDriverRideDetailsController,
  getAdminDriverRideHistoryController,
  getAdminDriversController,
  updateAdminDriverBlockStatusController,
} from "./admin-driver.controller";

const adminDriverRouter = Router();

adminDriverRouter.post("/approve-by-email", adminApproveDriverByEmailController);
adminDriverRouter.get("/verification", adminListDriversVerificationController);
adminDriverRouter.get("/pending", adminListDriversVerificationController);
adminDriverRouter.get("/verified", getVerifiedDriversController);
adminDriverRouter.get("/", getAdminDriversController);
adminDriverRouter.patch("/:id/approve", adminApproveDriverAccountController);
adminDriverRouter.get("/:id/rides/:rideId", getAdminDriverRideDetailsController);
adminDriverRouter.get("/:id/rides", getAdminDriverRideHistoryController);
adminDriverRouter.patch("/:id/block", updateAdminDriverBlockStatusController);
adminDriverRouter.get("/:id", getAdminDriverDetailsController);

export default adminDriverRouter;
