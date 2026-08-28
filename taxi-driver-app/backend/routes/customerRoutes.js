const express = require("express");
const { requireCustomerAuth } = require("../middleware/customerAuthMiddleware");
const {
  registerEmail,
  verifyRegisterOtp,
  setRegisterPassword,
  login,
  profile
} = require("../controllers/customerAuthController");
const {
  requestRide,
  confirmRide,
  activeRide,
  abandonStaleActiveRide,
  rideStatus,
  rideHistory,
  cancelRide,
  invoice,
  pickupLocations,
  dropLocations
} = require("../controllers/customerRideController");

const router = express.Router();

router.post("/register/email", registerEmail);
router.post("/register/verify-otp", verifyRegisterOtp);
router.post("/register/set-password", setRegisterPassword);
router.post("/login", login);
router.get("/profile", requireCustomerAuth, profile);

router.post("/rides/request", requireCustomerAuth, requestRide);
router.post("/rides/confirm", requireCustomerAuth, confirmRide);
router.post("/rides/active/abandon", requireCustomerAuth, abandonStaleActiveRide);
router.get("/rides/active", requireCustomerAuth, activeRide);
router.get("/rides/history", requireCustomerAuth, rideHistory);
router.get("/rides/pickup-locations", requireCustomerAuth, pickupLocations);
router.get("/rides/drop-locations", requireCustomerAuth, dropLocations);
router.get("/rides/:rideId/status", requireCustomerAuth, rideStatus);
router.get("/rides/:rideId/invoice", requireCustomerAuth, invoice);
router.post("/rides/:rideId/cancel", requireCustomerAuth, cancelRide);

module.exports = router;
