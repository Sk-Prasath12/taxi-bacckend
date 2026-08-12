import type { Server } from "socket.io";
import { Types } from "mongoose";
import { env } from "../config/env";
import { logger } from "../config/logger";
import { RideModel } from "../modules/customer/ride/ride.model";
import { UserModel } from "../modules/users/users.model";
import { listOnlineDrivers, getOnlineDriver } from "../socket/ride-booking/ride-booking.store";

export type GeoPoint = { lat: number; lng: number };

export type NearbyDispatchOptions = {
  maxRadiusMeters?: number;
  vehicleTypeId?: string | null;
  rejectedDriverIds?: (string | Types.ObjectId)[];
};

const DEFAULT_RADIUS_M = Math.round(env.NEARBY_DRIVER_RADIUS_KM * 1000);
const LOCATION_MAX_AGE_MS = 15 * 60 * 1000;
const TERMINAL_RIDE_STATUSES = ["COMPLETED", "CANCELLED"] as const;

export const getNearbyDriverRadiusMeters = (): number => DEFAULT_RADIUS_M;
export const getNearbyDriverRadiusKm = (): number => env.NEARBY_DRIVER_RADIUS_KM;

const toRadians = (value: number) => (value * Math.PI) / 180;

export const distanceMeters = (from: GeoPoint, to: GeoPoint) => {
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

const pointFromUserDoc = (driver: {
  driver_location?: { coordinates?: number[] };
}): GeoPoint | null => {
  const coords = driver.driver_location?.coordinates;
  if (!Array.isArray(coords) || coords.length < 2) return null;
  const lng = coords[0];
  const lat = coords[1];
  if (typeof lat !== "number" || typeof lng !== "number") return null;
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  return { lat, lng };
};

const normalizeRejected = (ids?: (string | Types.ObjectId)[]) =>
  (ids ?? []).map((id) => String(id)).filter(Boolean);

/** Drivers currently assigned to a non-terminal ride. */
export const findBusyDriverIds = async (): Promise<string[]> => {
  const ids = await RideModel.distinct("driver_id", {
    driver_id: { $ne: null },
    status: { $nin: [...TERMINAL_RIDE_STATUSES] },
  });
  return ids.map((id) => String(id)).filter(Boolean);
};

type CandidateDriver = { driverId: string; location: GeoPoint; source: "memory" | "db" };

/**
 * Resolves ONLINE, verified drivers with fresh GPS near pickup (memory store + MongoDB).
 */
export const findNearbyEligibleDrivers = async (
  pickup: GeoPoint,
  options: NearbyDispatchOptions = {}
): Promise<CandidateDriver[]> => {
  const maxRadiusMeters = options.maxRadiusMeters ?? DEFAULT_RADIUS_M;
  const rejected = new Set(normalizeRejected(options.rejectedDriverIds));
  const busy = new Set(await findBusyDriverIds());
  const staleBefore = new Date(Date.now() - LOCATION_MAX_AGE_MS);
  const seen = new Map<string, CandidateDriver>();

  for (const mem of listOnlineDrivers()) {
    if (rejected.has(mem.driverId) || busy.has(mem.driverId)) continue;
    if (Date.now() - mem.updatedAt > LOCATION_MAX_AGE_MS) continue;
    const dist = distanceMeters(pickup, mem.location);
    if (dist > maxRadiusMeters) continue;
    seen.set(mem.driverId, {
      driverId: mem.driverId,
      location: mem.location,
      source: "memory",
    });
  }

  try {
    const dbDrivers = await UserModel.find({
      role: "DRIVER",
      driver_status: "ONLINE",
      is_blocked: { $ne: true },
      is_driver_verified: true,
      driver_verification_status: "APPROVED",
      driver_location_updated_at: { $gte: staleBefore },
      driver_location: {
        $near: {
          $geometry: {
            type: "Point",
            coordinates: [pickup.lng, pickup.lat],
          },
          $maxDistance: maxRadiusMeters,
        },
      },
    })
      .select("_id driver_location")
      .limit(40)
      .lean();

    for (const row of dbDrivers) {
      const driverId = String(row._id);
      if (rejected.has(driverId) || busy.has(driverId) || seen.has(driverId)) continue;
      const location = pointFromUserDoc(row);
      if (!location) continue;
      seen.set(driverId, { driverId, location, source: "db" });
    }
  } catch (error) {
    logger.warn({ error }, "Geo query for nearby drivers failed; using in-memory only");
  }

  if (seen.size === 0) {
    const onlineDrivers = await UserModel.find({
      role: "DRIVER",
      driver_status: "ONLINE",
      is_blocked: { $ne: true },
      is_driver_verified: true,
      driver_verification_status: "APPROVED",
    })
      .select("_id driver_location")
      .limit(20)
      .lean();

    for (const row of onlineDrivers) {
      const driverId = String(row._id);
      if (rejected.has(driverId) || busy.has(driverId) || seen.has(driverId)) continue;
      const location = pointFromUserDoc(row);
      if (!location) continue;
      const dist = distanceMeters(pickup, location);
      if (dist > maxRadiusMeters) continue;
      seen.set(driverId, { driverId, location, source: "db" });
    }
  }

  return Array.from(seen.values()).sort(
    (a, b) => distanceMeters(pickup, a.location) - distanceMeters(pickup, b.location)
  );
};

export const getDriverLocationForMatching = async (
  driverId: string
): Promise<GeoPoint | null> => {
  const mem = getOnlineDriver(driverId);
  if (mem && Date.now() - mem.updatedAt <= LOCATION_MAX_AGE_MS) {
    return mem.location;
  }
  const driver = await UserModel.findOne({ _id: driverId, role: "DRIVER" })
    .select("driver_location driver_location_updated_at")
    .lean();
  if (!driver) return null;
  const updated = driver.driver_location_updated_at;
  if (updated && updated.getTime() < Date.now() - LOCATION_MAX_AGE_MS) {
    return null;
  }
  return pointFromUserDoc(driver);
};

const buildTargetedPayload = (
  payload: Record<string, unknown>,
  distanceM: number
) => ({
  ...payload,
  distance_m: Math.round(distanceM),
  distance_km: Number((distanceM / 1000).toFixed(1)),
});

/** Only nearby, on-duty drivers with GPS receive `new_ride` (no global broadcast). */
export const emitNewRideToNearbyDrivers = async (
  io: Server,
  pickup: GeoPoint,
  payload: Record<string, unknown>,
  options: NearbyDispatchOptions = {}
) => {
  const nearby = await findNearbyEligibleDrivers(pickup, options);

  if (nearby.length === 0) {
    logger.warn(
      {
        ride_id: payload.ride_id,
        pickup,
        rejected: normalizeRejected(options.rejectedDriverIds).length,
        maxRadiusMeters: options.maxRadiusMeters ?? DEFAULT_RADIUS_M,
        maxRadiusKm: Number(((options.maxRadiusMeters ?? DEFAULT_RADIUS_M) / 1000).toFixed(2)),
      },
      "No online drivers within configured radius of pickup — ride stays SEARCHING_DRIVER"
    );
    return { targeted: 0, broadcastAll: false };
  }

  for (const { driverId, location } of nearby) {
    const distanceM = distanceMeters(pickup, location);
    io.to(`driver_${driverId}`).emit("new_ride", buildTargetedPayload(payload, distanceM));
  }

  logger.info(
    {
      ride_id: payload.ride_id,
      targeted: nearby.length,
      maxRadiusMeters: options.maxRadiusMeters ?? DEFAULT_RADIUS_M,
    },
    "new_ride emitted to nearby eligible drivers"
  );

  return { targeted: nearby.length, broadcastAll: false };
};

export const emitRideUnavailableToDrivers = (io: Server, rideId: string) => {
  io.to("drivers").emit("ride_unavailable", { ride_id: rideId, rideId });
  io.to("drivers").emit("ride_cancelled", { ride_id: rideId, status: "ACCEPTED_BY_OTHER" });
};
