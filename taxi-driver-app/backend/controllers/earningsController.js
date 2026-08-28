const { Ride, RIDE_STATUS } = require("../models/Ride");
const {
  calcCommission,
  calcDriverEarnings,
  COMMISSION_PERCENT
} = require("../services/walletService");
const {
  getPeriodBounds,
  formatDateKey,
  effectiveCompletedAt
} = require("../utils/periodRange");

function normalizePeriod(raw) {
  const p = String(raw || "today").toLowerCase();
  if (p === "weekly" || p === "week") return "week";
  if (p === "monthly" || p === "month") return "month";
  if (p === "yearly" || p === "year") return "year";
  return "today";
}

function parseTzOffset(req) {
  const q = req.query.tz_offset ?? req.query.tzOffset ?? req.headers["x-tz-offset"];
  const n = Number(q);
  if (!Number.isNaN(n) && n >= -720 && n <= 840) return n;
  return 330;
}

function paymentBucket(ride) {
  const method = String(ride.payment?.method || "").toUpperCase();
  const mode = String(ride.paymentMode || "").toUpperCase();
  if (method === "CASH" || mode === "CASH") return "cash";
  if (method === "CARD" || method.includes("DEBIT") || method.includes("CREDIT")) return "card";
  if (["UPI", "GPAY", "PHONEPE", "PAYTM", "RAZORPAY"].includes(method) || mode === "ONLINE") {
    return "digital";
  }
  return "cash";
}

function paymentLabel(ride) {
  const method = String(ride.payment?.method || "").toUpperCase();
  const mode = String(ride.paymentMode || "").toUpperCase();
  if (method === "RAZORPAY" || mode === "ONLINE") return "Online / UPI";
  if (method === "GPAY") return "Google Pay";
  if (method === "PHONEPE") return "PhonePe";
  if (method === "PAYTM") return "Paytm";
  if (method === "UPI") return "UPI";
  if (method === "CARD") return "Card";
  if (method === "CASH" || mode === "CASH") return "Cash";
  return method || mode || "Cash";
}

function formatAddress(ride, which) {
  if (which === "pickup") {
    return ride.pickupAddress || ride.pickup?.address || "Pickup";
  }
  return ride.dropAddress || ride.drop?.address || "Drop";
}

function rideDurationHours(ride) {
  const mins = Number(ride.duration_min || 0);
  if (mins > 0) return mins / 60;
  const completed = effectiveCompletedAt(ride);
  if (ride.startedAt && completed) {
    return Math.max((completed - new Date(ride.startedAt)) / 3600000, 0.1);
  }
  return 0;
}

function fareForRide(ride) {
  return Number(ride.fare || 0);
}

function netForRide(ride) {
  if (ride.driverEarningsAmount != null) return Number(ride.driverEarningsAmount);
  return calcDriverEarnings(fareForRide(ride));
}

function commissionForRide(ride) {
  if (ride.platformCommissionAmount != null) return Number(ride.platformCommissionAmount);
  return calcCommission(fareForRide(ride));
}

function toRideRow(ride, tzOffsetMinutes) {
  const fare = fareForRide(ride);
  const completedAt = effectiveCompletedAt(ride);
  const localDate =
    ride.completedLocalDate || formatDateKey(completedAt, tzOffsetMinutes);
  return {
    ride_id: String(ride._id),
    customer_name: ride.customerName || "Passenger",
    customer_phone: ride.customerPhone || "",
    pickup: formatAddress(ride, "pickup"),
    dropoff: formatAddress(ride, "drop"),
    fare,
    driver_earnings: netForRide(ride),
    commission: commissionForRide(ride),
    payment_mode: ride.paymentMode,
    payment_method: ride.payment?.method,
    payment_label: paymentLabel(ride),
    payment_bucket: paymentBucket(ride),
    completed_at: completedAt,
    completed_local_date: localDate,
    duration_min: ride.duration_min,
    actual_distance_km: ride.actual_distance_km
  };
}

function aggregateRides(inPeriod, tzOffsetMinutes) {
  let totalFare = 0;
  let totalCommission = 0;
  let totalNet = 0;
  let cash = 0;
  let card = 0;
  let digital = 0;
  let hours = 0;
  const byDay = new Map();

  for (const ride of inPeriod) {
    const fare = fareForRide(ride);
    const commission = commissionForRide(ride);
    const net = netForRide(ride);
    totalFare += fare;
    totalCommission += commission;
    totalNet += net;
    hours += rideDurationHours(ride);
    const bucket = paymentBucket(ride);
    if (bucket === "cash") cash += fare;
    else if (bucket === "card") card += fare;
    else digital += fare;

    const dayKey =
      ride.completedLocalDate ||
      formatDateKey(effectiveCompletedAt(ride), tzOffsetMinutes);
    const day = byDay.get(dayKey) || {
      date: dayKey,
      total: 0,
      net: 0,
      rides: 0,
      cash: 0,
      card: 0,
      digital: 0
    };
    day.total += fare;
    day.net += net;
    day.rides += 1;
    if (bucket === "cash") day.cash += fare;
    else if (bucket === "card") day.card += fare;
    else day.digital += fare;
    byDay.set(dayKey, day);
  }

  const dailyBreakdown = [...byDay.values()]
    .sort((a, b) => b.date.localeCompare(a.date))
    .map((d) => ({
      date: d.date,
      total: Number(d.total.toFixed(2)),
      net: Number(d.net.toFixed(2)),
      rides: d.rides,
      cash: Number(d.cash.toFixed(2)),
      card: Number(d.card.toFixed(2)),
      digital: Number(d.digital.toFixed(2))
    }));

  return {
    totalFare,
    totalCommission,
    totalNet,
    cash,
    card,
    digital,
    hours,
    dailyBreakdown
  };
}

/** GET /api/drivers/earnings/summary?period=today|week|month|year&tz_offset=330 */
async function getEarningsSummary(req, res) {
  const period = normalizePeriod(req.query.period);
  const tzOffsetMinutes = parseTzOffset(req);
  const { start, end, label } = getPeriodBounds(period, tzOffsetMinutes);

  const rides = await Ride.find({
    driverId: req.driver._id,
    status: RIDE_STATUS.COMPLETED
  })
    .sort({ completedAt: -1, updatedAt: -1 })
    .lean();

  const inPeriod = rides.filter((r) => {
    const t = effectiveCompletedAt(r);
    return t >= start && t <= end;
  });

  const agg = aggregateRides(inPeriod, tzOffsetMinutes);

  return res.json({
    success: true,
    data: {
      period,
      period_label: label,
      date_from: start,
      date_to: end,
      tz_offset_minutes: tzOffsetMinutes,
      total: Number(agg.totalFare.toFixed(2)),
      rides: inPeriod.length,
      hours: Number(agg.hours.toFixed(1)),
      cash: Number(agg.cash.toFixed(2)),
      card: Number(agg.card.toFixed(2)),
      digital: Number(agg.digital.toFixed(2)),
      commission: Number(agg.totalCommission.toFixed(2)),
      net: Number(agg.totalNet.toFixed(2)),
      commission_percent: COMMISSION_PERCENT,
      daily_breakdown: agg.dailyBreakdown,
      rides_list: inPeriod.slice(0, 50).map((r) => toRideRow(r, tzOffsetMinutes))
    }
  });
}

module.exports = { getEarningsSummary };
