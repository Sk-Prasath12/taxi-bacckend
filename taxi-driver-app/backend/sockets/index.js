const jwt = require("jsonwebtoken");
const mongoose = require("mongoose");
const Driver = require("../models/Driver");
const { logger } = require("./logger");
const { nearestDriver } = require("./geo");
const { STATUS, createRide, getRide, acceptRideAtomic, transitionRide } = require("./rideRepository");

const activeDrivers = new Map();
const activeRides = new Map();
const customerSockets = new Map();
const isMongoReady = () => mongoose.connection.readyState === 1;

const parseDriverAuth = (socket, { token, driverId }) => {
  const accessToken = token || socket.handshake.auth?.token;
  if (!accessToken || !driverId || !process.env.JWT_SECRET) return { ok: false, message: "Missing driver auth data." };
  try {
    const payload = jwt.verify(accessToken, process.env.JWT_SECRET);
    if (String(payload.driverId) !== String(driverId)) {
      return { ok: false, message: "Driver token mismatch." };
    }
    return { ok: true };
  } catch (error) {
    return { ok: false, message: "Invalid driver JWT." };
  }
};

const registerSocketServer = (io) => {
  io.on("connection", (socket) => {
    logger.info("Socket connected", { socketId: socket.id });

    socket.on("driver:online", (payload = {}, ack = () => {}) => {
      const auth = parseDriverAuth(socket, payload);
      if (!auth.ok) {
        logger.warn("Driver online rejected", { socketId: socket.id, reason: auth.message });
        ack({ success: false, message: auth.message });
        return;
      }

      activeDrivers.set(String(payload.driverId), {
        socketId: socket.id,
        location: payload.location || null,
        status: "available"
      });
      socket.data.driverId = String(payload.driverId);
      socket.join(`driver:${payload.driverId}`);
      if (isMongoReady()) {
        Driver.findByIdAndUpdate(payload.driverId, {
          status: "online",
          currentLocation: {
            type: "Point",
            coordinates: [payload.location?.lng || 0, payload.location?.lat || 0]
          }
        }).catch(() => {});
      }
      logger.info("Driver online", { driverId: payload.driverId, location: payload.location || null });
      ack({ success: true });
    });

    socket.on("location:update", (payload = {}, ack = () => {}) => {
      const driverId = socket.data.driverId || String(payload.driverId || "");
      const existing = activeDrivers.get(driverId);
      if (!existing) {
        ack({ success: false, message: "Driver not online." });
        return;
      }
      existing.location = payload.location || existing.location;
      activeDrivers.set(driverId, existing);
      if (isMongoReady() && payload.location) {
        Driver.findByIdAndUpdate(driverId, {
          currentLocation: {
            type: "Point",
            coordinates: [payload.location?.lng || 0, payload.location?.lat || 0]
          }
        }).catch(() => {});
      }
      ack({ success: true });
    });

    socket.on("join", (payload = {}) => {
      const userId = String(payload.userId || payload.driverId || "");
      const role = String(payload.role || "driver");
      if (userId) {
        socket.join(`${role}:${userId}`);
        if (role === "driver") socket.data.driverId = userId;
      }
    });

    socket.on("join_ride_room", (rideId) => {
      const id = String(rideId || "");
      if (id) socket.join(`ride:${id}`);
    });

    socket.on("customer:connect", (payload = {}, ack = () => {}) => {
      const customerId = String(payload.customerId || "");
      if (!customerId) {
        ack({ success: false, message: "customerId is required." });
        return;
      }
      customerSockets.set(customerId, socket.id);
      socket.data.customerId = customerId;
      socket.join(`customer:${customerId}`);
      logger.info("Customer connected", { customerId, socketId: socket.id });
      ack({ success: true });
    });

    socket.on("customer:ride:request", async (payload = {}, ack = () => {}) => {
      try {
        const customerId = String(payload.customerId || socket.data.customerId || "");
        if (!customerId || !payload.pickup || !payload.drop) {
          ack({ success: false, message: "customerId, pickup, drop required." });
          return;
        }

        const ride = await createRide({
          customerId,
          customerName: payload.customerName,
          pickup: payload.pickup,
          drop: payload.drop,
          distance: payload.distance
        });
        logger.info("Ride requested", { rideId: ride.rideId, customerId });

        const chosen = await selectBestDriver(activeDrivers, payload.pickup);
        if (!chosen) {
          io.to(`customer:${customerId}`).emit("ride:no_driver", { rideId: ride.rideId });
          ack({ success: true, rideId: ride.rideId, assigned: false });
          return;
        }

        io.to(`driver:${chosen.driverId}`).emit("ride:new", ride);
        logger.info("Ride dispatched", { rideId: ride.rideId, driverId: chosen.driverId, distanceKm: chosen.distanceKm });
        ack({ success: true, rideId: ride.rideId, assigned: true, driverId: chosen.driverId });
      } catch (error) {
        logger.error("ride request error", { message: error.message });
        ack({ success: false, message: "Unable to request ride." });
      }
    });

    socket.on("ride:accept", async (payload = {}, ack = () => {}) => {
      const driverId = socket.data.driverId;
      if (!driverId) {
        ack({ success: false, message: "Driver not authenticated." });
        return;
      }
      const ride = await acceptRideAtomic({ rideId: payload.rideId, driverId });
      if (!ride) {
        logger.warn("ride accept rejected", { rideId: payload.rideId, driverId });
        ack({ success: false, message: "Ride already accepted/unavailable." });
        return;
      }

      const driver = activeDrivers.get(driverId);
      if (driver) {
        driver.status = "busy";
        activeDrivers.set(driverId, driver);
      }
      if (isMongoReady()) {
        Driver.findByIdAndUpdate(driverId, { status: "busy" }).catch(() => {});
      }
      activeRides.set(ride.rideId, { customerId: ride.customerId, driverId });
      io.to(`customer:${ride.customerId}`).emit("ride:accepted", ride);
      io.to(`driver:${driverId}`).emit("ride:update", ride);
      logger.info("Ride accepted", { rideId: ride.rideId, driverId, customerId: ride.customerId });
      ack({ success: true, ride });
    });

    socket.on("ride:arrived", async (payload = {}, ack = () => {}) => {
      await emitLifecycle(io, socket, payload, ack, STATUS.ACCEPTED, STATUS.ARRIVED, "arrived");
    });

    socket.on("ride:start", async (payload = {}, ack = () => {}) => {
      await emitLifecycle(io, socket, payload, ack, STATUS.ARRIVED, STATUS.STARTED, "started");
    });

    socket.on("ride:end", async (payload = {}, ack = () => {}) => {
      const ride = await emitLifecycle(io, socket, payload, ack, STATUS.STARTED, STATUS.COMPLETED, "completed", {
        fare: Number(payload.fare || 0)
      });
      if (ride) {
        const driver = activeDrivers.get(ride.driverId);
        if (driver) {
          driver.status = "available";
          activeDrivers.set(ride.driverId, driver);
        }
        if (isMongoReady()) {
          Driver.findByIdAndUpdate(ride.driverId, { status: "online" }).catch(() => {});
        }
        activeRides.delete(ride.rideId);
        io.to(`customer:${ride.customerId}`).emit("ride:payment", { rideId: ride.rideId, fare: ride.fare, currency: "INR" });
      }
    });

    socket.on("ride:location", async (payload = {}, ack = () => {}) => {
      const driverId = socket.data.driverId;
      if (!driverId || !payload.rideId || !payload.location) {
        ack({ success: false, message: "rideId and location required." });
        return;
      }
      const ride = await getRide(payload.rideId);
      if (!ride || String(ride.driverId) !== String(driverId)) {
        ack({ success: false, message: "Ride not found for driver." });
        return;
      }
      io.to(`customer:${ride.customerId}`).emit("ride:tracking", {
        rideId: ride.rideId,
        driverId,
        location: payload.location
      });
      ack({ success: true });
    });

    socket.on("disconnect", () => {
      const driverId = socket.data.driverId;
      const customerId = socket.data.customerId;
      if (driverId) {
        activeDrivers.delete(driverId);
        if (isMongoReady()) {
          Driver.findByIdAndUpdate(driverId, { status: "offline" }).catch(() => {});
        }
        logger.info("Driver disconnected", { driverId });
      }
      if (customerId) {
        customerSockets.delete(customerId);
        logger.info("Customer disconnected", { customerId });
      }
    });
  });
};

