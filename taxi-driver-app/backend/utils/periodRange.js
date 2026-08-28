/**
 * Period bounds in UTC for MongoDB queries, aligned to the driver's local calendar.
 * @param {string} period today | week | month | year
 * @param {number} tzOffsetMinutes Minutes east of UTC (IST = 330)
 */
function getPeriodBounds(period, tzOffsetMinutes = 330) {
  const offsetMs = tzOffsetMinutes * 60 * 1000;
  const shifted = new Date(Date.now() + offsetMs);
  const y = shifted.getUTCFullYear();
  const m = shifted.getUTCMonth();
  const d = shifted.getUTCDate();

  const toUtc = (localY, localM, localD, h, min, s, ms) =>
    new Date(Date.UTC(localY, localM, localD, h, min, s, ms) - offsetMs);

  let start;
  let end;
  let label;

  if (period === "week") {
    const startLocal = new Date(Date.UTC(y, m, d, 0, 0, 0, 0));
    startLocal.setUTCDate(startLocal.getUTCDate() - 6);
    start = toUtc(
      startLocal.getUTCFullYear(),
      startLocal.getUTCMonth(),
      startLocal.getUTCDate(),
      0,
      0,
      0,
      0
    );
    end = toUtc(y, m, d, 23, 59, 59, 999);
    label = `${formatDateKey(start, tzOffsetMinutes)} — ${formatDateKey(end, tzOffsetMinutes)}`;
  } else if (period === "month") {
    start = toUtc(y, m, 1, 0, 0, 0, 0);
    end = toUtc(y, m, d, 23, 59, 59, 999);
    label = `${y}-${String(m + 1).padStart(2, "0")}`;
  } else if (period === "year") {
    start = toUtc(y, 0, 1, 0, 0, 0, 0);
    end = toUtc(y, m, d, 23, 59, 59, 999);
    label = String(y);
  } else {
    start = toUtc(y, m, d, 0, 0, 0, 0);
    end = toUtc(y, m, d, 23, 59, 59, 999);
    label = formatDateKey(start, tzOffsetMinutes);
  }

  return { start, end, label, tzOffsetMinutes };
}

function formatDateKey(utcDate, tzOffsetMinutes = 330) {
  const shifted = new Date(utcDate.getTime() + tzOffsetMinutes * 60 * 1000);
  const y = shifted.getUTCFullYear();
  const m = String(shifted.getUTCMonth() + 1).padStart(2, "0");
  const day = String(shifted.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

function effectiveCompletedAt(ride) {
  if (ride.completedAt) return new Date(ride.completedAt);
  if (ride.payment?.paidAt) return new Date(ride.payment.paidAt);
  if (ride.updatedAt) return new Date(ride.updatedAt);
  if (ride.createdAt) return new Date(ride.createdAt);
  return new Date(0);
}

module.exports = {
  getPeriodBounds,
  formatDateKey,
  effectiveCompletedAt
};
