const mongoose = require("mongoose");

const walletTransactionSchema = new mongoose.Schema(
  {
    driverId: { type: mongoose.Schema.Types.ObjectId, ref: "Driver", required: true, index: true },
    rideId: { type: mongoose.Schema.Types.ObjectId, ref: "Ride", required: true, index: true },
    customerId: { type: String, required: true },
    paymentId: { type: String, index: true },
    razorpayOrderId: { type: String, index: true },
    amount: { type: Number, required: true },
    commission: { type: Number, default: 0 },
    driverEarnings: { type: Number, required: true },
    walletBalance: { type: Number, required: true },
    paymentMethod: { type: String, enum: ["RAZORPAY", "CASH", "ONLINE"], default: "RAZORPAY" },
    status: { type: String, enum: ["SUCCESS", "FAILED", "PENDING"], default: "SUCCESS" },
    transactionTime: { type: Date, default: Date.now }
  },
  { timestamps: true }
);

walletTransactionSchema.index({ paymentId: 1 }, { unique: true, sparse: true });

module.exports = mongoose.model("WalletTransaction", walletTransactionSchema);
