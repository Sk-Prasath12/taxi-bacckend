const { generateOtp } = require("../utils/otp");
const socketUtils = require("../utils/socket");
const Notification = require("../models/Notification");
const mongoose = require("mongoose");
const { Ride, RIDE_STATUS } = require("../models/Ride");
const Driver = require("../models/Driver");
const {
  toRidePayload,
  createRideRequest,
  getIncomingRidesForDriver,
  getRideHistoryForDriver,
  acceptRideAtomic,
  transitionRide,
  findRideById
} = require("../services/rideService");
const { stampRideEarnings } = require("../services/rideEarnings");
const { driverCanAcceptRides, isVerificationRequired } = require("../services/driverVerification");
const { NEARBY_KM } = require("../services/nearbyRideDispatch");

function ensureDriverOwnership(ride, driverId) {
  return ride.driverId && ride.driverId.toString() === driverId.toString();
}

function pickupOtpMatches(stored, input) {
  const a = String(stored ?? "").trim();
  const b = String(input ?? "").trim();
  if (!a || !b) return false;
  if (a === b) return true;
  const na = Number(a);
  const nb = Number(b);
  if (Number.isFinite(na) && Number.isFinite(nb) && na === nb) return true;
  return false;
}

async function getAvailableRides(req, res) {
  const lat = req.query.lat;
  const lng = req.query.lng;
  const rides = await getIncomingRidesForDriver(req.driver._id, { lat, lng });
  return res.json({
    success: true,
    nearby_km: NEARBY_KM,
    data: rides.map(toRidePayload)
  });
}

async function createRide(req, res) {
  const body = req.body || {};
  const customerId = body.customerId;
  if (!customerId || !body.pickup || !body.drop) {
    return res.status(400).json({ success: false, message: "customerId, pickup and drop are required." });
  }

  const ride = await createRideRequest({
    customerId,
    customerName: body.customerName || "Passenger",
    pickup: body.pickup,
    drop: body.drop,
    distance: body.distance || "",
    otp: generateOtp()
  });

  const ridePayload = toRidePayload(ride);
  await socketUtils.emitToAllDrivers("ride:new", ridePayload);
  await Notification.create({
    userType: "customer",
    userId: String(customerId),
    title: "Ride requested",
    message: `Ride ${ride._id.toString()} requested successfully.`
  });
  return res.status(201).json({ success: true, ride: ridePayload });
}

async function acceptRide(req, res) {
  const { rideId } = req.params;
  if (!mongoose.Types.ObjectId.isValid(rideId)) {
    return res.status(400).json({ success: false, message: "Invalid ride id." });
  }

  if (!driverCanAcceptRides(req.driver)) {
    return res.status(403).json({
      success: false,
      message:
        req.driver.driver_verification_status === "PENDING"
          ? "Waiting for admin to approve your driver account."
          : "Your driver account is not approved yet.",
      driver_verification_status: req.driver.driver_verification_status,
      is_driver_verified: req.driver.is_driver_verified,
      verification_required: isVerificationRequired()
    });
  }

  const driverId = req.driver._id;

  let ride = await Ride.findOne({
    _id: rideId,
    driverId,
    status: { $in: [RIDE_STATUS.ACCEPTED, RIDE_STATUS.ARRIVED, RIDE_STATUS.STARTED] }
  });
  if (ride) {
    const payload = toRidePayload(ride);
    return res.json({ success: true, message: "Ride already accepted.", ride: payload });
  }

  ride = await acceptRideAtomic({ rideId, driverId });
  if (!ride) {
    const existing = await Ride.findById(rideId);
    if (!existing) {
      return res.status(404).json({ success: false, message: "Ride not found." });
    }
    if (existing.status !== RIDE_STATUS.REQUESTED) {
      return res.status(409).json({
        success: false,
        message: `Ride is not available (status: ${existing.status}).`
      });
    }
    return res.status(409).json({
      success: false,
      message: "Ride has already been accepted by another driver."
    });
  }
  const payload = toRidePayload(ride);
  payload.driver_name = req.driver.name;
  payload.driver = {
    id: req.driver._id.toString(),
    name: req.driver.name,
    phone: req.driver.phone
  };
  socketUtils.emitToDriver(req.driver._id.toString(), "ride:update", payload);
  socketUtils.emitToCustomer(ride.customerId.toString(), "ride:accepted", payload);
  socketUtils.emitToCustomer(ride.customerId.toString(), "ride:update", payload);
  await socketUtils.emitToAllDrivers("ride:update", {
    ...payload,
    status: RIDE_STATUS.ACCEPTED,
    taken: true,
    message: "Ride accepted by another driver"
  });
  await Notification.create({
    userType: "customer",
    userId: ride.customerId.toString(),
    title: "Ride accepted",
    message: "Driver has accepted your ride."
  });
  return res.json({ success: true, ride: payload });
}

