const { Ride } = require("../models/Ride");

const STATUS = {
  REQUESTED: "requested",
  ACCEPTED: "accepted",
  ARRIVED: "arrived",
  STARTED: "started",
  COMPLETED: "completed"
};

const memoryRides = new Map();

const useMongo = () => process.env.RIDE_STORE === "mongo";

const createRide = async (payload) => {
  const rideId = payload.rideId || `${Date.now()}-${Math.floor(Math.random() * 10000)}`;
  const ride = {
    rideId,
    customerId: payload.customerId,
    customerName: payload.customerName || "Passenger",
    pickup: payload.pickup,
    drop: payload.drop,
    distance: payload.distance || "",
    status: STATUS.REQUESTED,
    driverId: null,
    fare: payload.fare || 0,
    otp: payload.otp || "",
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  };

  if (useMongo()) {
    const doc = await Ride.create({
      customerId: payload.customerId,
      customerName: payload.customerName || "Passenger",
      pickup: payload.pickup,
      drop: payload.drop,
      distance: payload.distance || "",
      status: STATUS.REQUESTED,
      otp: payload.otp || "000000"
    });
    return toPayload(doc);
  }

  memoryRides.set(rideId, ride);
  return ride;
};

const getRide = async (rideId) => {
  if (useMongo()) {
    const doc = await Ride.findById(rideId);
    return doc ? toPayload(doc) : null;
  }
  return memoryRides.get(rideId) || null;
};

const acceptRideAtomic = async ({ rideId, driverId }) => {
  if (useMongo()) {
    const doc = await Ride.findOneAndUpdate(
      { _id: rideId, status: STATUS.REQUESTED, $or: [{ driverId: null }, { driverId: { $exists: false } }] },
      { $set: { driverId, status: STATUS.ACCEPTED, acceptedAt: new Date() } },
      { new: true }
    );
    return doc ? toPayload(doc) : null;
  }

  const ride = memoryRides.get(rideId);
  if (!ride || ride.status !== STATUS.REQUESTED || ride.driverId) return null;
  ride.driverId = driverId;
  ride.status = STATUS.ACCEPTED;
  ride.updatedAt = new Date().toISOString();
  memoryRides.set(rideId, ride);
  return ride;
};

const transitionRide = async ({ rideId, driverId, from, to, extra = {} }) => {
  if (useMongo()) {
    const doc = await Ride.findOneAndUpdate(
      { _id: rideId, driverId, status: from },
      { $set: { status: to, ...extra } },
      { new: true }
    );
    return doc ? toPayload(doc) : null;
  }

  const ride = memoryRides.get(rideId);
  if (!ride || ride.driverId !== driverId || ride.status !== from) return null;
  ride.status = to;
  Object.assign(ride, extra);
  ride.updatedAt = new Date().toISOString();
  memoryRides.set(rideId, ride);
  return ride;
};

const toPayload = (doc) => ({
  rideId: doc._id ? doc._id.toString() : doc.rideId,
  customerId: doc.customerId?.toString?.() || doc.customerId,
  customerName: doc.customerName,
  pickup: doc.pickup,
  drop: doc.drop,
  distance: doc.distance,
  status: doc.status,
  driverId: doc.driverId?.toString?.() || doc.driverId || null,
  fare: doc.fare || 0
});

module.exports = {
  STATUS,
  createRide,
  getRide,
  acceptRideAtomic,
  transitionRide
};
