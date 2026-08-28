const express = require("express");
const {
  getAvailableRides,
  createRide,
  acceptRide,
  markArrived,
  verifyOtp,
  startRide,
  endRide,
  getRideRoute
} = require("../controllers/rideControllerCore");
const { requireAuth } = require("../middleware/authMiddleware");

const router = express.Router();

router.get("/available", requireAuth, getAvailableRides);
router.post("/request", createRide);
router.post("/:rideId/accept", requireAuth, acceptRide);
router.post("/:rideId/arrived", requireAuth, markArrived);
router.post("/:rideId/verify-otp", requireAuth, verifyOtp);
router.post("/:rideId/start", requireAuth, startRide);
router.post("/:rideId/end", requireAuth, endRide);
router.get("/:rideId/route", requireAuth, getRideRoute);

module.exports = router;
