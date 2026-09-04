import { RideDocument, RideStatus } from "../customer/ride/ride.model";
import { HttpError } from "../../utils/http-error";

/** Statuses where normal cancel is allowed (before pickup OTP / ride start). */
export const CANCELLABLE_STATUSES: RideStatus[] = [
  "PENDING_CONFIRMATION",
  "SEARCHING_DRIVER",
  "DRIVER_ASSIGNED",
  "ARRIVED_AT_PICKUP",
];

const POST_START_STATUSES: RideStatus[] = ["STARTED", "PICKED_UP", "IN_TRANSIT", "COMPLETED"];

export type CancelledBy = "CUSTOMER" | "DRIVER" | "ADMIN" | "SYSTEM";

export const assertRideCancellable = (ride: RideDocument): void => {
  if (ride.status === "CANCELLED") {
    throw new HttpError(400, "Ride is already cancelled");
  }
  if (ride.status === "COMPLETED") {
    throw new HttpError(400, "Completed rides cannot be cancelled");
  }

  const started =
    Boolean(ride.otp_verified) ||
    Boolean(ride.trip_started_at) ||
    POST_START_STATUSES.includes(ride.status);

  if (started) {
    throw new HttpError(
      400,
      "Ride cannot be cancelled after pickup OTP verification or ride start"
    );
  }

  if (!CANCELLABLE_STATUSES.includes(ride.status)) {
    throw new HttpError(400, `This ride cannot be cancelled in status ${ride.status}`);
  }
};

export const applyCancellationFields = (
  ride: RideDocument,
  cancelledBy: CancelledBy,
  reason?: string
): void => {
  ride.previous_status = ride.status;
  ride.status = "CANCELLED";
  ride.cancelled_by = cancelledBy;
  ride.cancellation_reason = (reason ?? "").trim() || "No reason provided";
  ride.cancelled_at = new Date();
};
