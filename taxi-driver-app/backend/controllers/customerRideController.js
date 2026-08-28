const { Ride, RIDE_STATUS } = require("../models/Ride");
const Driver = require("../models/Driver");
const VehicleType = require("../models/VehicleType");
const Notification = require("../models/Notification");
const socketUtils = require("../utils/socket");
const { generateOtp } = require("../utils/otp");
const { estimateBookingFare, calcTripFare, CANCELLATION_FEE } = require("../utils/fareCalculator");
const { findDriverIdsNearPickup, resolveNearbyDriverIds, NEARBY_KM } = require("../services/nearbyRideDispatch");

const resolvePaymentFields = (paymentModeRaw, paymentMethodRaw) => {
  const modeIn = String(paymentModeRaw || paymentMethodRaw || "CASH").toUpperCase();
  let method = String(paymentMethodRaw || paymentModeRaw || "CASH").toUpperCase();
  const digitalMethods = ["UPI", "GPAY", "PHONEPE", "PAYTM", "CARD", "RAZORPAY"];
  if (modeIn === "ONLINE" || digitalMethods.includes(method)) {
    if (method === "ONLINE" || method === "CASH") method = "RAZORPAY";
    if (method === "UPI" || digitalMethods.includes(method)) {
      return { paymentMode: "ONLINE", method };
    }
    return { paymentMode: "ONLINE", method: "RAZORPAY" };
  }
  return { paymentMode: "CASH", method: "CASH" };
};

const kmDistance = (a, b) => {
  const toRad = (deg) => (deg * Math.PI) / 180;
  const R = 6371;
  const dLat = toRad((b.lat || 0) - (a.lat || 0));
  const dLng = toRad((b.lng || 0) - (a.lng || 0));
  const h =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(a.lat || 0)) * Math.cos(toRad(b.lat || 0)) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
  return 2 * R * Math.asin(Math.sqrt(h));
};

const requestRide = async (req, res) => {
  const b = req.body || {};
  if (!b.pickup_lat || !b.pickup_lng || !b.drop_lat || !b.drop_lng || !b.vehicle_type_id) {
    return res.status(400).json({ success: false, message: "pickup/drop coordinates and vehicle_type_id are required." });
  }

  const vehicleType = await VehicleType.findById(b.vehicle_type_id);
  if (!vehicleType) {
    return res.status(400).json({ success: false, message: "Invalid vehicle type id." });
  }

  const distanceKm = kmDistance(
    { lat: Number(b.pickup_lat), lng: Number(b.pickup_lng) },
    { lat: Number(b.drop_lat), lng: Number(b.drop_lng) }
  );
  const fare = estimateBookingFare({
    distanceKm,
    baseFare: vehicleType.baseFare,
    perKm: vehicleType.perKmFare
  });
  const { paymentMode, method } = resolvePaymentFields(b.payment_mode, b.payment_method);
  const ride = await Ride.create({
    customerId: req.customer._id.toString(),
    customerName: req.customer.name,
    customerPhone: req.customer.phone,
    customerEmail: req.customer.email,
    pickup: { lat: Number(b.pickup_lat), lng: Number(b.pickup_lng) },
    pickupAddress: b.pickup_address || "",
    drop: { lat: Number(b.drop_lat), lng: Number(b.drop_lng) },
    dropAddress: b.drop_address || "",
    vehicleTypeId: String(b.vehicle_type_id),
    paymentMode,
    paymentStatus: "PENDING",
    payment: { method, status: "PENDING" },
    distance: `${distanceKm.toFixed(1)} km`,
    actual_distance_km: Number(distanceKm.toFixed(2)),
    fare,
    otp: generateOtp(),
    status: RIDE_STATUS.REQUESTED
  });

  await Notification.create({
    userType: "customer",
    userId: req.customer._id.toString(),
    title: "Ride requested",
    message: `Your ride request ${ride._id.toString()} has been created.`
  });

  return res.status(201).json({
    success: true,
    ride_id: ride._id.toString(),
    fare: ride.fare,
    fare_breakdown: {
      note: "1st minute free, then ₹5/min waiting/time charge",
      cancellation_fee: CANCELLATION_FEE,
      driver_receives_cancellation_fee: true
    },
    payment_mode: ride.paymentMode,
    payment_status: ride.paymentStatus
  });
};

