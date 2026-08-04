import { Server as HttpServer } from "http";
import axios from "axios";
import { getDistance } from "geolib";
import { isValidObjectId } from "mongoose";
import { Server, Socket } from "socket.io";
import { env } from "../config/env";
import { logger } from "../config/logger";
import { RideModel } from "../modules/customer/ride/ride.model";
import { UserModel } from "../modules/users/users.model";
import { verifyAccessToken } from "../utils/jwt.util";
import { registerRideBookingHandlers } from "./ride-booking/ride-booking.handlers";
import { persistUserLocation } from "../utils/driver-location-persist.util";

type SocketRole = "customer" | "driver";

type JoinPayload = {
  userId?: string;
  role?: SocketRole;
  rideId?: string;
};

let ioInstance: Server | null = null;
const userSocketMap = new Map<string, Set<string>>();
const socketUserMap = new Map<string, string>();
const socketRoleMap = new Map<string, SocketRole>();
const driverLastLocationUpdateAt = new Map<string, number>();
const DRIVER_LOCATION_THROTTLE_MS = 2000;
const DRIVER_BROADCAST_INTERVAL_MS = 2000;
type SocketWithOptionalIdentity = Socket & {
  data: {
    identity?: { userId: string; role: "customer" | "driver" };
  };
};

const DRIVER_LOCATION_MIN_DELTA_METERS = 5;

const TRACKING_ACTIVE_STATUSES = new Set([
  "DRIVER_ASSIGNED",
  "ARRIVED_AT_PICKUP",
  "STARTED",
  "PICKED_UP",
  "IN_TRANSIT",
]);

type DriverLiveLocation = {
  rideId: string;
  lat: number;
  lng: number;
  bearing: number;
  speed: number;
  updatedAt: number;
};

type DriverLocationBroadcastPayload = {
  ride_id: string;
  lat: number;
  lng: number;
  bearing: number;
  speed: number;
  timestamp: number;
  distance_km: string;
  eta_min: number;
};

type RideTrackingUpdatePayload = {
  rideId: string;
  lat: number;
  lng: number;
  bearing: number;
  speed: number;
  timestamp: number;
  stage: string;
};

const driverLiveLocationMap = new Map<string, DriverLiveLocation>();
const driverBroadcastTimerMap = new Map<string, NodeJS.Timeout>();
const driverLastBroadcastSignatureMap = new Map<string, string>();
const rideRouteEmittedMap = new Set<string>();

const getRoomNameForUser = (userId: string, role: SocketRole) => {
  if (role === "driver") {
    return [`drivers`, `driver_${userId}`];
  }
  return [`customer_${userId}`];
};

const getRideRooms = (rideId: string) => [`ride:${rideId}`, `ride_${rideId}`];

const normalizeRoleFromToken = (role?: string): SocketRole | null => {
  if (role === "CUSTOMER") {
    return "customer";
  }
  if (role === "DRIVER") {
    return "driver";
  }
  return null;
};

const getSocketToken = (socket: Socket): string | null => {
  const authToken = socket.handshake.auth?.token;
  if (typeof authToken === "string" && authToken.trim().length > 0) {
    return authToken;
  }

  const authorization = socket.handshake.headers.authorization;
  if (typeof authorization === "string" && authorization.startsWith("Bearer ")) {
    return authorization.slice(7);
  }

  return null;
};

const getAuthIdentity = (socket: Socket): { userId: string; role: SocketRole } | null => {
  const token = getSocketToken(socket);
  if (!token) {
    return null;
  }

  try {
    const payload = verifyAccessToken(token);
    if (payload.type !== "access") {
      return null;
    }

    const role = normalizeRoleFromToken(payload.role);
    if (!role) {
      return null;
    }

    return { userId: payload.sub, role };
  } catch {
    return null;
  }
};

const trackUserSocket = (userId: string, socketId: string) => {
  const currentSockets = userSocketMap.get(userId) ?? new Set<string>();
  currentSockets.add(socketId);
  userSocketMap.set(userId, currentSockets);
  socketUserMap.set(socketId, userId);
};

