const crypto = require("crypto");
const Razorpay = require("razorpay");
const { Ride, RIDE_STATUS } = require("../models/Ride");
const { calcKmOnlyFare, PER_KM_DEFAULT } = require("../utils/fareCalculator");
const { creditDriverWalletForRide } = require("../services/walletService");
const {
  emitPaymentSuccess,
  emitPaymentFailed,
  finalizeRideAfterPayment
} = require("./rideControllerFlex");
const socketUtils = require("../utils/socket");

let razorpayClient = null;

const getRazorpay = () => {
  const keyId = process.env.RAZORPAY_KEY_ID;
  const keySecret = process.env.RAZORPAY_KEY_SECRET;
  if (!keyId || !keySecret) return null;
  if (!razorpayClient) {
    razorpayClient = new Razorpay({ key_id: keyId, key_secret: keySecret });
  }
  return razorpayClient;
};

const canCreatePaymentOrder = (ride) => {
  if (ride.paymentMode !== "ONLINE") return false;
  if (ride.paymentStatus === "SUCCESS") return false;
  return (
    ride.status === RIDE_STATUS.COMPLETED ||
    ride.status === RIDE_STATUS.COMPLETED_PENDING_PAYMENT ||
    (ride.drop_otp_verified === true && ride.paymentStatus === "PENDING")
  );
};

const createOrder = async (req, res) => {
  const ride = await Ride.findOne({ _id: req.body.ride_id, customerId: req.customer._id.toString() });
  if (!ride) return res.status(404).json({ success: false, message: "Ride not found." });
  if (!canCreatePaymentOrder(ride)) {
    return res.status(400).json({
      success: false,
      message: "Ride is not ready for online payment (verify drop OTP first)."
    });
  }

  let fare = Number(ride.fare || 0);
  if (fare <= 0) {
    const km = Number(ride.actual_distance_km || 0);
    if (km > 0) {
      fare = calcKmOnlyFare({ distanceKm: km });
    } else if (Number(ride.price || 0) > 0) {
      fare = Number(ride.price);
    }
  }
  if (fare > 0 && Number(ride.fare || 0) <= 0) {
    ride.fare = fare;
    await ride.save();
  }

  const amountPaise = Math.round(fare * 100);
  if (amountPaise <= 0) {
    return res.status(400).json({ success: false, message: "Invalid fare for payment." });
  }

  const razorpay = getRazorpay();
  if (!razorpay) {
    return res.status(503).json({
      success: false,
      message: "Razorpay is not configured. Set RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET."
    });
  }

  try {
    const order = await razorpay.orders.create({
      amount: amountPaise,
      currency: "INR",
      receipt: String(ride._id)
    });

    ride.payment.orderId = order.id;
    await ride.save();

    return res.json({
      success: true,
      order_id: order.id,
      amount: Number(order.amount),
      currency: order.currency || "INR",
      key: process.env.RAZORPAY_KEY_ID
    });
  } catch (err) {
    console.error("RAZORPAY ORDER ERROR:", err);
    return res.status(502).json({ success: false, message: "Failed to create Razorpay order." });
  }
};

const verify = async (req, res) => {
  const { ride_id, order_id, payment_id, signature } = req.body;
  const ride = await Ride.findOne({ _id: ride_id, customerId: req.customer._id.toString() });
  if (!ride) return res.status(404).json({ success: false, message: "Ride not found." });

  if (ride.paymentStatus === "SUCCESS" && ride.walletCredited) {
    emitPaymentSuccess(ride, {
      payment_id: ride.payment?.transactionRef,
      order_id: ride.payment?.orderId,
      ride_completed: true
    });
    return res.json({
      success: true,
      message: "Payment already verified.",
      payment_status: ride.paymentStatus,
      ride_id: String(ride._id),
      status: ride.status
    });
  }

  const secret = process.env.RAZORPAY_KEY_SECRET;
  const devBypass =
    process.env.NODE_ENV === "development" && process.env.ENABLE_PAYMENT_DEV_BYPASS === "true";

  if (!secret && !devBypass) {
    return res.status(503).json({ success: false, message: "Razorpay secret not configured." });
  }

  if (!devBypass) {
    const expected = crypto.createHmac("sha256", secret).update(`${order_id}|${payment_id}`).digest("hex");
    const expectedBuf = Buffer.from(expected, "utf8");
    const receivedBuf = Buffer.from(signature || "", "utf8");
    const valid =
      expectedBuf.length === receivedBuf.length && crypto.timingSafeEqual(expectedBuf, receivedBuf);
    if (!valid) {
      ride.paymentStatus = "FAILED";
      await ride.save();
      emitPaymentFailed(ride, "Invalid payment signature.");
      return res.status(400).json({
        success: false,
        message: "Invalid payment signature.",
        payment_status: ride.paymentStatus
      });
    }
  }

  ride.paymentStatus = "SUCCESS";
  ride.payment.status = "PAID";
  ride.payment.method = "RAZORPAY";
  ride.payment.transactionRef = payment_id;
  ride.payment.orderId = order_id || ride.payment.orderId;
  ride.payment.paidAt = new Date();
  await ride.save();

  let walletResult = null;
  if (!ride.walletCredited && ride.driverId) {
    try {
      walletResult = await creditDriverWalletForRide({
        ride,
        paymentId: payment_id,
        orderId: order_id,
        paymentMethod: "RAZORPAY"
      });
      ride.walletCredited = true;
      await ride.save();
    } catch (err) {
      console.error("WALLET CREDIT ERROR:", err);
    }
  }

  await finalizeRideAfterPayment(ride);

  const completedRide = (await Ride.findById(ride._id)) || ride;
  emitPaymentSuccess(completedRide, {
    payment_id,
    order_id,
    wallet_balance: walletResult?.walletBalance,
    driver_earnings: walletResult?.driverEarnings,
    ride_completed: true
  });

  return res.json({
    success: true,
    message: "Payment verified — ride completed.",
    payment_status: completedRide.paymentStatus,
    ride_id: String(completedRide._id),
    status: completedRide.status,
    wallet_balance: walletResult?.walletBalance,
    driver_earnings: walletResult?.driverEarnings
  });
};

module.exports = { createOrder, verify };
