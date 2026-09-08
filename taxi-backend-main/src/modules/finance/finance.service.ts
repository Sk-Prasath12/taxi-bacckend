import { Types } from "mongoose";
import { emitToRoom } from "../../socket/socket-emit.service";
import { calculateCommission } from "../common/commission.service";
import { RideDocument, RideModel } from "../customer/ride/ride.model";
import { UserModel } from "../users/users.model";
import { AdminRevenueModel } from "./admin-revenue.model";
import { DriverDueModel } from "./driver-due.model";
import { WalletModel } from "./wallet.model";
import { WalletTransactionModel } from "./wallet-transaction.model";

/**
 * Idempotent finance settlement for a completed ride.
 * Uses finance_processed lock + unique ride_id wallet transaction.
 */
export const processRidePayment = async (rideInput: RideDocument) => {
  const ride = await RideModel.findById(rideInput._id);
  if (!ride) {
    return null;
  }

  if (ride.status !== "COMPLETED" || ride.payment_status !== "SUCCESS" || !ride.driver_id) {
    return null;
  }

  const { commission, driverAmount } = calculateCommission(ride.fare);

  const lockedRide = await RideModel.findOneAndUpdate(
    {
      _id: ride._id,
      finance_processed: { $ne: true },
    },
    {
      $set: {
        finance_processed: true,
        driver_earning: driverAmount,
        commission_amount: commission,
      },
    },
    { new: true }
  );

  if (!lockedRide) {
    // Already processed — ensure earning fields exist for history.
    if (ride.driver_earning == null) {
      await RideModel.updateOne(
        { _id: ride._id },
        { $set: { driver_earning: driverAmount, commission_amount: commission } }
      );
    }
    return {
      already_processed: true,
      commission,
      driverAmount,
    };
  }

  const isOnline = ride.payment_mode === "ONLINE";
  // Credit withdrawable wallet for both ONLINE and CASH so Driver Wallet always reflects ride earnings.
  // CASH also increments platform commission due (driver collected full fare in hand).
  const balanceDelta = driverAmount;

  let txnCreated = false;
  try {
    await WalletTransactionModel.create({
      user_id: ride.driver_id,
      ride_id: ride._id,
      type: "RIDE_EARNING",
      amount: driverAmount,
      balance_delta: balanceDelta,
      fare: ride.fare,
      commission,
      payment_mode: ride.payment_mode ?? "CASH",
      payment_status: "SUCCESS",
      description: isOnline
        ? `Online ride earning for ride ${ride.id}`
        : `Cash ride earning for ride ${ride.id}`,
    });
    txnCreated = true;
  } catch (error: unknown) {
    const code = (error as { code?: number })?.code;
    // Duplicate key = wallet already credited for this rideId — do NOT $inc again.
    if (code === 11000) {
      const wallet = await WalletModel.findOne({ user_id: ride.driver_id }).lean();
      const payload = {
        ride_id: String(ride.id),
        amount: driverAmount,
        fare: ride.fare,
        commission,
        payment_mode: ride.payment_mode ?? "CASH",
        payment_status: "SUCCESS",
        finance_processed: true,
        wallet_balance: wallet?.balance ?? 0,
        total_earned: wallet?.total_earned ?? 0,
        already_processed: true,
      };
      await emitToRoom(`driver_${String(ride.driver_id)}`, "driver_wallet_updated", payload);
      await emitToRoom(`driver_${String(ride.driver_id)}`, "wallet_updated", payload);
      return { already_processed: true, commission, driverAmount, wallet };
    }
    // Roll back finance flag so a retry can settle.
    await RideModel.updateOne({ _id: ride._id }, { $set: { finance_processed: false } });
    throw error;
  }

  if (!txnCreated) {
    return { already_processed: true, commission, driverAmount };
  }

  await WalletModel.findOneAndUpdate(
    { user_id: ride.driver_id },
    { $inc: { balance: driverAmount, total_earned: driverAmount } },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );

  if (isOnline) {
    try {
      await AdminRevenueModel.create({
        ride_id: ride._id,
        amount: commission,
        source: "ONLINE",
      });
    } catch (error: unknown) {
      if ((error as { code?: number })?.code !== 11000) throw error;
    }
  } else {
    await DriverDueModel.findOneAndUpdate(
      { driver_id: ride.driver_id },
      { $inc: { due_amount: commission } },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    try {
      await AdminRevenueModel.create({
        ride_id: ride._id,
        amount: commission,
        source: "CASH",
      });
    } catch (error: unknown) {
      if ((error as { code?: number })?.code !== 11000) throw error;
    }

    await emitToRoom(`driver_${String(ride.driver_id)}`, "driver_due_updated", {
      ride_id: String(ride.id),
      due_amount: commission,
    });
  }

  const wallet = await WalletModel.findOne({ user_id: ride.driver_id }).lean();
  const payload = {
    ride_id: String(ride.id),
    amount: driverAmount,
    fare: ride.fare,
    commission,
    payment_mode: ride.payment_mode ?? "CASH",
    payment_status: "SUCCESS",
    finance_processed: true,
    wallet_balance: wallet?.balance ?? 0,
    total_earned: wallet?.total_earned ?? 0,
  };

  await emitToRoom(`driver_${String(ride.driver_id)}`, "driver_wallet_updated", payload);
  await emitToRoom(`driver_${String(ride.driver_id)}`, "wallet_updated", payload);

  return { already_processed: false, commission, driverAmount, wallet };
};

/**
 * Backfill wallet credits for completed paid rides that never settled,
 * and upgrade older CASH earnings that only bumped total_earned (balance_delta=0).
 */
export const ensureDriverWalletSettled = async (driverId: Types.ObjectId | string) => {
  const driverObjectId =
    typeof driverId === "string" ? new Types.ObjectId(driverId) : driverId;

  const pendingRides = await RideModel.find({
    driver_id: driverObjectId,
    status: "COMPLETED",
    payment_status: "SUCCESS",
    finance_processed: { $ne: true },
  })
    .sort({ completed_at: -1 })
    .limit(30);

  for (const ride of pendingRides) {
    try {
      await processRidePayment(ride);
    } catch {
      // Leave for next wallet refresh; do not fail the read path.
    }
  }

  // Older CASH settlements credited total_earned only — credit balance once.
  const staleTxns = await WalletTransactionModel.find({
    user_id: driverObjectId,
    type: "RIDE_EARNING",
    balance_delta: 0,
    amount: { $gt: 0 },
  })
    .sort({ createdAt: -1 })
    .limit(50);

  for (const txn of staleTxns) {
    const upgraded = await WalletTransactionModel.findOneAndUpdate(
      { _id: txn._id, balance_delta: 0 },
      { $set: { balance_delta: txn.amount } },
      { new: true }
    );
    if (!upgraded) continue;
    await WalletModel.findOneAndUpdate(
      { user_id: driverObjectId },
      { $inc: { balance: txn.amount } },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );
  }

  // Completed SUCCESS rides with no RIDE_EARNING row (finance flag already true).
  const recentPaid = await RideModel.find({
    driver_id: driverObjectId,
    status: "COMPLETED",
    payment_status: "SUCCESS",
  })
    .select("_id fare payment_mode driver_earning commission_amount")
    .sort({ completed_at: -1 })
    .limit(40)
    .lean();

  if (recentPaid.length === 0) return;

  const rideIds = recentPaid.map((r) => r._id);
  const existing = await WalletTransactionModel.find({
    user_id: driverObjectId,
    type: "RIDE_EARNING",
    ride_id: { $in: rideIds },
  })
    .select("ride_id")
    .lean();
  const haveTxn = new Set(existing.map((t) => String(t.ride_id)));

  for (const ride of recentPaid) {
    if (haveTxn.has(String(ride._id))) continue;
    const fare = Number(ride.fare ?? 0);
    const { commission, driverAmount } = calculateCommission(fare);
    const amount = Number(ride.driver_earning ?? driverAmount);
    const commissionAmt = Number(ride.commission_amount ?? commission);
    const mode = (ride.payment_mode ?? "CASH") as "ONLINE" | "CASH";
    try {
      await WalletTransactionModel.create({
        user_id: driverObjectId,
        ride_id: ride._id,
        type: "RIDE_EARNING",
        amount,
        balance_delta: amount,
        fare,
        commission: commissionAmt,
        payment_mode: mode,
        payment_status: "SUCCESS",
        description:
          mode === "ONLINE"
            ? `Online ride earning for ride ${String(ride._id)}`
            : `Cash ride earning for ride ${String(ride._id)}`,
      });
      // Only balance — total_earned may already have been incremented when finance_processed was set.
      await WalletModel.findOneAndUpdate(
        { user_id: driverObjectId },
        { $inc: { balance: amount } },
        { upsert: true, new: true, setDefaultsOnInsert: true }
      );
    } catch (error: unknown) {
      if ((error as { code?: number })?.code === 11000) continue;
    }
  }
};

export const getRevenueSummary = async () => {
  const [totals] = await AdminRevenueModel.aggregate<{ totalRevenue: number; onlineRevenue: number; cashRevenue: number }>(
    [
      {
        $group: {
          _id: null,
          totalRevenue: { $sum: "$amount" },
          onlineRevenue: {
            $sum: {
              $cond: [{ $eq: ["$source", "ONLINE"] }, "$amount", 0],
            },
          },
          cashRevenue: {
            $sum: {
              $cond: [{ $eq: ["$source", "CASH"] }, "$amount", 0],
            },
          },
        },
      },
      {
        $project: { _id: 0, totalRevenue: 1, onlineRevenue: 1, cashRevenue: 1 },
      },
    ]
  );

  return (
    totals ?? {
      totalRevenue: 0,
      onlineRevenue: 0,
      cashRevenue: 0,
    }
  );
};

export const getRevenueList = async () => {
  return AdminRevenueModel.find().sort({ createdAt: -1 }).lean();
};

export const getDriverDueById = async (driverId: string) => {
  const due = await DriverDueModel.findOne({
    driver_id: new Types.ObjectId(driverId),
  }).lean();

  return {
    driver_id: driverId,
    due_amount: due?.due_amount ?? 0,
    updatedAt: due?.updatedAt ?? null,
  };
};

const DAY_MS = 24 * 60 * 60 * 1000;

const getDayStart = (date: Date) => {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
};

const formatDayLabel = (date: Date) => date.toISOString().slice(0, 10);

const buildDateBuckets = (days: number) => {
  const todayStart = getDayStart(new Date());
  return Array.from({ length: days }, (_item, index) => {
    const dayStart = new Date(todayStart.getTime() - (days - 1 - index) * DAY_MS);
    const nextDay = new Date(dayStart.getTime() + DAY_MS);
    return { label: formatDayLabel(dayStart), dayStart, nextDay };
  });
};

const bucketByDay = (
  rows: Array<{ _id: { year: number; month: number; day: number }; value: number }>,
  labels: string[]
) => {
  const valueMap = new Map<string, number>();
  for (const row of rows) {
    const month = String(row._id.month).padStart(2, "0");
    const day = String(row._id.day).padStart(2, "0");
    const key = `${row._id.year}-${month}-${day}`;
    valueMap.set(key, row.value);
  }

  return labels.map((label) => ({
    date: label,
    value: valueMap.get(label) ?? 0,
  }));
};

export const getAdminDashboardMetrics = async () => {
  const todayStart = getDayStart(new Date());
  const tomorrowStart = new Date(todayStart.getTime() + DAY_MS);
  const activeTripStatuses = [
    "PENDING_CONFIRMATION",
    "SEARCHING_DRIVER",
    "DRIVER_ASSIGNED",
    "ARRIVED_AT_PICKUP",
    "STARTED",
    "PICKED_UP",
    "IN_TRANSIT",
  ];
  const sevenDayBuckets = buildDateBuckets(7);
  const sevenDayStart = sevenDayBuckets[0].dayStart;
  const sevenDayEnd = sevenDayBuckets[6].nextDay;
  const previousSevenDayStart = new Date(sevenDayStart.getTime() - 7 * DAY_MS);

  const [
    totalDrivers,
    totalCustomers,
    activeTrips,
    completedTrips,
    tripsToday,
    totalRevenueAgg,
    tripsPerDayAgg,
    currentRevenueAgg,
    previousRevenueAgg,
  ] = await Promise.all([
    UserModel.countDocuments({ role: "DRIVER" }),
    UserModel.countDocuments({ role: "CUSTOMER" }),
    RideModel.countDocuments({ status: { $in: activeTripStatuses } }),
    RideModel.countDocuments({ status: "COMPLETED" }),
    RideModel.countDocuments({ createdAt: { $gte: todayStart, $lt: tomorrowStart } }),
    AdminRevenueModel.aggregate<{ total: number }>([{ $group: { _id: null, total: { $sum: "$amount" } } }]),
    RideModel.aggregate<{ _id: { year: number; month: number; day: number }; value: number }>([
      { $match: { createdAt: { $gte: sevenDayStart, $lt: sevenDayEnd } } },
      {
        $group: {
          _id: {
            year: { $year: "$createdAt" },
            month: { $month: "$createdAt" },
            day: { $dayOfMonth: "$createdAt" },
          },
          value: { $sum: 1 },
        },
      },
      { $sort: { "_id.year": 1, "_id.month": 1, "_id.day": 1 } },
    ]),
    AdminRevenueModel.aggregate<{ _id: { year: number; month: number; day: number }; value: number }>([
      { $match: { createdAt: { $gte: sevenDayStart, $lt: sevenDayEnd } } },
      {
        $group: {
          _id: {
            year: { $year: "$createdAt" },
            month: { $month: "$createdAt" },
            day: { $dayOfMonth: "$createdAt" },
          },
          value: { $sum: "$amount" },
        },
      },
      { $sort: { "_id.year": 1, "_id.month": 1, "_id.day": 1 } },
    ]),
    AdminRevenueModel.aggregate<{ total: number }>([
      { $match: { createdAt: { $gte: previousSevenDayStart, $lt: sevenDayStart } } },
      { $group: { _id: null, total: { $sum: "$amount" } } },
    ]),
  ]);

  const totalRevenue = totalRevenueAgg[0]?.total ?? 0;
  const currentRevenue = currentRevenueAgg.reduce((sum, item) => sum + item.value, 0);
  const previousRevenue = previousRevenueAgg[0]?.total ?? 0;
  const revenueGrowthPercent =
    previousRevenue <= 0
      ? currentRevenue > 0
        ? 100
        : 0
      : Number((((currentRevenue - previousRevenue) / previousRevenue) * 100).toFixed(2));

  const dayLabels = sevenDayBuckets.map((item) => item.label);

  return {
    total_drivers: totalDrivers,
    total_customers: totalCustomers,
    active_trips: activeTrips,
    completed_trips: completedTrips,
    trips_today: tripsToday,
    total_revenue: Number(totalRevenue.toFixed(2)),
    trips_per_day: bucketByDay(tripsPerDayAgg, dayLabels).map((item) => ({
      date: item.date,
      trips: item.value,
    })),
    revenue_growth: {
      percentage: revenueGrowthPercent,
      current_period_revenue: Number(currentRevenue.toFixed(2)),
      previous_period_revenue: Number(previousRevenue.toFixed(2)),
      per_day: bucketByDay(currentRevenueAgg, dayLabels).map((item) => ({
        date: item.date,
        revenue: Number(item.value.toFixed(2)),
      })),
    },
  };
};