const untrackUserSocket = (socketId: string) => {
  const userId = socketUserMap.get(socketId);
  if (!userId) {
    return;
  }

  const sockets = userSocketMap.get(userId);
  if (!sockets) {
    socketUserMap.delete(socketId);
    return;
  }

  sockets.delete(socketId);
  if (sockets.size === 0) {
    userSocketMap.delete(userId);
  } else {
    userSocketMap.set(userId, sockets);
  }
  socketUserMap.delete(socketId);
  socketRoleMap.delete(socketId);
};

const joinRideRoom = (socket: Socket, rideId?: string) => {
  if (!rideId) {
    return;
  }
  const rooms = getRideRooms(rideId);
  for (const room of rooms) {
    socket.join(room);
  }
};

const handleJoinEvent = (socket: Socket) => {
  socket.on("join", (payload: JoinPayload = {}) => {
    const authenticatedIdentity = getAuthIdentity(socket);
    const userId = payload.userId ?? authenticatedIdentity?.userId;
    const role = payload.role ?? authenticatedIdentity?.role;
    console.log("JOIN EVENT:", userId, role);

    if (!userId || !role) {
      console.warn("Invalid join payload");
      socket.emit("socket_error", { message: "Invalid join payload" });
      return;
    }

    if (
      authenticatedIdentity &&
      (authenticatedIdentity.userId !== userId || authenticatedIdentity.role !== role)
    ) {
      socket.emit("socket_error", { message: "Join payload does not match authenticated user" });
      return;
    }

    if (role === "driver") {
      socket.join("drivers");
      socket.join(`driver_${userId}`);
      console.log("driver joined:", userId);
      logger.info(`driver joined: ${userId}`);
      void UserModel.updateOne(
        { _id: userId, role: "DRIVER" },
        { $set: { driver_status: "ONLINE" } }
      ).catch((error: unknown) => {
        logger.error({ error, userId }, "Failed to update driver status to ONLINE on connect");
      });
    }

    if (role === "customer") {
      socket.join(`customer_${userId}`);
      logger.info(`customer joined: ${userId}`);
      if (payload.rideId) {
        joinRideRoom(socket, payload.rideId);
      }
    }

    if (role !== "customer") {
      joinRideRoom(socket, payload.rideId);
    }
    trackUserSocket(userId, socket.id);
    socketRoleMap.set(socket.id, role);

    const joinedRooms = Array.from(socket.rooms);
    logger.info(
      {
        socketId: socket.id,
        rooms: joinedRooms,
      },
      "Socket room assignment complete"
    );

    const rooms = getRoomNameForUser(userId, role);
    socket.emit("joined", { userId, role, rooms });
  });
};

type DriverLocationPayload = {
  rideId?: string;
  ride_id?: string;
  driver_id?: string;
  lat?: number;
  lng?: number;
};

const isValidCoordinate = (value: unknown, min: number, max: number) => {
  return typeof value === "number" && Number.isFinite(value) && value >= min && value <= max;
};

const toFiniteNumberOr = (value: unknown, fallback: number) => {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
};

const toFiniteNumber = (value: unknown): number | null => {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return null;
};

const calculateETA = (distanceMeters: number) => {
  const avgSpeedMetersPerSecond = (40 * 1000) / 3600;
  const timeSeconds = distanceMeters / avgSpeedMetersPerSecond;
  return Math.max(0, Math.round(timeSeconds / 60));
};

const resolveTargetPoint = (status: string, pickup: { lat: number; lng: number }, drop: { lat: number; lng: number }) => {
  const normalized = status.toUpperCase();
  if (
    normalized === "STARTED" ||
    normalized === "PICKED_UP" ||
    normalized === "IN_TRANSIT" ||
    normalized === "COMPLETED"
  ) {
    return drop;
  }
  return pickup;
};

