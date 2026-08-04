import { HttpError } from "../../utils/http-error";

const allowedTransitions: Record<string, string[]> = {
  SEARCHING_DRIVER: ["DRIVER_ASSIGNED"],
  DRIVER_ASSIGNED: ["ARRIVED_AT_PICKUP"],
  ARRIVED_AT_PICKUP: ["STARTED"],
  STARTED: ["COMPLETED"],
};

export const assertRideTransition = (currentStatus: string, nextStatus: string) => {
  const allowed = allowedTransitions[currentStatus] ?? [];
  if (!allowed.includes(nextStatus)) {
    throw new HttpError(
      409,
      `Invalid ride state transition from ${currentStatus} to ${nextStatus}`
    );
  }
};
