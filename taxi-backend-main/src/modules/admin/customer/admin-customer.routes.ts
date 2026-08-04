import { Router } from "express";
import {
  adminApproveCustomerAccountController,
  adminApproveCustomerByEmailController,
  getAdminCustomerDetailsController,
  getAdminCustomerRideHistoryController,
  getAdminCustomersController,
  updateAdminCustomerBlockStatusController,
} from "./admin-customer.controller";

const adminCustomerRouter = Router();

adminCustomerRouter.post("/approve-by-email", adminApproveCustomerByEmailController);
adminCustomerRouter.get("/", getAdminCustomersController);
adminCustomerRouter.patch("/:id/approve", adminApproveCustomerAccountController);
adminCustomerRouter.get("/:id", getAdminCustomerDetailsController);
adminCustomerRouter.patch("/:id/block", updateAdminCustomerBlockStatusController);
adminCustomerRouter.get("/:id/rides", getAdminCustomerRideHistoryController);

export default adminCustomerRouter;
