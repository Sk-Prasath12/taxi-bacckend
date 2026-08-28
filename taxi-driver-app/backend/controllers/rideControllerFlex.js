const socketUtils = require("../utils/socket");
const Notification = require("../models/Notification");
const { Ride, RIDE_STATUS } = require("../models/Ride");
const { findRideById, toRidePayload } = require("../services/rideService");
const { calcKmOnlyFare, PER_KM_DEFAULT } = require("../utils/fareCalculator");

const { creditDriverWalletForRide } = require("../services/walletService");
const { stampRideEarnings } = require("../services/rideEarnings");

const toFlexPayload = (ride) => ({
  ride_id: ride._id.toString(),
  rideId: ride._id.toString(),
  status: ride.status,
  fare: ride.fare,
  payment_status: ride.paymentStatus,
  payment_mode: ride.paymentMode,
  drop_otp: ride.drop_otp,
  drop_otp_verified: ride.drop_otp_verified,
  drop_reached: ride.drop_reached,
  customer_name: ride.customerName,
  ride: {
    id: ride._id.toString(),
    ride_id: ride._id.toString(),
    status: ride.status,
    fare: ride.fare,
    payment_status: ride.paymentStatus,
    payment_mode: ride.paymentMode
  }
});

const emitPaymentPending = (ride) => {
  const payload = toFlexPayload(ride);
  socketUtils.emitToCustomer(ride.customerId, "payment_pending", payload);
  socketUtils.emitToCustomer(ride.customerId, "ride_status_update", payload);
  socketUtils.emitToRide(ride._id.toString(), "payment_pending", payload);
  if (ride.driverId) {
    socketUtils.emitToDriver(ride.driverId.toString(), "payment_pending", payload);
  }
};

const emitPaymentSuccess = (ride, extra = {}) => {
  const payload = { ...toFlexPayload(ride), amount: ride.fare, ...extra };
  socketUtils.emitToCustomer(ride.customerId, "payment_success", payload);
  socketUtils.emitToRide(ride._id.toString(), "payment_success", payload);
  if (ride.driverId) {
    socketUtils.emitToDriver(ride.driverId.toString(), "payment_success", payload);
    socketUtils.emitToDriver(ride.driverId.toString(), "wallet_updated", payload);
  }
};

const emitPaymentFailed = (ride, message) => {
  const payload = { ...toFlexPayload(ride), message };
  socketUtils.emitToCustomer(ride.customerId, "payment_failed", payload);
  socketUtils.emitToRide(ride._id.toString(), "payment_failed", payload);
  if (ride.driverId) {
    socketUtils.emitToDriver(ride.driverId.toString(), "payment_failed", payload);
  }
};

const emitRideCompleted = (ride) => {
  const payload = toFlexPayload(ride);
  socketUtils.emitToCustomer(ride.customerId, "ride_completed", payload);
  socketUtils.emitToRide(ride._id.toString(), "ride_completed", payload);
  if (ride.driverId) {
    socketUtils.emitToDriver(ride.driverId.toString(), "ride_completed", payload);
  }
};

function haversineKm(a, b) {
  if (!a?.lat || !a?.lng || !b?.lat || !b?.lng) return 0;
  const R = 6371;
  const dLat = ((b.lat - a.lat) * Math.PI) / 180;
  const dLng = ((b.lng - a.lng) * Math.PI) / 180;
  const lat1 = (a.lat * Math.PI) / 180;
  const lat2 = (b.lat * Math.PI) / 180;
  const x =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(x));
}