async function markArrived(req, res) {
  const { rideId } = req.params;
  const driverId = req.driver._id;

  let ride = await Ride.findOne({
    _id: rideId,
    driverId,
    status: RIDE_STATUS.ARRIVED
  });
  if (ride) {
    const payload = toRidePayload(ride);
    return res.json({ success: true, message: "Already at pickup.", ride: payload });
  }

  ride = await transitionRide({
    rideId,
    driverId,
    currentStatus: RIDE_STATUS.ACCEPTED,
    nextStatus: RIDE_STATUS.ARRIVED,
    extraUpdates: { arrivedAt: new Date() }
  });
  if (!ride) {
    const existing = await Ride.findOne({ _id: rideId, driverId });
    if (!existing) {
      return res.status(404).json({ success: false, message: "Ride not found." });
    }
    return res.status(400).json({
      success: false,
      message: `Cannot mark arrived (status: ${existing.status}). Accept the ride first.`
    });
  }
  const payload = toRidePayload(ride);
  const arrivedEvent = {
    ride_id: ride._id.toString(),
    status: "ARRIVED",
    otp: ride.otp,
    ride: payload
  };
  socketUtils.emitToDriver(req.driver._id.toString(), "ride:update", payload);
  socketUtils.emitToCustomer(ride.customerId.toString(), "ride:update", payload);
  socketUtils.emitToCustomer(ride.customerId.toString(), "pickup_otp_generated", arrivedEvent);
  socketUtils.emitToCustomer(ride.customerId.toString(), "driver_arrived", arrivedEvent);
  socketUtils.emitToCustomer(ride.customerId.toString(), "ride_status_update", arrivedEvent);
  await Notification.create({
    userType: "customer",
    userId: ride.customerId.toString(),
    title: "Driver arrived",
    message: "Your driver reached pickup location."
  });
  return res.json({ success: true, ride: payload, otp: ride.otp });
}

async function verifyOtp(req, res) {
  const rawOtp = req.body.otp;
  if (rawOtp == null || String(rawOtp).trim() === "") {
    return res.status(400).json({ success: false, message: "OTP is required." });
  }
  const otpNorm = String(rawOtp).trim();

  const ride = await findRideById(req.params.rideId);
  if (!ride || ride.driverId?.toString() !== req.driver._id.toString()) {
    return res.status(400).json({ success: false, message: "Ride not found for this driver." });
  }

  if (ride.status === RIDE_STATUS.ACCEPTED) {
    ride.status = RIDE_STATUS.ARRIVED;
    ride.arrivedAt = ride.arrivedAt || new Date();
    await ride.save();
  }

  if (ride.status !== RIDE_STATUS.ARRIVED && ride.status !== RIDE_STATUS.STARTED) {
    return res.status(400).json({
      success: false,
      message: "Mark arrived at pickup before verifying OTP."
    });
  }

  if (ride.otpVerifiedAt) {
    return res.json({ success: true, message: "OTP already verified.", ride: toRidePayload(ride) });
  }

  if (!pickupOtpMatches(ride.otp, otpNorm)) {
    return res.status(400).json({ success: false, message: "Invalid OTP." });
  }

  ride.otpVerifiedAt = new Date();
  await ride.save();
  return res.json({ success: true, ride: toRidePayload(ride) });
}

async function startRide(req, res) {
  const ride = await findRideById(req.params.rideId);
  if (!ride || ride.driverId?.toString() !== req.driver._id.toString()) {
    return res.status(404).json({ success: false, message: "Ride not found." });
  }
  if (ride.status === RIDE_STATUS.STARTED) {
    return res.json({ success: true, message: "Trip already started.", ride: toRidePayload(ride) });
  }
  if (ride.status !== RIDE_STATUS.ARRIVED || !ride.otpVerifiedAt) {
    return res.status(400).json({ success: false, message: "Verify pickup OTP before starting ride." });
  }
  ride.status = RIDE_STATUS.STARTED;
  ride.startedAt = new Date();
  await ride.save();
  const payload = toRidePayload(ride);
  socketUtils.emitToDriver(req.driver._id.toString(), "ride:update", payload);
  socketUtils.emitToCustomer(ride.customerId.toString(), "ride:update", payload);
  await Notification.create({
    userType: "customer",
    userId: ride.customerId.toString(),
    title: "Ride started",
    message: "Your ride has started."
  });
  return res.json({ success: true, ride: payload });
}

