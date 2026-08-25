import { Server } from "socket.io";
import { logger } from "../../config/logger";
import { verifyAccessToken } from "../../utils/jwt.util";
import { HttpError } from "../../utils/http-error";
import { emitNewRideToNearbyDrivers, emitRideUnavailableToDrivers } from "../../utils/nearby-drivers.util";
import {
  getActiveRide,
  getOnlineDriver,
  listOnlineDrivers,
  removeActiveRide,
  removeOnlineDriver,
  upsertActiveRide,
  upsertOnlineDriver,
} from "./ride-booking.store";
import {
  createSocketRideRequest,
  acceptRideAtomically,
  updateRideStatus,
} from "./ride-booking.repository";
import { assertRideTransition } from "./ride-booking.state";
import { persistUserLocation } from "../../utils/driver-location-persist.util";
import { UserModel } from "../../modules/users/users.model";
import { acceptIncomingRide } from "../../modules/driver/ride/driver-ride.service";
import {
  DriverOnlinePayload,
  RideAcceptPayload,
  RideLifecyclePayload,
  RideRequestPayload,
  SocketIdentity,
  SocketWithIdentity,
} from "./ride-booking.types";

const isCoordinate = (value: unknown): value is { lat: number; lng: number } => {
  if (typeof value !== "object" || value === null) return false;
  const maybe = value as { lat?: number; lng?: number };
  return (
    typeof maybe.lat === "number" &&
    Number.isFinite(maybe.lat) &&
    maybe.lat >= -90 &&
    maybe.lat <= 90 &&
    typeof maybe.lng === "number" &&
    Number.isFinite(maybe.lng) &&
    maybe.lng >= -180 &&
    maybe.lng <= 180
  );
};

const toRadians = (value: number) => (value * Math.PI) / 180;

