import { Router } from "express";
import { requireAuth } from "../../middlewares/auth.middleware";
import { requireRole } from "../../middlewares/role.middleware";
import { validate } from "../../middlewares/validate.middleware";
import {
  customerChangePasswordController,
  customerForgotPasswordEmailController,
  customerForgotPasswordSetPasswordController,
  customerForgotPasswordVerifyOtpController,
  customerGetProfileController,
  customerLoginController,
  customerRegisterEmailController,
  customerSetPasswordController,
  customerUpdateProfileController,
  customerVerifyOtpController,
} from "./customer.controller";
import {
  changePasswordSchema,
  customerLoginSchema,
  forgotPasswordEmailSchema,
  forgotPasswordSetPasswordSchema,
  forgotPasswordVerifyOtpSchema,
  registerEmailSchema,
  setPasswordSchema,
  updateCustomerProfileSchema,
  verifyOtpSchema,
} from "./customer.validator";
import customerRideRouter from "./ride/ride.routes";

const customerRouter = Router();

customerRouter.post(
  "/api/customers/register/email",
  validate(registerEmailSchema),
  customerRegisterEmailController
);

customerRouter.post(
  "/api/customers/register/verify-otp",
  validate(verifyOtpSchema),
  customerVerifyOtpController
);

customerRouter.post(
  "/api/customers/register/set-password",
  validate(setPasswordSchema),
  customerSetPasswordController
);

customerRouter.post("/api/customers/login", validate(customerLoginSchema), customerLoginController);

customerRouter.post(
  "/api/customers/change-password",
  requireAuth,
  requireRole(["CUSTOMER"]),
  validate(changePasswordSchema),
  customerChangePasswordController
);

customerRouter.get(
  "/api/customers/profile",
  requireAuth,
  requireRole(["CUSTOMER"]),
  customerGetProfileController
);

customerRouter.patch(
  "/api/customers/profile",
  requireAuth,
  requireRole(["CUSTOMER"]),
  validate(updateCustomerProfileSchema),
  customerUpdateProfileController
);

customerRouter.post(
  "/api/customers/forgot-password/email",
  validate(forgotPasswordEmailSchema),
  customerForgotPasswordEmailController
);

customerRouter.post(
  "/api/customers/forgot-password/verify-otp",
  validate(forgotPasswordVerifyOtpSchema),
  customerForgotPasswordVerifyOtpController
);

customerRouter.post(
  "/api/customers/forgot-password/set-password",
  validate(forgotPasswordSetPasswordSchema),
  customerForgotPasswordSetPasswordController
);

customerRouter.use(customerRideRouter);

export default customerRouter;
