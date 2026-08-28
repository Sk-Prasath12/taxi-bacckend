const { Ride, RIDE_STATUS } = require("../models/Ride");
const { filterRidesByPickupDistance, NEARBY_KM } = require("./nearbyRideDispatch");

const { calcCommission, calcDriverEarnings } = require("./walletService");

const toRidePayload = (rideDoc) => {
  const fare = Number(rideDoc.fare || 0);
  return {
    rideId: rideDoc._id.toString(),
    id: rideDoc._id.toString(),
    ride_id: rideDoc._id.toString(),
    driverId: rideDoc.driverId ? rideDoc.driverId.toString() : null,
    customerId: rideDoc.customerId?.toString(),
    customerName: rideDoc.customerName,
    customerPhone: rideDoc.customerPhone,
    pickup: rideDoc.pickup,
    drop: rideDoc.drop,
    pickupAddress: rideDoc.pickupAddress || "",
    dropAddress: rideDoc.dropAddress || "",
    distance: rideDoc.distance,
    actual_distance_km: rideDoc.actual_distance_km,
    duration_min: rideDoc.duration_min,
    fare,
    commission: calcCommission(fare),
    driverEarnings: calcDriverEarnings(fare),
    paymentMode: rideDoc.paymentMode,
    paymentStatus: rideDoc.paymentStatus,
    paymentMethod: rideDoc.payment?.method || rideDoc.paymentMode,
    payment_status: rideDoc.paymentStatus,
    payment_mode: rideDoc.paymentMode,
    customer_name: rideDoc.customerName,
    customer_phone: rideDoc.customerPhone,
    otp: rideDoc.otp,
    status: rideDoc.status,
    otpVerifiedAt: rideDoc.otpVerifiedAt,
    timestamps: {
      acceptedAt: rideDoc.acceptedAt,
      arrivedAt: rideDoc.arrivedAt,
      startedAt: rideDoc.startedAt,
      completedAt: rideDoc.completedAt,
      createdAt: rideDoc.createdAt,
      updatedAt: rideDoc.updatedAt
    },
    acceptedAt: rideDoc.acceptedAt,
    startedAt: rideDoc.startedAt,
    completedAt: rideDoc.completedAt,
    createdAt: rideDoc.createdAt
  };
};

const createRideRequest = async ({ customerId, customerName, pickup, drop, distance, otp }) => {
  const ride = await Ride.create({
    customerId,
    customerName,
    pickup,
    drop,
    distance,
    otp,
    status: RIDE_STATUS.REQUESTED
  });
  return ride;
};

const getIncomingRidesForDriver = async (driverId, { lat, lng } = {}) => {
  const rides = await Ride.find({
    status: RIDE_STATUS.REQUESTED,
    $or: [{ driverId: null }, { driverId: { $exists: false } }]
  }).sort({ createdAt: -1 });

  return filterRidesByPickupDistance(rides, lat, lng, NEARBY_KM);
};

const getRideHistoryForDriver = async (driverId) =>
  Ride.find({
    driverId,
    status: RIDE_STATUS.COMPLETED
  }).sort({ createdAt: -1 });

const acceptRideAtomic = async ({ rideId, driverId }) =>
  Ride.findOneAndUpdate(
    {
      _id: rideId,
      status: RIDE_STATUS.REQUESTED,
      $or: [{ driverId: null }, { driverId: { $exists: false } }]
    },
    { $set: { driverId, status: RIDE_STATUS.ACCEPTED, acceptedAt: new Date() } },
    { new: true }
  );

const transitionRide = async ({ rideId, driverId, currentStatus, nextStatus, extraUpdates = {} }) =>
  Ride.findOneAndUpdate(
    { _id: rideId, driverId, status: currentStatus },
    { $set: { status: nextStatus, ...extraUpdates } },
    { new: true }
  );

const findRideById = async (rideId) => Ride.findById(rideId);

module.exports = {
  RIDE_STATUS,
  toRidePayload,
  createRideRequest,
  getIncomingRidesForDriver,
  getRideHistoryForDriver,
  acceptRideAtomic,
  transitionRide,
  findRideById
};
