import { env } from "../config/env";
import { logger } from "../config/logger";
import { applyCancellationFields } from "../modules/common/ride-cancel.util";
import { RideDocument, RideModel } from "../modules/customer/ride/ride.model";
import { emitToCustomer, emitToRide } from "../socket/socket";
import { dispatchRideUnavailableToDrivers, emitToRoom } from "../socket/socket-emit.service";
import { emitAdminRideUpdate } from "./ride-socket-events.util";

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

  const current = await RideModel.findOne({
    _id: ride._id,
    status: "SEARCHING_DRIVER",
    driver_id: null,
  });

  if (!current) {
    const fresh = await RideModel.findById(ride._id);
    return fresh ?? ride;
  }

  applyCancellationFields(current, "SYSTEM", "SEARCH_TIMEOUT: No driver accepted in time");
  await current.save();

  logger.info(
    {
      ride_id: current.id,
      timeout_sec: getRideSearchTimeoutSec(),
    },
    "SEARCHING_DRIVER auto-cancelled after timeout"
  );

  const payload = {
    ride_id: current.id,
    status: "CANCELLED" as const,
    cancelled_by: current.cancelled_by,
    cancellation_reason: current.cancellation_reason,
    cancelled_at: current.cancelled_at,
    previous_status: current.previous_status,
    reason: "SEARCH_TIMEOUT",
    message: "No driver accepted in time. Please try again.",
  };

  try {
    dispatchRideUnavailableToDrivers(current.id);
    emitToCustomer(String(current.customer_id), "ride_status_update", payload);
    emitToCustomer(String(current.customer_id), "ride_cancelled", payload);
    emitToRide(current.id, "ride_status_update", payload);
    emitToRide(current.id, "ride_cancelled", payload);
    await emitToRoom("drivers", "ride_cancelled", payload);
    void emitAdminRideUpdate("ride_cancelled", {
      ...payload,
      customer_id: String(current.customer_id),
      driver_id: null,
    });
  } catch (error) {
    logger.warn({ error, ride_id: current.id }, "Failed to emit cancel after search timeout");
  }

  return current;
};
