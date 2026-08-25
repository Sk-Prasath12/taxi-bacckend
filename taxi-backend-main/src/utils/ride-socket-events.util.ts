import { emitToCustomer, emitToRide } from "../socket/socket";
import { emitToRoom } from "../socket/socket-emit.service";

type EmitPayload = Record<string, unknown>;

const STATUS_ALIAS_EVENTS: Record<string, string[]> = {
  SEARCHING: ["ride_created"],
  ACCEPTED: ["ride_accepted", "DRIVER_ACCEPTED"],
  ARRIVED: ["driver_arrived", "DRIVER_ARRIVED"],
  STARTED: ["pickup_otp_verified", "otp_verified", "trip_started", "TRIP_STARTED", "gps_tracking_started"],
  IN_TRANSIT: ["location_updated"],
  DROP_REACHED: ["drop_reached"],
  DROP_OTP_VERIFIED: ["drop_otp_verified"],
  COMPLETED: ["destination_reached", "ride_completed"],
};

/** Canonical status update + spec alias events for customer and ride rooms. */
export const emitRideStatusToParties = (
  customerId: string,
  rideId: string,
  statusForClient: string,
  payload: EmitPayload
) => {
  emitToCustomer(customerId, "ride_status_update", payload);
  emitToRide(rideId, "ride_status_update", payload);

  const aliases = STATUS_ALIAS_EVENTS[statusForClient] ?? [];
  for (const event of aliases) {
    emitToCustomer(customerId, event, payload);
    emitToRide(rideId, event, payload);
  }
};

export const emitCustomerAndRide = (
  customerId: string,
  rideId: string,
  event: string,
  payload: EmitPayload
) => {
  emitToCustomer(customerId, event, payload);
  emitToRide(rideId, event, payload);
};

/** Broadcast ride lifecycle updates to connected admin dashboards. */
export const emitAdminRideUpdate = async (event: string, payload: EmitPayload) => {
  await emitToRoom("admins", event, payload);
  await emitToRoom("admins", "ride_status_update", payload);
};