const buildNewRidePayload = (ride) => ({
  rideId: ride._id.toString(),
  ride_id: ride._id.toString(),
  id: ride._id.toString(),
  customerName: ride.customerName,
  customer_name: ride.customerName,
  pickup: ride.pickup,
  drop: ride.drop,
  pickupAddress: ride.pickupAddress,
  dropAddress: ride.dropAddress,
  fare: ride.fare,
  distance: ride.distance,
  distance_km: ride.actual_distance_km,
  payment_mode: ride.paymentMode,
  payment_method: ride.payment?.method,
  status: ride.status,
  nearby_km: NEARBY_KM
});

const emitNewRideToDrivers = async (ride) => {
  const payload = buildNewRidePayload(ride);
  const nearbyIds = await resolveNearbyDriverIds(ride.pickup, NEARBY_KM);

  const notifyDriver = (driverId) => {
    socketUtils.emitToDriver(driverId, "new_ride", payload);
    socketUtils.emitToDriver(driverId, "ride:new", payload);
    socketUtils.emitToDriver(driverId, "ride:request", payload);
  };

  if (nearbyIds === null) {
    await socketUtils.emitToAllDrivers("new_ride", payload);
    await socketUtils.emitToAllDrivers("ride:new", payload);
    await socketUtils.emitToAllDrivers("ride:request", payload);
    return;
  }

  nearbyIds.forEach(notifyDriver);
};

const emitRideCancelled = async (ride) => {
  const payload = {
    ...buildNewRidePayload(ride),
    status: RIDE_STATUS.CANCELLED,
    ride_id: ride._id.toString(),
    message: "Ride cancelled by customer"
  };
  await socketUtils.emitToAllDrivers("ride_cancelled", payload);
  await socketUtils.emitToAllDrivers("ride:cancelled", payload);
  socketUtils.emitToRide(ride._id.toString(), "ride_cancelled", payload);
  socketUtils.emitToCustomer(ride.customerId, "ride_status_update", payload);
  if (ride.driverId) {
    socketUtils.emitToDriver(ride.driverId.toString(), "ride_cancelled", payload);
    socketUtils.emitToDriver(ride.driverId.toString(), "ride:cancelled", payload);
    socketUtils.emitToDriver(ride.driverId.toString(), "ride:update", payload);
  }
};

const confirmRide = async (req, res) => {
  const ride = await Ride.findOne({ _id: req.body.ride_id, customerId: req.customer._id.toString() });
  if (!ride) return res.status(404).json({ success: false, message: "Ride not found." });
  if (ride.status !== RIDE_STATUS.REQUESTED) {
    return res.status(400).json({
      success: false,
      message: `Ride cannot be confirmed (status: ${ride.status}).`
    });
  }
  if (req.body.payment_mode || req.body.payment_method) {
    const { paymentMode, method } = resolvePaymentFields(
      req.body.payment_mode || ride.paymentMode,
      req.body.payment_method || ride.payment?.method
    );
    ride.paymentMode = paymentMode;
    ride.payment = ride.payment || {};
    ride.payment.method = method;
  }
  ride.paymentStatus = "PENDING";
  const firstDispatch = !ride.dispatchedAt;
  ride.dispatchedAt = ride.dispatchedAt || new Date();
  await ride.save();
  if (firstDispatch) {
    await emitNewRideToDrivers(ride);
  }
  return res.json({
    success: true,
    ride_id: ride._id.toString(),
    otp: ride.otp,
    status: ride.status,
    fare: ride.fare,
    distance: ride.distance,
    payment_mode: ride.paymentMode,
    ride: {
      id: ride._id.toString(),
      ride_id: ride._id.toString(),
      otp: ride.otp,
      dispatchedAt: ride.dispatchedAt,
      fare: ride.fare,
      distance: ride.distance,
      payment_mode: ride.paymentMode,
      status: ride.status
    }
  });
};