async function endRide(req, res) {
  const ride = await transitionRide({
    rideId: req.params.rideId,
    driverId: req.driver._id,
    currentStatus: RIDE_STATUS.STARTED,
    nextStatus: RIDE_STATUS.COMPLETED,
    extraUpdates: {
      completedAt: new Date(),
      fare: Number(req.body?.fare || 0)
    }
  });
  if (!ride) {
    return res.status(400).json({ success: false, message: "Ride cannot be completed." });
  }
  stampRideEarnings(ride);
  await ride.save();
  const payload = toRidePayload(ride);
  socketUtils.emitToDriver(req.driver._id.toString(), "ride:update", payload);
  socketUtils.emitToCustomer(ride.customerId.toString(), "ride:update", payload);
  socketUtils.emitToCustomer(ride.customerId.toString(), "ride:payment", {
    rideId: ride._id.toString(),
    fare: ride.fare,
    currency: "INR"
  });
  await Notification.create({
    userType: "customer",
    userId: ride.customerId.toString(),
    title: "Ride completed",
    message: "Ride completed. Please proceed with payment."
  });
  return res.json({ success: true, ride: payload });
}

async function getRideRoute(req, res) {
  var stage = String(req.query.stage || "pickup").toLowerCase();
  if (!["pickup", "drop"].includes(stage)) {
    return res.status(400).json({ success: false, message: "stage must be pickup or drop." });
  }

  var ride = await findRideById(req.params.rideId);
  if (!ride) {
    return res.status(404).json({ success: false, message: "Ride not found." });
  }
  if (!ensureDriverOwnership(ride, req.driver._id)) {
    return res.status(403).json({ success: false, message: "Ride is assigned to another driver." });
  }

  var currentLat = Number(req.query.currentLat);
  var currentLng = Number(req.query.currentLng);
  if (Number.isNaN(currentLat) || Number.isNaN(currentLng)) {
    return res.status(400).json({
      success: false,
      message: "currentLat and currentLng query params are required."
    });
  }

  var target = stage === "pickup" ? ride.pickup : ride.drop;
  if (!target || typeof target.lat !== "number" || typeof target.lng !== "number") {
    return res.status(400).json({
      success: false,
      message: "Ride location coordinates are not available for this stage."
    });
  }

  var osrmUrl =
    "https://router.project-osrm.org/route/v1/driving/" +
    currentLng +
    "," +
    currentLat +
    ";" +
    target.lng +
    "," +
    target.lat +
    "?overview=full&geometries=geojson&steps=true";

  var response = await fetch(osrmUrl);
  if (!response.ok) {
    return res.status(502).json({ success: false, message: "Unable to fetch route from OSRM." });
  }

  var data = await response.json();
  if (!data.routes || data.routes.length === 0) {
    return res.status(404).json({ success: false, message: "No route found." });
  }

  var route = data.routes[0];
  return res.json({
    success: true,
    data: {
      distanceMeters: route.distance,
      durationSeconds: route.duration,
      geometry: route.geometry,
      destination: target
    }
  });
}

async function getIncomingRides(req, res) {
  const lat = req.query.lat;
  const lng = req.query.lng;
  const rides = await getIncomingRidesForDriver(req.driver._id, { lat, lng });
  return res.json({
    success: true,
    nearby_km: NEARBY_KM,
    data: rides.map(toRidePayload)
  });
}

async function getRideHistory(req, res) {
  const rides = await getRideHistoryForDriver(req.driver._id);
  return res.json({ success: true, data: rides.map(toRidePayload) });
}

async function getActiveRide(req, res) {
  const ride = await Ride.findOne({
    driverId: req.driver._id,
    status: {
      $in: [
        RIDE_STATUS.ACCEPTED,
        RIDE_STATUS.ARRIVED,
        RIDE_STATUS.STARTED,
        RIDE_STATUS.COMPLETED_PENDING_PAYMENT
      ]
    }
  }).sort({ updatedAt: -1 });

  if (!ride) {
    return res.json({ success: true, ride: null });
  }
  const payload = toRidePayload(ride);
  return res.json({ success: true, ride: payload });
}

module.exports = {
  getAvailableRides: getAvailableRides,
  createRide: createRide,
  acceptRide: acceptRide,
  markArrived: markArrived,
  verifyOtp: verifyOtp,
  startRide: startRide,
  endRide: endRide,
  getRideRoute: getRideRoute,
  getIncomingRides: getIncomingRides,
  getRideHistory: getRideHistory,
  getActiveRide: getActiveRide
};
