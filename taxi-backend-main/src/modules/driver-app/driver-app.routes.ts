import { Router } from "express";
import { requireAuth } from "../../middlewares/auth.middleware";
import { requireRole } from "../../middlewares/role.middleware";
import { validate } from "../../middlewares/validate.middleware";
import {
  acceptRideRequestController,
  cancelRideController,
  changePasswordController,
  completeRideController,
  confirmPaymentController,
  createPaymentController,
  createSupportTicketController,
  forgotPasswordController,
  getAvailableRidesController,
  getCurrentRideController,
  calculateFareController,
  getDriverLocationController,
  getDriverProfileController,
  getDriverRatingController,
  getDriverStatusController,
  getEarningsSummaryController,
  getFareDetailsController,
  getNearbyDriversController,
  getNotificationsController,
  getRideHistoryController,
  getRideHistoryByIdController,
  getRideRequestDetailsController,
  getSettingsController,
  getSupportTicketsController,
  getWalletBalanceController,
  getWalletTransactionsController,
  goOfflineController,
  goOnlineController,
  loginController,
  logoutController,
  pickupConfirmController,
  refundPaymentController,
  registerDeviceController,
  registerDriverController,
  refreshTokenController,
  rejectRideRequestController,
  requestWalletWithdrawController,
  resetPasswordController,
  rideArrivedController,
  startRideController,
  submitRatingController,
  submitVehicleController,
  syncDriverLocationController,
  updateDriverProfileController,
  updateDriverVehicleController,
  updateSettingsController,
  uploadDriverPhotoController,
  uploadVehicleDocsController,
  verifyOtpController,
  walletAddMoneyController,
  getPassengerRatingController,
  resendOtpController,
  replySupportTicketController,
  getWalletWithdrawHistoryController,
  getDriverVehicleController,
} from "./driver-app.controller";
import {
  authForgotPasswordSchema,
  authLoginSchema,
  authRegisterSchema,
  authRefreshSchema,
  authResetPasswordSchema,
  authResendOtpSchema,
  authVerifyOtpSchema,
  changePasswordSchema,
  fareCalculateSchema,
  fareDetailsSchema,
  locationUpdateSchema,
  notificationRegisterSchema,
  paymentConfirmSchema,
  paymentCreateSchema,
  paymentRefundSchema,
  ratingSubmitSchema,
  rideActionSchema,
  rideIdParamSchema,
  rideRequestDetailsSchema,
  settingsUpdateSchema,
  supportCreateTicketSchema,
  supportReplyTicketSchema,
  updateDriverProfileSchema,
  uploadPhotoSchema,
  uploadVehicleDocsSchema,
  vehicleAddSchema,
  vehicleUpdateSchema,
  walletAddMoneySchema,
  walletWithdrawRequestSchema,
} from "./driver-app.validator";

const driverAppRouter = Router();

// Authentication
driverAppRouter.post("/auth/register", validate(authRegisterSchema), registerDriverController);
driverAppRouter.post("/auth/login", validate(authLoginSchema), loginController);
driverAppRouter.post("/auth/logout", requireAuth, logoutController);
driverAppRouter.post("/auth/refresh-token", validate(authRefreshSchema), refreshTokenController);
driverAppRouter.post("/auth/forgot-password", validate(authForgotPasswordSchema), forgotPasswordController);
driverAppRouter.post("/auth/reset-password", validate(authResetPasswordSchema), resetPasswordController);
driverAppRouter.post("/auth/verify-otp", validate(authVerifyOtpSchema), verifyOtpController);
driverAppRouter.post("/auth/resend-otp", validate(authResendOtpSchema), resendOtpController);

// Driver profile
const driverOnly = [requireAuth, requireRole(["DRIVER"])]
driverAppRouter.get("/driver/profile", ...driverOnly, getDriverProfileController);
driverAppRouter.put("/driver/profile", ...driverOnly, validate(updateDriverProfileSchema), updateDriverProfileController);
driverAppRouter.post("/driver/upload-photo", ...driverOnly, validate(uploadPhotoSchema), uploadDriverPhotoController);
driverAppRouter.post("/driver/change-password", ...driverOnly, validate(changePasswordSchema), changePasswordController);

// Vehicle
driverAppRouter.post("/driver/vehicle/add", ...driverOnly, validate(vehicleAddSchema), submitVehicleController);
driverAppRouter.get("/driver/vehicle", ...driverOnly, getDriverVehicleController);
driverAppRouter.put("/driver/vehicle/update", ...driverOnly, validate(vehicleUpdateSchema), updateDriverVehicleController);
driverAppRouter.post("/driver/vehicle/upload-docs", ...driverOnly, validate(uploadVehicleDocsSchema), uploadVehicleDocsController);