const buildDriverLocationPayload = async (
  liveLocation: DriverLiveLocation
): Promise<DriverLocationBroadcastPayload | null> => {
  const ride = await RideModel.findById(liveLocation.rideId).lean();
  if (!ride?.pickup || !ride?.drop) {
    return null;
  }
  const target = resolveTargetPoint(ride.status, ride.pickup, ride.drop);
  const distanceMeters = getDistance(
    { latitude: liveLocation.lat, longitude: liveLocation.lng },
    { latitude: target.lat, longitude: target.lng }
  );

  return {
    ride_id: liveLocation.rideId,
    lat: liveLocation.lat,
    lng: liveLocation.lng,
    bearing: liveLocation.bearing,
    speed: liveLocation.speed,
    timestamp: Date.now(),
    distance_km: (distanceMeters / 1000).toFixed(2),
    eta_min: calculateETA(distanceMeters),
  };
};

const buildRideTrackingPayload = async (
  liveLocation: DriverLiveLocation
): Promise<RideTrackingUpdatePayload | null> => {
  const ride = await RideModel.findById(liveLocation.rideId).lean();
  if (!ride) return null;
  return {
    rideId: String(ride._id),
    lat: liveLocation.lat,
    lng: liveLocation.lng,
    bearing: liveLocation.bearing,
    speed: liveLocation.speed,
    timestamp: Date.now(),
    stage: ride.status,
  };
};

const getDriverLiveLocation = (driverId: string) => {
  return driverLiveLocationMap.get(driverId) ?? null;
};

const buildLocationSignature = (location: DriverLiveLocation) => {
  return `${location.rideId}:${location.lat.toFixed(6)}:${location.lng.toFixed(6)}:${location.bearing.toFixed(1)}:${location.speed.toFixed(1)}`;
};

const shouldBroadcastLocationDelta = (
  previous: DriverLiveLocation | null,
  next: DriverLiveLocation
) => {
  if (!previous) return true;
  const movedMeters = getDistance(
    { latitude: previous.lat, longitude: previous.lng },
    { latitude: next.lat, longitude: next.lng }
  );
  const bearingChanged = Math.abs(previous.bearing - next.bearing) >= 5;
  const speedChanged = Math.abs(previous.speed - next.speed) >= 1;
  return movedMeters >= DRIVER_LOCATION_MIN_DELTA_METERS || bearingChanged || speedChanged;
};

const stopDriverBroadcast = (driverId: string) => {
  const timer = driverBroadcastTimerMap.get(driverId);
  if (timer) {
    clearInterval(timer);
    driverBroadcastTimerMap.delete(driverId);
  }
};

const startDriverBroadcast = (driverId: string) => {
  if (driverBroadcastTimerMap.has(driverId)) return;

  const timer = setInterval(async () => {
    const location = getDriverLiveLocation(driverId);
    if (!location || !ioInstance) {
      stopDriverBroadcast(driverId);
      return;
    }
    const signature = buildLocationSignature(location);
    const lastSignature = driverLastBroadcastSignatureMap.get(driverId);
    if (lastSignature === signature) {
      return;
    }
    driverLastBroadcastSignatureMap.set(driverId, signature);
    const payload = await buildDriverLocationPayload(location);
    const trackingPayload = await buildRideTrackingPayload(location);
    if (!payload) {
      return;
    }
    const rideRooms = getRideRooms(location.rideId);
    for (const room of rideRooms) {
      ioInstance.to(room).emit("driver_location", payload);
      if (trackingPayload) {
        ioInstance.to(room).emit("ride-tracking-update", trackingPayload);
      }
    }
  }, DRIVER_BROADCAST_INTERVAL_MS);

  driverBroadcastTimerMap.set(driverId, timer);
};

