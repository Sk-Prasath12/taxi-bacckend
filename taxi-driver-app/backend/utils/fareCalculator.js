const PER_KM_DEFAULT = Number(process.env.FARE_PER_KM || 30);
const PER_MIN = Number(process.env.FARE_PER_MIN || 5);
const FREE_WAITING_MIN = Number(process.env.FARE_FREE_WAITING_MIN || 1);
const CANCELLATION_FEE = Number(process.env.CANCELLATION_FEE || 10);

const billableMinutes = (durationMin) => {
  const extra = Number(durationMin || 0) - FREE_WAITING_MIN;
  if (extra <= 0) return 0;
  return Math.ceil(extra);
};

const timeCharge = (durationMin) => billableMinutes(durationMin) * PER_MIN;

const distanceCharge = (distanceKm, perKm = PER_KM_DEFAULT) =>
  Number(distanceKm || 0) * perKm;

/** Fare from GPS km only (no time charge). */
const calcKmOnlyFare = ({ distanceKm, perKm = PER_KM_DEFAULT }) =>
  Number(distanceCharge(distanceKm, perKm).toFixed(2));

const calcTripFare = ({
  distanceKm,
  durationMin = 0,
  baseFare = 0,
  perKm = PER_KM_DEFAULT
}) => {
  const total = baseFare + distanceCharge(distanceKm, perKm) + timeCharge(durationMin);
  return Number(total.toFixed(2));
};

const estimateBookingFare = ({ distanceKm, baseFare = 0, perKm = PER_KM_DEFAULT }) =>
  calcTripFare({
    distanceKm,
    durationMin: Number(distanceKm || 0) * 2,
    baseFare,
    perKm
  });

module.exports = {
  PER_KM_DEFAULT,
  PER_MIN,
  FREE_WAITING_MIN,
  CANCELLATION_FEE,
  billableMinutes,
  timeCharge,
  distanceCharge,
  calcKmOnlyFare,
  calcTripFare,
  estimateBookingFare
};