const emitLifecycle = async (io, socket, payload, ack, from, to, logStatus, extra = {}) => {
  const driverId = socket.data.driverId;
  if (!driverId) {
    ack({ success: false, message: "Driver not authenticated." });
    return null;
  }
  const ride = await transitionRide({ rideId: payload.rideId, driverId, from, to, extra });
  if (!ride) {
    ack({ success: false, message: `Invalid state transition: ${from} -> ${to}` });
    return null;
  }
  io.to(`customer:${ride.customerId}`).emit("ride:update", ride);
  io.to(`driver:${driverId}`).emit("ride:update", ride);
  logger.info(`Ride ${logStatus}`, { rideId: ride.rideId, driverId });
  ack({ success: true, ride });
  return ride;
};

const selectBestDriver = async (activeDriversMap, pickup) => {
  if (isMongoReady()) {
    const nearest = await Driver.findOne({
      status: "online",
      currentLocation: {
        $near: {
          $geometry: { type: "Point", coordinates: [pickup.lng, pickup.lat] }
        }
      }
    })
      .select("_id")
      .lean();
    if (nearest && activeDriversMap.has(nearest._id.toString())) {
      const active = activeDriversMap.get(nearest._id.toString());
      if (active?.status === "available") {
        return { driverId: nearest._id.toString(), ...active, distanceKm: null };
      }
    }
  }
  return nearestDriver(activeDriversMap, pickup);
};

module.exports = { registerSocketServer };