const emitRideRouteIfNeeded = async (rideId: string) => {
  if (rideRouteEmittedMap.has(rideId) || !ioInstance) {
    return;
  }
  if (!isValidObjectId(rideId)) {
    return;
  }
  try {
    const ride = await RideModel.findById(rideId).lean();
    if (!ride?.pickup || !ride?.drop) {
      return;
    }
    const { lat: pickupLat, lng: pickupLng } = ride.pickup;
    const { lat: dropLat, lng: dropLng } = ride.drop;
    if (
      typeof pickupLat !== "number" ||
      typeof pickupLng !== "number" ||
      typeof dropLat !== "number" ||
      typeof dropLng !== "number"
    ) {
      return;
    }

    const osrmBase = env.OSRM_URL.replace(/\/$/, "");
    const url =
      `${osrmBase}/route/v1/driving/` +
      `${pickupLng},${pickupLat};${dropLng},${dropLat}?overview=full&geometries=geojson`;
    const response = await axios.get(url);
    const route = response.data?.routes?.[0]?.geometry;
    if (!route) {
      return;
    }

    rideRouteEmittedMap.add(rideId);
    for (const room of getRideRooms(rideId)) {
      ioInstance.to(room).emit("route", route);
    }
  } catch (error) {
    logger.warn({ error, rideId }, "Failed to fetch or emit OSRM route");
  }
};

const handleDriverLocationEvent = (socket: Socket) => {
  const onDriverLocation = async (payload: DriverLocationPayload = {}) => {
    const role = socketRoleMap.get(socket.id);
    if (role !== "driver") {
      logger.warn({ socketId: socket.id }, "Ignoring driver_location from non-driver socket");
      return;
    }

    const rideId = payload.ride_id ?? payload.rideId;
    const lat = toFiniteNumber(payload.lat);
    const lng = toFiniteNumber(payload.lng);
    const bearing = toFiniteNumberOr(toFiniteNumber((payload as Record<string, unknown>).bearing), 0);
    const speed = toFiniteNumberOr(toFiniteNumber((payload as Record<string, unknown>).speed), 0);
    const socketDriverId = socketUserMap.get(socket.id);
    const payloadDriverId =
      typeof payload.driver_id === "string" && payload.driver_id.trim().length > 0
        ? payload.driver_id.trim()
        : undefined;
    const driverId = payloadDriverId ?? socketDriverId;

    const hasValidRideId = typeof rideId === "string" && isValidObjectId(rideId);
    const hasValidLat = isValidCoordinate(lat, -90, 90);
    const hasValidLng = isValidCoordinate(lng, -180, 180);

    if (!hasValidRideId || !hasValidLat || !hasValidLng) {
      logger.warn(
        { socketId: socket.id, payload },
        "Ignoring invalid driver_location payload"
      );
      return;
    }
    const latitude = lat as number;
    const longitude = lng as number;
    if (!driverId || !socketDriverId) {
      logger.warn({ socketId: socket.id }, "Ignoring driver_location without driver id");
      return;
    }
    if (payloadDriverId && payloadDriverId !== socketDriverId) {
      logger.warn(
        { socketId: socket.id, payloadDriverId, socketDriverId },
        "Ignoring driver_location: driver_id does not match socket user"
      );
      return;
    }

    const now = Date.now();
    const lastUpdateAt = driverLastLocationUpdateAt.get(driverId) ?? 0;
    if (now - lastUpdateAt < DRIVER_LOCATION_THROTTLE_MS) {
      return;
    }
    driverLastLocationUpdateAt.set(driverId, now);

    const ride = await RideModel.findById(rideId).lean();
    if (!ride) {
      logger.warn({ socketId: socket.id, rideId }, "Ignoring driver_location for unknown ride");
      return;
    }
    if (!ride.driver_id || String(ride.driver_id) !== driverId) {
      logger.warn(
        { socketId: socket.id, rideId, driverId },
        "Ignoring driver_location for unassigned driver"
      );
      return;
    }
    if (!TRACKING_ACTIVE_STATUSES.has(ride.status)) {
      logger.warn(
        { socketId: socket.id, rideId, status: ride.status },
        "Ignoring driver location for inactive/non-trackable ride state"
      );
      return;
    }

    console.log("Driver Location:", driverId, lat, lng);

    void persistUserLocation({
      userId: driverId,
      role: "DRIVER",
      lat: latitude,
      lng: longitude,
      rideId: String(ride._id),
    });

    const nextLocation: DriverLiveLocation = {
      rideId: String(ride._id),
      lat: latitude,
      lng: longitude,
      bearing,
      speed,
      updatedAt: Date.now(),
    };
    const prevLocation = driverLiveLocationMap.get(driverId) ?? null;
    if (!shouldBroadcastLocationDelta(prevLocation, nextLocation)) {
      return;
    }
    driverLiveLocationMap.set(driverId, nextLocation);
    startDriverBroadcast(driverId);

    const io = getIO();
    const rideRooms = getRideRooms(String(ride._id));
    const locationPayload = await buildDriverLocationPayload({
      rideId: String(ride._id),
      lat: latitude,
      lng: longitude,
      bearing,
      speed,
      updatedAt: Date.now(),
    });
    if (!locationPayload) {
      return;
    }
    const rideTrackingPayload = await buildRideTrackingPayload({
      rideId: String(ride._id),
      lat: latitude,
      lng: longitude,
      bearing,
      speed,
      updatedAt: Date.now(),
    });

    for (const room of rideRooms) {
      io.to(room).emit("driver_location_update", {
        rideId,
        lat: latitude,
        lng: longitude,
        bearing,
        speed,
        timestamp: Date.now(),
      });
      io.to(room).emit("driver_location", locationPayload);
      if (rideTrackingPayload) {
        io.to(room).emit("ride-tracking-update", rideTrackingPayload);
      }
    }
    io.to(`customer_${String(ride.customer_id)}`).emit("driver_location_update", {
      rideId,
      lat: latitude,
      lng: longitude,
      bearing,
      speed,
      timestamp: Date.now(),
    });
    io.to(`customer_${String(ride.customer_id)}`).emit("driver_location", locationPayload);
    if (rideTrackingPayload) {
      io.to(`customer_${String(ride.customer_id)}`).emit("ride-tracking-update", rideTrackingPayload);
    }
    void emitRideRouteIfNeeded(String(ride._id));
    logger.info(
      { socketId: socket.id, rideRooms, rideId: String(ride._id), lat, lng },
      "Driver location forwarded to customer and ride room"
    );
  };

  socket.on("driver_location", onDriverLocation);
  socket.on("driver_location_update", onDriverLocation);
  socket.on("driver-location-update", onDriverLocation);
};

