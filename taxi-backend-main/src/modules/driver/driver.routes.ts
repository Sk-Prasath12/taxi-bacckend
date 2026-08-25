import { Router } from "express";
import { requireAuth } from "../../middlewares/auth.middleware";
import { requireRole } from "../../middlewares/role.middleware";
import { validate } from "../../middlewares/validate.middleware";
import {
  driverLoginSchema,
  driverRegisterEmailSchema,
  driverRegisterSchema,
  driverRefreshTokenSchema,
  driverSetPasswordSchema,
  driverStatusSchema,
  driverVerifyOtpSchema,
  driverForgotPasswordEmailSchema,
  driverForgotPasswordVerifyOtpSchema,
  driverForgotPasswordSetPasswordSchema,
} from "./driver.validator";
import {
  driverGetProfileController,
  driverGetWalletController,
  driverGetCashEarningsController,
  driverGetEarningsSummaryController,
  driverGetTotalEarningsController,
  driverLoginController,
  driverRefreshTokenController,
  driverRegisterController,
  driverRegisterEmailController,
  driverSetPasswordController,
  driverForgotPasswordEmailController,
  driverForgotPasswordVerifyOtpController,
  driverForgotPasswordSetPasswordController,
  driverUpdateStatusController,
  driverUpdateVehicleController,
  driverVerifyOtpController,
} from "./driver.controller";
import driverRideRouter from "./ride/driver-ride.routes";

const driverRouter = Router();

driverRouter.post("/api/drivers/register/email", validate(driverRegisterEmailSchema), driverRegisterEmailController);
driverRouter.post("/api/drivers/register", validate(driverRegisterSchema), driverRegisterController);
driverRouter.post("/api/drivers/register/verify-otp", validate(driverVerifyOtpSchema), driverVerifyOtpController);
driverRouter.post("/api/drivers/register/set-password", validate(driverSetPasswordSchema), driverSetPasswordController);
driverRouter.post("/api/drivers/auth/refresh", validate(driverRefreshTokenSchema), driverRefreshTokenController);
driverRouter.post("/api/drivers/forgot-password/email", validate(driverForgotPasswordEmailSchema), driverForgotPasswordEmailController);
driverRouter.post(
  "/api/drivers/forgot-password/verify-otp",
  validate(driverForgotPasswordVerifyOtpSchema),
  driverForgotPasswordVerifyOtpController
);
driverRouter.post(
  "/api/drivers/forgot-password/set-password",
  validate(driverForgotPasswordSetPasswordSchema),
  driverForgotPasswordSetPasswordController
);
driverRouter.post("/api/drivers/login", validate(driverLoginSchema), driverLoginController);

driverRouter.get("/api/drivers/profile", requireAuth, requireRole(["DRIVER"]), driverGetProfileController);
driverRouter.patch(
  "/api/drivers/vehicle",
  requireAuth,
  requireRole(["DRIVER"]),
  driverUpdateVehicleController
);
driverRouter.post(
  "/api/drivers/vehicle",
  requireAuth,
  requireRole(["DRIVER"]),
  driverUpdateVehicleController
);
driverRouter.patch(
  "/api/drivers/profile/vehicle",
  requireAuth,
  requireRole(["DRIVER"]),
  driverUpdateVehicleController
);
driverRouter.get("/api/drivers/wallet", requireAuth, requireRole(["DRIVER"]), driverGetWalletController);
driverRouter.get(
  "/api/drivers/earnings/cash",
  requireAuth,
  requireRole(["DRIVER"]),
  driverGetCashEarningsController
);
driverRouter.get(
  "/api/drivers/earnings/total",
  requireAuth,
  requireRole(["DRIVER"]),
  driverGetTotalEarningsController
);
driverRouter.get(
  "/api/drivers/earnings/summary",
  requireAuth,
  requireRole(["DRIVER"]),
  driverGetEarningsSummaryController
);
driverRouter.patch(
  "/api/drivers/status",
  requireAuth,
  requireRole(["DRIVER"]),
  validate(driverStatusSchema),
  driverUpdateStatusController
);

driverRouter.use("/api/drivers/rides", requireAuth, requireRole(["DRIVER"]));
driverRouter.use(driverRideRouter);

export default driverRouter;
