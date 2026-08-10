import { Types } from "mongoose";
import { emitToRoom } from "../../socket/socket-emit.service";
import { calculateCommission } from "../common/commission.service";
import { RideDocument, RideModel } from "../customer/ride/ride.model";
import { UserModel } from "../users/users.model";
import { AdminRevenueModel } from "./admin-revenue.model";
import { DriverDueModel } from "./driver-due.model";
import { WalletModel } from "./wallet.model";

export const processRidePayment = async (rideInput: RideDocument) => {
  const ride = await RideModel.findById(rideInput._id);
  if (!ride) {
    return;
  }

  if (ride.status !== "COMPLETED" || ride.payment_status !== "SUCCESS" || !ride.driver_id) {
    return;
  }

  const lockedRide = await RideModel.findOneAndUpdate(
    {
      _id: ride._id,
      finance_processed: { $ne: true },
    },
    {
      $set: { finance_processed: true },
    },
    { new: true }
  );

  if (!lockedRide) {
    return;
  }

  const { commission, driverAmount } = calculateCommission(ride.fare);

  if (ride.payment_mode === "ONLINE") {
    await WalletModel.findOneAndUpdate(
      { user_id: ride.driver_id },
      { $inc: { balance: driverAmount, total_earned: driverAmount } },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    await AdminRevenueModel.create({
      ride_id: ride._id,
      amount: commission,
      source: "ONLINE",
    });

    await emitToRoom(`driver_${String(ride.driver_id)}`, "driver_wallet_updated", {
      ride_id: String(ride.id),
      amount: driverAmount,
    });
    await emitToRoom(`driver_${String(ride.driver_id)}`, "wallet_updated", {
      amount: driverAmount,
    });
    return;
  }

  await DriverDueModel.findOneAndUpdate(
    { driver_id: ride.driver_id },
    { $inc: { due_amount: commission } },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );

  await AdminRevenueModel.create({
    ride_id: ride._id,
    amount: commission,
    source: "CASH",
  });

  await emitToRoom(`driver_${String(ride.driver_id)}`, "driver_due_updated", {
    ride_id: String(ride.id),
    due_amount: commission,
  });
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
  const activeTripStatuses = ["PENDING_CONFIRMATION", "SEARCHING_DRIVER", "DRIVER_ASSIGNED", "ARRIVED_AT_PICKUP", "STARTED", "PICKED_UP", "IN_TRANSIT"];
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