export const initializeSocketServer = (httpServer: HttpServer) => {
  if (ioInstance) {
    return ioInstance;
  }

  ioInstance = new Server(httpServer, {
    cors: {
      origin: "*",
      methods: ["GET", "POST"],
    },
    transports: ["websocket"],
  });

  ioInstance.on("connection", (socket) => {
    console.log("Socket connected:", socket.id);
    logger.info(`Socket connected: ${socket.id}`);
    handleJoinEvent(socket);
    handleDriverLocationEvent(socket);
    registerRideBookingHandlers(ioInstance as Server, socket as SocketWithOptionalIdentity);

    socket.on("join_ride_room", (rideId?: string) => {
      if (!rideId) {
        return;
      }
      joinRideRoom(socket, rideId);
      logger.info(`Socket ${socket.id} joined ride rooms for ${rideId}`);
    });

    socket.on("disconnect", () => {
      const userId = socketUserMap.get(socket.id);
      const role = socketRoleMap.get(socket.id);
      logger.warn({ socketId: socket.id, userId, role }, "Socket disconnected");
      untrackUserSocket(socket.id);
      if (role === "driver" && userId) {
        driverLastLocationUpdateAt.delete(userId);
        stopDriverBroadcast(userId);
        const lastKnown = driverLiveLocationMap.get(userId);
        if (lastKnown && ioInstance) {
          void RideModel.findById(lastKnown.rideId)
            .lean()
            .then((ride) => {
              if (!ride) return;
              const payload = {
                rideId: lastKnown.rideId,
                driverId: userId,
                timestamp: Date.now(),
                message: "Driver temporarily offline. Reconnecting...",
                lastKnownLocation: {
                  lat: lastKnown.lat,
                  lng: lastKnown.lng,
                  bearing: lastKnown.bearing,
                  speed: lastKnown.speed,
                  updatedAt: lastKnown.updatedAt,
                },
              };
              for (const room of getRideRooms(lastKnown.rideId)) {
                ioInstance?.to(room).emit("ride-tracking-driver-offline", payload);
              }
              ioInstance
                ?.to(`customer_${String(ride.customer_id)}`)
                .emit("ride-tracking-driver-offline", payload);
            })
            .catch((error: unknown) => {
              logger.warn({ error, userId }, "Failed to notify customer about driver disconnect");
            });
        }
        void UserModel.updateOne(
          { _id: userId, role: "DRIVER" },
          { $set: { driver_status: "OFFLINE" } }
        ).catch((error: unknown) => {
          logger.error({ error, userId }, "Failed to update driver status to OFFLINE on disconnect");
        });
      }
    });
  });

  logger.info("Socket.io server initialized");
  return ioInstance;
};

