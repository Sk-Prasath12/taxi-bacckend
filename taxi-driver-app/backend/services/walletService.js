const mongoose = require("mongoose");
const Driver = require("../models/Driver");
const WalletTransaction = require("../models/WalletTransaction");

const COMMISSION_PERCENT = Number(process.env.PLATFORM_COMMISSION_PERCENT || 15);

const calcCommission = (amount) => Number(((amount * COMMISSION_PERCENT) / 100).toFixed(2));
const calcDriverEarnings = (amount) => Number((amount - calcCommission(amount)).toFixed(2));

/**
 * Credits driver wallet after verified payment. Idempotent per paymentId.
 */
const creditDriverWalletForRide = async ({
  ride,
  paymentId,
  orderId,
  paymentMethod = "RAZORPAY"
}) => {
  if (!ride?.driverId) {
    throw new Error("Ride has no assigned driver.");
  }

  const existing = paymentId
    ? await WalletTransaction.findOne({ paymentId }).lean()
    : null;
  if (existing) {
    const driver = await Driver.findById(ride.driverId).lean();
    return {
      duplicate: true,
      transaction: existing,
      walletBalance: driver?.walletBalance ?? existing.walletBalance
    };
  }

  const existingForRide = await WalletTransaction.findOne({
    rideId: ride._id,
    status: "SUCCESS"
  }).lean();
  if (existingForRide) {
    const driver = await Driver.findById(ride.driverId).lean();
    return {
      duplicate: true,
      transaction: existingForRide,
      walletBalance: driver?.walletBalance ?? existingForRide.walletBalance
    };
  }

  const amount = Number(ride.fare || 0);
  const commission = calcCommission(amount);
  const driverEarnings = calcDriverEarnings(amount);

  const session = await mongoose.startSession();
  session.startTransaction();
  try {
    const driver = await Driver.findByIdAndUpdate(
      ride.driverId,
      { $inc: { walletBalance: driverEarnings } },
      { new: true, session }
    );

    const walletBalance = Number((driver?.walletBalance ?? driverEarnings).toFixed(2));

    const [transaction] = await WalletTransaction.create(
      [
        {
          driverId: ride.driverId,
          rideId: ride._id,
          customerId: String(ride.customerId),
          paymentId: paymentId || undefined,
          razorpayOrderId: orderId || ride.payment?.orderId,
          amount,
          commission,
          driverEarnings,
          walletBalance,
          paymentMethod,
          status: "SUCCESS",
          transactionTime: new Date()
        }
      ],
      { session }
    );

    await session.commitTransaction();
    return { duplicate: false, transaction, walletBalance, driverEarnings, commission };
  } catch (err) {
    await session.abortTransaction();
    if (err?.code === 11000 && paymentId) {
      const dup = await WalletTransaction.findOne({ paymentId }).lean();
      const driver = await Driver.findById(ride.driverId).lean();
      return {
        duplicate: true,
        transaction: dup,
        walletBalance: driver?.walletBalance ?? 0
      };
    }
    throw err;
  } finally {
    session.endSession();
  }
};

const getDriverWalletSummary = async (driverId) => {
  const driver = await Driver.findById(driverId).select("walletBalance").lean();
  const balance = Number((driver?.walletBalance ?? 0).toFixed(2));

  const pendingAgg = await WalletTransaction.aggregate([
    { $match: { driverId: new mongoose.Types.ObjectId(driverId), status: "PENDING" } },
    { $group: { _id: null, total: { $sum: "$amount" } } }
  ]);

  const transactions = await WalletTransaction.find({ driverId })
    .sort({ transactionTime: -1 })
    .limit(20)
    .lean();

  return {
    balance,
    pending: Number((pendingAgg[0]?.total || 0).toFixed(2)),
    transactions
  };
};

module.exports = {
  COMMISSION_PERCENT,
  calcCommission,
  calcDriverEarnings,
  creditDriverWalletForRide,
  getDriverWalletSummary
};