// Driver status
driverAppRouter.post("/driver/status/online", ...driverOnly, goOnlineController);
driverAppRouter.post("/driver/status/offline", ...driverOnly, goOfflineController);
driverAppRouter.get("/driver/status", ...driverOnly, getDriverStatusController);

// Location
driverAppRouter.post("/driver/location/update", ...driverOnly, validate(locationUpdateSchema), syncDriverLocationController);
driverAppRouter.get("/driver/location", ...driverOnly, getDriverLocationController);
driverAppRouter.get("/drivers/nearby", ...driverOnly, getNearbyDriversController);

// Ride request
driverAppRouter.get("/rides/available", ...driverOnly, getAvailableRidesController);
driverAppRouter.get("/rides/request/:id", ...driverOnly, validate(rideRequestDetailsSchema), getRideRequestDetailsController);
driverAppRouter.post("/rides/accept", ...driverOnly, validate(rideActionSchema), acceptRideRequestController);
driverAppRouter.post("/rides/reject", ...driverOnly, validate(rideActionSchema), rejectRideRequestController);
driverAppRouter.post("/rides/cancel", ...driverOnly, validate(rideActionSchema), cancelRideController);

// Ride lifecycle
driverAppRouter.post("/rides/arrived", ...driverOnly, validate(rideActionSchema), rideArrivedController);
driverAppRouter.post("/rides/start", ...driverOnly, validate(rideActionSchema), startRideController);
driverAppRouter.post("/rides/pickup-confirm", ...driverOnly, validate(rideActionSchema), pickupConfirmController);
driverAppRouter.post("/rides/complete", ...driverOnly, validate(rideActionSchema), completeRideController);
driverAppRouter.get("/rides/current", ...driverOnly, getCurrentRideController);

// Fare
driverAppRouter.post("/fare/calculate", ...driverOnly, validate(fareCalculateSchema), calculateFareController);
driverAppRouter.get("/fare/details/:ride_id", ...driverOnly, validate(fareDetailsSchema), getFareDetailsController);

// Wallet
driverAppRouter.get("/wallet/balance", ...driverOnly, getWalletBalanceController);
driverAppRouter.get("/wallet/transactions", ...driverOnly, getWalletTransactionsController);
driverAppRouter.post("/wallet/add-money", ...driverOnly, validate(walletAddMoneySchema), walletAddMoneyController);
driverAppRouter.post("/wallet/withdraw-request", ...driverOnly, validate(walletWithdrawRequestSchema), requestWalletWithdrawController);
driverAppRouter.get("/wallet/withdraw-history", ...driverOnly, getWalletWithdrawHistoryController);

// Payment
driverAppRouter.post("/payment/create", ...driverOnly, validate(paymentCreateSchema), createPaymentController);
driverAppRouter.post("/payment/confirm", ...driverOnly, validate(paymentConfirmSchema), confirmPaymentController);
driverAppRouter.post("/payment/refund", ...driverOnly, validate(paymentRefundSchema), refundPaymentController);

// Rating
driverAppRouter.post("/rating/submit", ...driverOnly, validate(ratingSubmitSchema), submitRatingController);
driverAppRouter.get("/rating/driver", ...driverOnly, getDriverRatingController);
driverAppRouter.get("/rating/passenger", ...driverOnly, getPassengerRatingController);

// Ride history
driverAppRouter.get("/rides/history", ...driverOnly, getRideHistoryController);
driverAppRouter.get("/rides/history/:ride_id", ...driverOnly, validate(rideIdParamSchema), getRideHistoryByIdController);
driverAppRouter.get("/rides/earnings/summary", ...driverOnly, getEarningsSummaryController);

// Notifications
driverAppRouter.post("/notifications/register-device", ...driverOnly, validate(notificationRegisterSchema), registerDeviceController);
driverAppRouter.get("/notifications/list", ...driverOnly, getNotificationsController);

// Support
driverAppRouter.post("/support/ticket/create", ...driverOnly, validate(supportCreateTicketSchema), createSupportTicketController);
driverAppRouter.get("/support/tickets", ...driverOnly, getSupportTicketsController);
driverAppRouter.post("/support/ticket/reply", ...driverOnly, validate(supportReplyTicketSchema), replySupportTicketController);

// Settings
driverAppRouter.get("/settings", ...driverOnly, getSettingsController);
driverAppRouter.post("/settings/update", ...driverOnly, validate(settingsUpdateSchema), updateSettingsController);

export default driverAppRouter;
