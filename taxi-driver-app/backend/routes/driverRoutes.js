const express = require("express");
const {
  register,
  login,
  getProfile,
  updateVehicleDetails,
  sendRegisterOtp,
  verifyRegisterOtp,
  setRegisterPassword,
  sendForgotOtp,
  verifyForgotOtp,
  setForgotPassword,
  updateDriverStatus,
  getWallet,
  getInvoice,
  getCashEarnings,
  getTotalEarnings,
  withdraw
} = require("../controllers/driverAuthController");
const { getEarningsSummary } = require("../controllers/earningsController");
const {
  getIncomingRides,
  getRideHistory,
  getActiveRide,
  acceptRide,
  markArrived,
  verifyOtp,
  startRide,
  endRide
} = require("../controllers/rideControllerCore");
const {
  markDroppedFlex,
  verifyDropOtpFlex,
  confirmCashReceivedFlex,
  completeRideFlex,
  getRideForDriver
} = require("../controllers/rideControllerFlex");
const {
  uploadMiddleware,
  listDocuments,
  uploadDocument,
  submitForReview
} = require("../controllers/driverDocumentController");
const { requireAuth } = require("../middleware/authMiddleware");

const router = express.Router();

router.post("/register", register);
router.post("/login", login);
router.get("/profile", requireAuth, getProfile);
router.patch("/vehicle", requireAuth, updateVehicleDetails);
router.post("/vehicle", requireAuth, updateVehicleDetails);
router.patch("/profile/vehicle", requireAuth, updateVehicleDetails);

// Compatibility routes for current Flutter app.
router.post("/register/email", sendRegisterOtp);
router.post("/register/verify-otp", verifyRegisterOtp);
router.post("/register/set-password", setRegisterPassword);

router.post("/forgot-password/email", sendForgotOtp);
router.post("/forgot-password/verify-otp", verifyForgotOtp);
router.post("/forgot-password/set-password", setForgotPassword);

router.get("/documents", requireAuth, listDocuments);
router.post("/documents/upload", requireAuth, uploadMiddleware, uploadDocument);
router.post("/documents/submit", requireAuth, submitForReview);

router.patch("/status", requireAuth, updateDriverStatus);
router.get("/wallet", requireAuth, getWallet);
router.get("/earnings/cash", requireAuth, getCashEarnings);
router.get("/earnings/total", requireAuth, getTotalEarnings);
router.get("/earnings/summary", requireAuth, getEarningsSummary);

router.get("/rides/incoming", requireAuth, getIncomingRides);
router.get("/rides/active", requireAuth, getActiveRide);
router.get("/rides/history", requireAuth, getRideHistory);
router.get("/rides/:rideId", requireAuth, getRideForDriver);
router.post("/rides/:rideId/accept", requireAuth, acceptRide);
router.post("/rides/:rideId/arrived", requireAuth, markArrived);
router.post("/rides/:rideId/verify-otp", requireAuth, verifyOtp);

router.post("/rides/:rideId/picked-up", requireAuth, startRide);
router.post("/rides/:rideId/in-transit", requireAuth, startRide);
router.post("/rides/:rideId/dropped", requireAuth, markDroppedFlex);
router.post("/rides/:rideId/verify-drop-otp", requireAuth, verifyDropOtpFlex);
router.post("/rides/:rideId/cash-received", requireAuth, confirmCashReceivedFlex);
router.post("/rides/:rideId/complete", requireAuth, completeRideFlex);

// Compatibility for invoice and wallet endpoints used by Flutter app.
router.get("/invoices/:rideId", requireAuth, getInvoice);
router.post("/wallet/withdraw", requireAuth, withdraw);

module.exports = router;