export const getIo = () => {
  if (!ioInstance) {
    throw new Error("Socket.io not initialized");
  }
  return ioInstance;
};

export const getIO = () => getIo();
export const io = getIO;

export const emitToDrivers = (event: string, payload: Record<string, unknown>) => {
  const io = getIO();
  const roomSize = io.sockets.adapter.rooms.get("drivers")?.size ?? 0;
  if (roomSize === 0) {
    logger.warn({ event }, "No connected driver sockets for drivers room");
  }
  io.to("drivers").emit(event, payload);
  logger.info(
    {
      event,
      room: "drivers",
      payload,
    },
    "Emitted event to drivers room"
  );
};

const CUSTOMER_EVENT_ALIASES: Record<string, string> = {
  ride_accepted: "ride:accepted",
  ride_status_update: "ride:status:update",
  driver_location: "driver:location:update",
  driver_location_update: "driver:location:update",
  payment_success: "payment:success",
  invoice_updated: "invoice:updated",
};

export const emitToCustomer = (
  customerId: string,
  event: string,
  payload: Record<string, unknown>
) => {
  if (!ioInstance) {
    logger.warn({ customerId, event }, "Socket server not initialized while emitting to customer");
    return;
  }
  const room = `customer_${customerId}`;
  const roomSize = ioInstance.sockets.adapter.rooms.get(room)?.size ?? 0;
  if (roomSize === 0) {
    logger.warn({ customerId, event }, "No connected customer sockets in room");
    console.warn("No clients in room:", room);
  }
  console.log(`Emitting ${event} to:`, room);
  ioInstance.to(room).emit(event, payload);
  const alias = CUSTOMER_EVENT_ALIASES[event];
  if (alias) {
    ioInstance.to(room).emit(alias, payload);
  }
};

export const emitToRide = (rideId: string, event: string, payload: Record<string, unknown>) => {
  if (!ioInstance) {
    logger.warn({ rideId, event }, "Socket server not initialized while emitting to ride room");
    return;
  }
  const rooms = getRideRooms(rideId);
  const totalSize = rooms.reduce(
    (acc, room) => acc + (ioInstance?.sockets.adapter.rooms.get(room)?.size ?? 0),
    0
  );
  if (totalSize === 0) {
    logger.warn({ rideId, event }, "No connected sockets in ride room");
  }
  for (const room of rooms) {
    ioInstance.to(room).emit(event, payload);
  }
};

export const joinRideRoomForUser = (userId: string, rideId: string) => {
  const userSockets = userSocketMap.get(userId);
  if (!ioInstance || !userSockets) {
    return;
  }

  userSockets.forEach((socketId) => {
    const socket = ioInstance?.sockets.sockets.get(socketId);
    for (const room of getRideRooms(rideId)) {
      socket?.join(room);
      logger.info({ socketId, room, userId }, "User joined ride room");
    }
  });
};
