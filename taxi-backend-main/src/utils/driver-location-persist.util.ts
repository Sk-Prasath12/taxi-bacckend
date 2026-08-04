import { Types } from "mongoose";
import { logger } from "../config/logger";
import { LocationModel } from "../modules/locations/location.model";
import { UserModel } from "../modules/users/users.model";

const lastPersistAt = new Map<string, number>();
const PERSIST_THROTTLE_MS = 3000;

export type PersistLocationInput = {
  userId: string;
  role: "DRIVER" | "CUSTOMER";
  lat: number;
  lng: number;
  rideId?: string;
};

const isValidLatLng = (lat: number, lng: number) =>
  Number.isFinite(lat) &&
  Number.isFinite(lng) &&
  lat >= -90 &&
  lat <= 90 &&
  lng >= -180 &&
  lng <= 180;

const toGeoPoint = (lat: number, lng: number) => ({
  type: "Point" as const,
  coordinates: [lng, lat] as [number, number],
});

export async function persistUserLocation(input: PersistLocationInput): Promise<void> {
  const { userId, role, lat, lng, rideId } = input;
  if (!Types.ObjectId.isValid(userId) || !isValidLatLng(lat, lng)) {
    return;
  }

  const throttleKey = `${role}:${userId}`;
  const now = Date.now();
  const last = lastPersistAt.get(throttleKey) ?? 0;
  if (now - last < PERSIST_THROTTLE_MS) {
    return;
  }
  lastPersistAt.set(throttleKey, now);

  const geo = toGeoPoint(lat, lng);
  const updatedAt = new Date();

  try {
    if (role === "DRIVER") {
      await UserModel.updateOne(
        { _id: userId, role: "DRIVER" },
        {
          $set: {
            driver_location: geo,
            driver_location_updated_at: updatedAt,
          },
        }
      );
    }

    await LocationModel.updateOne(
      { user_id: new Types.ObjectId(userId), role },
      {
        $set: {
          user_id: new Types.ObjectId(userId),
          role,
          location: geo,
          lat,
          lng,
          ride_id:
            rideId && Types.ObjectId.isValid(rideId) ? new Types.ObjectId(rideId) : undefined,
          updated_at: updatedAt,
        },
      },
      { upsert: true }
    );
  } catch (error) {
    logger.error({ error, userId, role }, "Failed to persist user location");
  }
}
