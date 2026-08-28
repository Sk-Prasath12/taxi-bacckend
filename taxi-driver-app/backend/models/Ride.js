const mongoose = require("mongoose");

const RIDE_STATUS = {
  REQUESTED: "requested",
  ACCEPTED: "accepted",
  ARRIVED: "arrived",
  STARTED: "started",
  COMPLETED_PENDING_PAYMENT: "completed_pending_payment",
  COMPLETED: "completed",
  CANCELLED: "cancelled"
};

const paymentSchema = new mongoose.Schema(
  {
    status: {
      type: String,
      enum: ["PENDING", "PAID"],
      default: "PENDING"
    },
    method: {
      type: String,
      enum: ["UPI", "GPAY", "PHONEPE", "PAYTM", "CARD", "CASH", "RAZORPAY"],
      default: "CASH"
    },
    transactionRef: String,
    orderId: String,
    qrReference: String,
    paidAt: Date
  },
  { _id: false }
);

const rideSchema = new mongoose.Schema(
  {
    customerId: { type: String, required: true, index: true },
    customerName: { type: String, default: "Passenger" },
    customerPhone: String,
    customerEmail: String,
    pickup: {
      lat: Number,
      lng: Number
    },
    pickupAddress: { type: String, default: "" },
    drop: {
      lat: Number,
      lng: Number
    },
    dropAddress: { type: String, default: "" },
    fare: { type: Number, default: 0 },
    distance: { type: String, default: "" },
    vehicleTypeId: String,
    paymentMode: { type: String, enum: ["ONLINE", "CASH"], default: "CASH" },
    paymentStatus: { type: String, enum: ["PENDING", "SUCCESS", "FAILED"], default: "PENDING" },
    driverId: { type: mongoose.Schema.Types.ObjectId, ref: "Driver", index: true },
    otp: { type: String, required: true },
    otpVerifiedAt: Date,
    acceptedAt: Date,
    arrivedAt: Date,
    startedAt: Date,
    completedAt: Date,
    cancelledAt: Date,
    /** When customer confirmed and drivers were notified. */
    dispatchedAt: Date,
    status: {
      type: String,
      enum: Object.values(RIDE_STATUS),
      default: RIDE_STATUS.REQUESTED,
      index: true
    },
    drop_otp_verified: { type: Boolean, default: false },
    drop_reached: { type: Boolean, default: false },
    drop_otp: String,
    actual_distance_km: Number,
    duration_min: Number,
    walletCredited: { type: Boolean, default: false },
    /** Snapshot at ride completion (for earnings history). */
    driverEarningsAmount: Number,
    platformCommissionAmount: Number,
    /** Local calendar date YYYY-MM-DD when ride completed (driver TZ). */
    completedLocalDate: { type: String, index: true },
    payment: { type: paymentSchema, default: () => ({}) }
  },
  { timestamps: true }
);

rideSchema.index({ driverId: 1, status: 1, completedAt: -1 });

module.exports = {
  Ride: mongoose.model("Ride", rideSchema),
  RIDE_STATUS
};