const activeRide = async (req, res) => {
  const ride = await Ride.findOne({
    customerId: req.customer._id.toString(),
    status: { $in: [RIDE_STATUS.REQUESTED, RIDE_STATUS.ACCEPTED, RIDE_STATUS.ARRIVED, RIDE_STATUS.STARTED] }
  }).sort({ createdAt: -1 });
  return res.json({ success: true, ride: ride || null });
};

const abandonStaleActiveRide = async (req, res) => {
  const customerId = req.customer._id.toString();
  const open = await Ride.find({
    customerId,
    status: {
      $in: [RIDE_STATUS.REQUESTED, RIDE_STATUS.ACCEPTED, RIDE_STATUS.ARRIVED, RIDE_STATUS.STARTED]
    }
  });
  for (const ride of open) {
    ride.status = RIDE_STATUS.CANCELLED;
    ride.cancelledAt = new Date();
    await ride.save();
    await emitRideCancelled(ride);
  }
  return res.json({
    success: true,
    message: "Previous open rides cleared.",
    cleared: open.length
  });
};

const rideStatus = async (req, res) => {
  const ride = await Ride.findOne({ _id: req.params.rideId, customerId: req.customer._id.toString() });
  if (!ride) return res.status(404).json({ success: false, message: "Ride not found." });
  return res.json({ success: true, ride });
};

const rideHistory = async (req, res) => {
  const rides = await Ride.find({
    customerId: req.customer._id.toString(),
    status: { $in: [RIDE_STATUS.COMPLETED, RIDE_STATUS.CANCELLED] }
  }).sort({ createdAt: -1 });
  return res.json({ success: true, data: rides });
};

const cancelRide = async (req, res) => {
  const ride = await Ride.findOne({
    _id: req.params.rideId,
    customerId: req.customer._id.toString(),
    status: {
      $in: [
        RIDE_STATUS.REQUESTED,
        RIDE_STATUS.ACCEPTED,
        RIDE_STATUS.ARRIVED,
        RIDE_STATUS.STARTED
      ]
    }
  });
  if (!ride) {
    return res.status(400).json({ success: false, message: "Ride cannot be cancelled in current state." });
  }
  const wasRequested = ride.status === RIDE_STATUS.REQUESTED;
  ride.status = RIDE_STATUS.CANCELLED;
  ride.cancelledAt = new Date();
  ride.cancellationFee = CANCELLATION_FEE;
  if (wasRequested) {
    ride.fare = CANCELLATION_FEE;
  }
  await ride.save();
  if (ride.driverId) {
    await Driver.findByIdAndUpdate(ride.driverId, { status: "online" }).catch(() => {});
  }
  await emitRideCancelled(ride);
  return res.json({
    success: true,
    message: "Ride cancelled.",
    ride_id: ride._id.toString(),
    cancellation_fee: CANCELLATION_FEE,
    driver_payout: CANCELLATION_FEE,
    note: "Cancellation fee is paid to the assigned driver when applicable."
  });
};

const invoice = async (req, res) => {
  const ride = await Ride.findOne({ _id: req.params.rideId, customerId: req.customer._id.toString() });
  if (!ride) return res.status(404).json({ success: false, message: "Ride not found." });
  const tax = Number((ride.fare * 0.05).toFixed(2));
  return res.json({
    success: true,
    data: {
      ride_id: ride._id.toString(),
      fare: ride.fare,
      tax,
      total: Number((ride.fare + tax).toFixed(2)),
      payment_mode: ride.paymentMode,
      payment_status: ride.paymentStatus
    }
  });
};

const pickupLocations = async (req, res) => {
  const rides = await Ride.find({ customerId: req.customer._id.toString() }).sort({ createdAt: -1 }).limit(10);
  const data = rides.map((r) => ({ lat: r.pickup?.lat, lng: r.pickup?.lng, address: r.pickupAddress || "" }));
  return res.json({ success: true, data });
};

const dropLocations = async (req, res) => {
  const rides = await Ride.find({ customerId: req.customer._id.toString() }).sort({ createdAt: -1 }).limit(10);
  const data = rides.map((r) => ({ lat: r.drop?.lat, lng: r.drop?.lng, address: r.dropAddress || "" }));
  return res.json({ success: true, data });
};

module.exports = {
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
};