function resolveBillableKm(ride, body) {
  const tracked = Number(body.actual_distance_km ?? ride.actual_distance_km ?? 0);
  if (tracked >= 0.05) return tracked;

  const dropLat = body.lat != null ? Number(body.lat) : ride.drop?.lat;
  const dropLng = body.lng != null ? Number(body.lng) : ride.drop?.lng;
  const pickup = ride.pickup;
  if (pickup?.lat && pickup?.lng && dropLat != null && dropLng != null) {
    return Math.max(haversineKm(pickup, { lat: dropLat, lng: dropLng }), 0.1);
  }
  if (pickup?.lat && pickup?.lng && dropLat == null) {
    return Math.max(haversineKm(pickup, ride.drop || pickup), 0.1);
  }
  return Math.max(tracked, 0.1);
}

/** POST dropped — mark drop, keep ride open for OTP + payment */
async function markDroppedFlex(req, res) {
  const ride = await findRideById(req.params.rideId);
  if (!ride || ride.driverId?.toString() !== req.driver._id.toString()) {
    return res.status(404).json({ success: false, message: "Ride not found." });
  }
  if (ride.status !== RIDE_STATUS.STARTED && ride.status !== "IN_TRANSIT" && ride.status !== "started") {
    return res.status(400).json({ success: false, message: "Ride must be in transit." });
  }

  const body = req.body || {};
  const billableKm = resolveBillableKm(ride, body);
  const durationMin = Number(body.duration_min ?? ride.duration_min ?? 0);
  const fare = Number(
    Number(body.fare || 0) > 0
      ? body.fare
      : calcKmOnlyFare({ distanceKm: billableKm }) || ride.fare || billableKm * PER_KM_DEFAULT
  );
  ride.fare = fare;
  ride.drop_reached = true;
  ride.drop_otp = ride.drop_otp || String(Math.floor(1000 + Math.random() * 9000));
  ride.drop_otp_verified = false;
  if (body.lat != null && body.lng != null) {
    ride.drop = { lat: Number(body.lat), lng: Number(body.lng) };
  }
  ride.actual_distance_km = billableKm;
  if (body.duration_min != null) ride.duration_min = Number(body.duration_min);
  await ride.save();

  const payload = toFlexPayload(ride);
  socketUtils.emitToCustomer(ride.customerId, "drop_reached", payload);
  socketUtils.emitToCustomer(ride.customerId, "drop_otp_generated", { ...payload, drop_otp: ride.drop_otp });
  socketUtils.emitToRide(ride._id.toString(), "ride_status_update", payload);

  return res.json({
    success: true,
    message: "Drop reached, fare recalculated",
    ride_id: ride._id.toString(),
    fare: ride.fare,
    drop_otp: ride.drop_otp
  });
}

/** POST verify-drop-otp */
async function verifyDropOtpFlex(req, res) {
  const otp = req.body?.otp;
  const ride = await findRideById(req.params.rideId);
  if (!ride || ride.driverId?.toString() !== req.driver._id.toString()) {
    return res.status(404).json({ success: false, message: "Ride not found." });
  }
  if (!ride.drop_reached) {
    return res.status(400).json({ success: false, message: "Mark drop reached first." });
  }
  if (ride.drop_otp_verified) {
    return res.json({ success: true, message: "Drop OTP already verified", ride_id: ride._id.toString() });
  }
  if (String(ride.drop_otp) !== String(otp)) {
    return res.status(400).json({ success: false, message: "Invalid drop OTP." });
  }

  ride.drop_otp_verified = true;
  ride.status = RIDE_STATUS.COMPLETED_PENDING_PAYMENT;
  ride.paymentStatus = "PENDING";
  await ride.save();

  socketUtils.emitToCustomer(ride.customerId, "drop_otp_verified", toFlexPayload(ride));
  emitPaymentPending(ride);

  await Notification.create({
    userType: "customer",
    userId: ride.customerId.toString(),
    title: "Payment required",
    message: `Please pay ₹${ride.fare} for your ride.`
  });

  return res.json({
    success: true,
    message: "Drop OTP verified — awaiting payment",
    ride_id: ride._id.toString(),
    status: ride.status,
    payment_status: ride.paymentStatus
  });
}

