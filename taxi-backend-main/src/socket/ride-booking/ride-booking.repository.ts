import { isValidObjectId } from "mongoose";
import { RideModel } from "../../modules/customer/ride/ride.model";
import { HttpError } from "../../utils/http-error";

type CreateRideInput = {
  customerId: string;
  pickup: { lat: number; lng: number };
  drop: { lat: number; lng: number };
};

export const createSocketRideRequest = async (input: CreateRideInput) => {
  const ride = await RideModel.create({
    customer_id: input.customerId,
    pickup: { ...input.pickup, address: "" },
    drop: { ...input.drop, address: "" },
    distance_km: 0,
    duration_min: 0,
    fare: 0,
    otp: 1000,
    otp_verified: false,
    payment_mode: "CASH",
    payment_status: "PENDING",
    status: "SEARCHING_DRIVER",
    driver_id: null,
  });
  return ride;
};

export const acceptRideAtomically = async (rideId: string, driverId: string) => {
  if (!isValidObjectId(rideId)) {
    throw new HttpError(400, "Invalid rideId");
  }
  const ride = await RideModel.findOneAndUpdate(
    {
      _id: rideId,
      status: "SEARCHING_DRIVER",
      driver_id: null,
    },
    {
      $set: {
        status: "DRIVER_ASSIGNED",
        driver_id: driverId,
      },
    },
    { new: true }
  );
  if (!ride) {
    throw new HttpError(409, "Ride already accepted or unavailable");
  }
  return ride;
};

export const updateRideStatus = async (rideId: string, currentStatus: string, nextStatus: string) => {
  const ride = await RideModel.findOneAndUpdate(
    {
      _id: rideId,
      status: currentStatus,
    },
    {
      $set: { status: nextStatus },
    },
    { new: true }
  );
  if (!ride) {
    throw new HttpError(409, `Ride is not in ${currentStatus} state`);
  }
  return ride;
};
