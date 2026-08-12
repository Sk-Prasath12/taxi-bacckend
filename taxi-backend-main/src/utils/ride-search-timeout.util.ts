import { env } from "../config/env";
import { logger } from "../config/logger";
import { RideDocument, RideModel } from "../modules/customer/ride/ride.model";
import { emitToCustomer, emitToRide } from "../socket/socket";
import { dispatchRideUnavailableToDrivers } from "../socket/socket-emit.service";

export const getRideSearchTimeoutMs = (): number =>
  Math.round(env.RIDE_SEARCH_TIMEOUT_SEC * 1000);

export const getRideSearchTimeoutSec = (): number => env.RIDE_SEARCH_TIMEOUT_SEC;

/** True when SEARCHING_DRIVER has exceeded configured timeout. */
export const isSearchingRideExpired = (ride: {
  status?: string;
  updatedAt?: Date;
  createdAt?: Date;
}): boolean => {
  if (ride.status !== "SEARCHING_DRIVER") return false;
  const started = ride.updatedAt ?? ride.createdAt;
  if (!started) return false;
  return Date.now() - new Date(started).getTime() > getRideSearchTimeoutMs();
};

/**
 * If the ride is still searching past timeout, cancel it and notify parties.
 * Returns the (possibly updated) ride document.
 */
export const expireSearchingRideIfNeeded = async (
  ride: RideDocument
): Promise<RideDocument> => {
  if (!isSearchingRideExpired(ride)) return ride;

  const updated = await RideModel.findOneAndUpdate(
    { _id: ride._id, status: "SEARCHING_DRIVER", driver_id: null },
    { $set: { status: "CANCELLED" } },
    { new: true }
  );

  if (!updated) {
    const fresh = await RideModel.findById(ride._id);
    return fresh ?? ride;
  }

  logger.info(
    {
      ride_id: updated.id,
      timeout_sec: getRideSearchTimeoutSec(),
    },
    "SEARCHING_DRIVER auto-cancelled after timeout"
  );

  try {
    dispatchRideUnavailableToDrivers(updated.id);
    emitToCustomer(String(updated.customer_id), "ride_status_update", {
      ride_id: updated.id,
      status: "CANCELLED",
      reason: "SEARCH_TIMEOUT",
      message: "No driver accepted in time. Please try again.",
    });
    emitToRide(updated.id, "ride_status_update", {
      ride_id: updated.id,
      status: "CANCELLED",
      reason: "SEARCH_TIMEOUT",
    });
  } catch (error) {
    logger.warn({ error, ride_id: updated.id }, "Failed to emit cancel after search timeout");
  }

  return updated;
};