/** Marks ride COMPLETED and notifies customer + driver. Idempotent. */
async function finalizeRideAfterPayment(ride) {
  if (
    ride.status === RIDE_STATUS.COMPLETED &&
    ride.completedAt &&
    ride.driverEarningsAmount != null
  ) {
    return ride;
  }
  stampRideEarnings(ride);
  ride.status = RIDE_STATUS.COMPLETED;
  await ride.save();
  emitRideCompleted(ride);
  if (ride.driverId) {
    const Driver = require("../models/Driver");
    await Driver.findByIdAndUpdate(ride.driverId, { status: "online" });
  }
  return ride;
}

/** POST cash-received */
async function confirmCashReceivedFlex(req, res) {
  const ride = await findRideById(req.params.rideId);
  if (!ride || ride.driverId?.toString() !== req.driver._id.toString()) {
    return res.status(404).json({ success: false, message: "Ride not found." });
  }
  if (!ride.drop_otp_verified) {
    return res.status(400).json({ success: false, message: "Drop OTP not verified." });
  }

  ride.paymentStatus = "SUCCESS";
  ride.payment.status = "PAID";
  ride.payment.method = "CASH";
  ride.payment.paidAt = new Date();

  let walletResult = null;
  if (!ride.walletCredited && ride.driverId) {
    try {
      walletResult = await creditDriverWalletForRide({
        ride,
        paymentId: `cash_${ride._id}`,
        paymentMethod: "CASH"
      });
      ride.walletCredited = true;
    } catch (err) {
      console.error("CASH WALLET CREDIT ERROR:", err);
    }
  }
  await ride.save();

  emitPaymentSuccess(ride, {
    payment_method: "CASH",
    wallet_balance: walletResult?.walletBalance,
    driver_earnings: walletResult?.driverEarnings
  });
  await finalizeRideAfterPayment(ride);

  return res.json({
    success: true,
    message: "Cash received — ride completed",
    ride_id: ride._id.toString(),
    payment_status: "SUCCESS",
    status: ride.status,
    wallet_balance: walletResult?.walletBalance
  });
}

/** POST complete — only after payment SUCCESS */
async function completeRideFlex(req, res) {
  const ride = await findRideById(req.params.rideId);
  if (!ride || ride.driverId?.toString() !== req.driver._id.toString()) {
    return res.status(404).json({ success: false, message: "Ride not found." });
  }
  if (!ride.drop_otp_verified) {
    return res.status(400).json({ success: false, message: "Drop OTP not verified." });
  }
  if (ride.paymentStatus !== "SUCCESS") {
    return res.status(400).json({ success: false, message: "Payment not completed." });
  }
  if (ride.status === RIDE_STATUS.COMPLETED) {
    return res.json({ success: true, message: "Ride already completed", ride_id: ride._id.toString() });
  }

  stampRideEarnings(ride);
  ride.status = RIDE_STATUS.COMPLETED;
  await ride.save();

  emitRideCompleted(ride);

  if (ride.driverId) {
    const Driver = require("../models/Driver");
    await Driver.findByIdAndUpdate(ride.driverId, { status: "online" });
  }

  return res.json({
    success: true,
    message: "Ride completed",
    ride_id: ride._id.toString(),
    status: ride.status
  });
}

/** GET single ride for driver (includes payment-pending) */
async function getRideForDriver(req, res) {
  const ride = await findRideById(req.params.rideId);
  if (!ride || ride.driverId?.toString() !== req.driver._id.toString()) {
    return res.status(404).json({ success: false, message: "Ride not found." });
  }
  return res.json({
    success: true,
    data: toRidePayload(ride)
  });
}

module.exports = {
  markDroppedFlex,
  verifyDropOtpFlex,
  confirmCashReceivedFlex,
  completeRideFlex,
  getRideForDriver,
  emitPaymentSuccess,
  emitPaymentFailed,
  finalizeRideAfterPayment
};