const distanceMeters = (from: { lat: number; lng: number }, to: { lat: number; lng: number }) => {
  const earthRadius = 6371000;
  const dLat = toRadians(to.lat - from.lat);
  const dLng = toRadians(to.lng - from.lng);
  const lat1 = toRadians(from.lat);
  const lat2 = toRadians(to.lat);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.sin(dLng / 2) * Math.sin(dLng / 2) * Math.cos(lat1) * Math.cos(lat2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return earthRadius * c;
};

const roomCustomer = (customerId: string) => `customer_${customerId}`;
const roomDriver = (driverId: string) => `driver_${driverId}`;
const roomRide = (rideId: string) => `ride_${rideId}`;

const extractIdentity = (socket: SocketWithIdentity): SocketIdentity | null => {
  const fromData = socket.data.identity;
  if (fromData?.userId && fromData?.role) {
    return fromData;
  }

  const authToken =
    typeof socket.handshake.auth?.token === "string"
      ? socket.handshake.auth.token
      : typeof socket.handshake.headers.authorization === "string" &&
          socket.handshake.headers.authorization.startsWith("Bearer ")
        ? socket.handshake.headers.authorization.slice(7)
        : null;
  if (!authToken) {
    return null;
  }
  try {
    const payload = verifyAccessToken(authToken);
    if (payload.type !== "access") return null;
    const role = payload.role === "DRIVER" ? "driver" : payload.role === "CUSTOMER" ? "customer" : null;
    if (!role) return null;
    const identity: SocketIdentity = { userId: payload.sub, role };
    socket.data.identity = identity;
    return identity;
  } catch {
    return null;
  }
};

const pickNearestOnlineDriver = (pickup: { lat: number; lng: number }) => {
  const online = listOnlineDrivers();
  if (online.length === 0) return null;

  const sorted = [...online].sort((a, b) => {
    const da = distanceMeters(pickup, a.location);
    const db = distanceMeters(pickup, b.location);
    return da - db;
  });

  return sorted[0] ?? null;
};

const emitSocketError = (socket: SocketWithIdentity, error: unknown) => {
  if (error instanceof HttpError) {
    socket.emit("socket:error", { message: error.message, statusCode: error.statusCode });
    return;
  }
  socket.emit("socket:error", { message: "Internal socket error" });
};

const ensureDriverIdentity = (identity: SocketIdentity | null): SocketIdentity => {
  if (!identity || identity.role !== "driver") {
    throw new HttpError(403, "Driver authentication required");
  }
  return identity;
};

const ensureCustomerIdentity = (identity: SocketIdentity | null): SocketIdentity => {
  if (!identity || identity.role !== "customer") {
    throw new HttpError(403, "Customer authentication required");
  }
  return identity;
};

export const registerRideBookingHandlers = (io: Server, socket: SocketWithIdentity) => {
  socket.on("driver:online", async (payload: DriverOnlinePayload = {}) => {
    try {
      const identity = ensureDriverIdentity(extractIdentity(socket));

      const driverId = payload.driverId ?? identity.userId;
      if (driverId !== identity.userId) {
        throw new HttpError(403, "driverId does not match authenticated driver");
      }
      if (!isCoordinate(payload.location)) {
        throw new HttpError(400, "Invalid location");
      }

      upsertOnlineDriver({
        driverId,
        socketId: socket.id,
        location: payload.location,
        updatedAt: Date.now(),
      });
      socket.join(roomDriver(driverId));

      void UserModel.updateOne(
        { _id: driverId, role: "DRIVER" },
        { $set: { driver_status: "ONLINE" } }
      );

      void persistUserLocation({
        userId: driverId,
        role: "DRIVER",
        lat: payload.location.lat,
        lng: payload.location.lng,
      });

      logger.info({ driverId, socketId: socket.id, location: payload.location }, "Driver is online");
      socket.emit("driver:online:ack", { driverId, ok: true });
    } catch (error) {
      logger.error({ error, socketId: socket.id }, "driver:online failed");
      emitSocketError(socket, error);
    }
  });

  socket.on("ride:request", async (_payload: RideRequestPayload) => {
    try {
      throw new HttpError(
        400,
        "Use REST API POST /api/customers/rides/request then /confirm for booking (vehicle type + fare required)."
      );
    } catch (error) {
      logger.error({ error, socketId: socket.id }, "ride:request failed");
      emitSocketError(socket, error);
    }
  });

  socket.on("ride:accept", async (payload: RideAcceptPayload) => {
    try {
      const identity = ensureDriverIdentity(extractIdentity(socket));
      if (!payload?.rideId) {
        throw new HttpError(400, "rideId is required");
      }

      const driverId = payload.driverId ?? identity.userId;
      if (driverId !== identity.userId) {
        throw new HttpError(403, "driverId does not match authenticated driver");
      }

      const result = await acceptIncomingRide(driverId, payload.rideId);
      const rideId = payload.rideId;
      const active = getActiveRide(rideId);
      const customerId = active?.customerId ?? "";

      upsertActiveRide({
        rideId,
        customerId,
        driverId,
        status: "DRIVER_ASSIGNED",
      });

      socket.join(roomRide(rideId));
      io.to(roomDriver(driverId)).emit("ride:accept:ack", {
        rideId,
        ride_id: rideId,
        status: result.status,
        success: true,
      });

      logger.info({ rideId, driverId, customerId }, "Ride accepted via REST rules");
    } catch (error) {
      logger.warn({ error, socketId: socket.id, payload }, "ride:accept failed");
      emitSocketError(socket, error);
    }
  });

  const onRideStatusEvent = async (
    payload: RideLifecyclePayload,
    expectedCurrent: "DRIVER_ASSIGNED" | "ARRIVED_AT_PICKUP" | "STARTED",
    nextStatus: "ARRIVED_AT_PICKUP" | "STARTED" | "COMPLETED",
    outgoingEvent: "ride:arrived" | "ride:start" | "ride:end"
  ) => {
    const identity = ensureDriverIdentity(extractIdentity(socket));
    if (!payload?.rideId) {
      throw new HttpError(400, "rideId is required");
    }

    const driverId = payload.driverId ?? identity.userId;
    if (driverId !== identity.userId) {
      throw new HttpError(403, "driverId does not match authenticated driver");
    }

    const activeRide = getActiveRide(payload.rideId);
    if (!activeRide) {
      throw new HttpError(404, "Active ride not found");
    }
    if (activeRide.driverId !== driverId) {
      throw new HttpError(403, "Ride does not belong to this driver");
    }

    assertRideTransition(activeRide.status, nextStatus);
    const updatedRide = await updateRideStatus(payload.rideId, expectedCurrent, nextStatus);
    const customerId = activeRide.customerId;

    const updated = {
      ...activeRide,
      status: nextStatus,
    };
    upsertActiveRide(updated);

    io.to(roomCustomer(customerId)).emit(outgoingEvent, {
      rideId: payload.rideId,
      status: nextStatus,
      driverId,
    });
    io.to(roomRide(payload.rideId)).emit("ride:status:update", {
      rideId: payload.rideId,
      status: nextStatus,
      driverId,
      customerId,
    });

    logger.info(
      {
        rideId: payload.rideId,
        from: expectedCurrent,
        to: nextStatus,
        driverId,
        customerId,
        dbStatus: updatedRide.status,
      },
      `${outgoingEvent} completed`
    );

    if (nextStatus === "COMPLETED") {
      removeActiveRide(payload.rideId);
    }
  };

  socket.on("ride:arrived", async (payload: RideLifecyclePayload) => {
    try {
      await onRideStatusEvent(payload, "DRIVER_ASSIGNED", "ARRIVED_AT_PICKUP", "ride:arrived");
    } catch (error) {
      logger.warn({ error, socketId: socket.id, payload }, "ride:arrived failed");
      emitSocketError(socket, error);
    }
  });

  socket.on("ride:start", async (payload: RideLifecyclePayload) => {
    try {
      await onRideStatusEvent(payload, "ARRIVED_AT_PICKUP", "STARTED", "ride:start");
    } catch (error) {
      logger.warn({ error, socketId: socket.id, payload }, "ride:start failed");
      emitSocketError(socket, error);
    }
  });

  socket.on("ride:end", async (payload: RideLifecyclePayload) => {
    try {
      await onRideStatusEvent(payload, "STARTED", "COMPLETED", "ride:end");
    } catch (error) {
      logger.warn({ error, socketId: socket.id, payload }, "ride:end failed");
      emitSocketError(socket, error);
    }
  });

  const onDriverLocationPing = async (payload: {
    driverId?: string;
    location?: { lat?: number; lng?: number };
    lat?: number;
    lng?: number;
    rideId?: string;
    ride_id?: string;
  }) => {
    try {
      const identity = ensureDriverIdentity(extractIdentity(socket));
      const driverId = payload.driverId ?? identity.userId;
      if (driverId !== identity.userId) {
        throw new HttpError(403, "driverId does not match authenticated driver");
      }

      const lat = payload.location?.lat ?? payload.lat;
      const lng = payload.location?.lng ?? payload.lng;
      if (typeof lat !== "number" || typeof lng !== "number") {
        throw new HttpError(400, "Invalid location");
      }

      const location = { lat, lng };
      upsertOnlineDriver({
        driverId,
        socketId: socket.id,
        location,
        updatedAt: Date.now(),
      });

      void persistUserLocation({
        userId: driverId,
        role: "DRIVER",
        lat,
        lng,
        rideId: payload.rideId ?? payload.ride_id,
      });

      socket.emit("location:update:ack", { driverId, ok: true });
    } catch (error) {
      emitSocketError(socket, error);
    }
  };

  socket.on("location:update", onDriverLocationPing);

  socket.on("customer:location", async (payload: {
    lat?: number;
    lng?: number;
    rideId?: string;
    ride_id?: string;
  }) => {
    try {
      const identity = ensureCustomerIdentity(extractIdentity(socket));
      const lat = payload.lat;
      const lng = payload.lng;
      if (typeof lat !== "number" || typeof lng !== "number") {
        throw new HttpError(400, "Invalid location");
      }

      void persistUserLocation({
        userId: identity.userId,
        role: "CUSTOMER",
        lat,
        lng,
        rideId: payload.rideId ?? payload.ride_id,
      });

      socket.emit("customer:location:ack", { ok: true });
    } catch (error) {
      emitSocketError(socket, error);
    }
  });

  socket.on("disconnect", () => {
    const identity = socket.data.identity;
    if (identity?.role === "driver") {
      removeOnlineDriver(identity.userId);
      logger.info({ driverId: identity.userId, socketId: socket.id }, "Driver disconnected and marked offline");
    }
  });
};
