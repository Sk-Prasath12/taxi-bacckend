const { calcCommission, calcDriverEarnings } = require("./walletService");
const { formatDateKey } = require("../utils/periodRange");

/**
 * Persists fare split + completion time on the ride when it finishes.
 * @param {import("mongoose").Document} ride
 * @param {{ tzOffsetMinutes?: number, completedAt?: Date }} opts
 */
function stampRideEarnings(ride, opts = {}) {
  const tzOffsetMinutes = Number(opts.tzOffsetMinutes ?? 330);
  const completedAt = opts.completedAt || ride.completedAt || ride.payment?.paidAt || new Date();
  ride.completedAt = completedAt;

  const fare = Number(ride.fare || 0);
  ride.platformCommissionAmount = calcCommission(fare);
  ride.driverEarningsAmount = calcDriverEarnings(fare);
  ride.completedLocalDate = formatDateKey(completedAt, tzOffsetMinutes);

  if (!ride.duration_min && ride.startedAt) {
    const mins = Math.round((completedAt - new Date(ride.startedAt)) / 60000);
    if (mins > 0) ride.duration_min = mins;
  }

  if (ride.payment && ride.paymentStatus === "SUCCESS" && !ride.payment.paidAt) {
    ride.payment.paidAt = completedAt;
  }
}

module.exports = { stampRideEarnings };
