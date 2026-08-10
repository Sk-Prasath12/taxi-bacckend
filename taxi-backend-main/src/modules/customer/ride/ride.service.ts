import { isValidObjectId, Types } from "mongoose";
import axios from "axios";
import { env } from "../../../config/env";
import { logger } from "../../../config/logger";
import { HttpError } from "../../../utils/http-error";
import { VehicleTypeModel } from "../../vehicle-type/vehicle-type.model";
import { UserModel } from "../../users/users.model";
import { RideDocument, RideModel } from "./ride.model";
import { joinRideRoomForUser } from "../../../socket/socket";
import { dispatchNewRideToNearbyDrivers, emitToRoom } from "../../../socket/socket-emit.service";
import { validateRideLocations } from "../../operational-zone/operational-zone.service";
import { emitCustomerAndRide } from "../../../utils/ride-socket-events.util";
import { toFlexibleClientStatus } from "../../../utils/ride-emit.util";

const ACTIVE_RIDE_BLOCKED_STATUSES = [
  "PENDING_CONFIRMATION",
  "SEARCHING_DRIVER",
  "DRIVER_ASSIGNED",
  "IN_PROGRESS",
  "ARRIVED_AT_PICKUP",
  "STARTED",
  "PICKED_UP",
  "IN_TRANSIT",
] as const;
const INACTIVE_RIDE_STATUSES = ["COMPLETED", "CANCELLED"] as const;
const FALLBACK_DURATION_MIN = 15;
const OTP_MIN = 1000;
const OTP_MAX = 9999;

/** Short / nearby trips still charge at least 1 km at the vehicle rate. */
const resolveTripFare = (distanceKm: number, perKmRate: number): number => {
  const minimum = perKmRate;
  const raw = distanceKm * perKmRate;
  return Number(Math.max(raw, minimum).toFixed(2));
};

const ensureCustomerId = (customerId?: string): string => {
  if (!customerId) {
    throw new HttpError(401, "Unauthorized");
  }
  return customerId;
};

const ensureCustomerCanCreateRide = async (userId: string): Promise<void> => {
  console.log("User ID:", userId);
  const user = await UserModel.findOne({
    _id: userId,
    role: "CUSTOMER",
    is_active: true,
  });
  if (!user) {
    throw new Error("Customer not found");
  }
  if (user.is_blocked) {
    const reason = user.blocked_reason?.trim() || "No reason provided";
    throw new HttpError(403, `You can't create ride because of blocked. Reason: ${reason}`);
  }
};

const ensureRideOwnership = (ride: RideDocument, customerId: string): void => {
  if (String(ride.customer_id) !== customerId) {
    throw new HttpError(403, "You are not allowed to access this ride");
  }
};

const customerObjectId = (customerId: string): Types.ObjectId => {
  if (!isValidObjectId(customerId)) {
    throw new HttpError(400, "Invalid customer id");
  }
  return new Types.ObjectId(customerId);
};

const emitRideCancelledEvents = async (ride: RideDocument): Promise<void> => {
  const rideId = ride.id;
  await emitToRoom("drivers", "ride_cancelled", { ride_id: rideId, status: "CANCELLED" });
  await emitToRoom(`ride_${rideId}`, "ride_status_update", {
    ride_id: rideId,
    status: "CANCELLED",
  });
  await emitToRoom(`customer_${String(ride.customer_id)}`, "ride_status_update", {
    ride_id: rideId,
    status: "CANCELLED",
  });
};

/** Cancels every non-completed ride for this customer (fresh booking). */
const cancelAllActiveRidesForCustomer = async (customerId: string): Promise<string[]> => {
  const rides = await RideModel.find({
    customer_id: customerObjectId(customerId),
    status: { $nin: INACTIVE_RIDE_STATUSES },
  }).sort({ createdAt: -1 });

  const clearedIds: string[] = [];
  for (const ride of rides) {
    ride.status = "CANCELLED";
    await ride.save();
    void emitRideCancelledEvents(ride);
    clearedIds.push(ride.id);
  }
  return clearedIds;
};

const ensureRideId = (rideId?: string): string => {
  if (!rideId || !isValidObjectId(rideId)) {
    logger.warn({ rideId }, "Invalid ride id received in customer ride flow");
    throw new HttpError(400, "Invalid ride id");
  }
  return rideId;
};

const mapRideSummary = (ride: RideDocument) => ({
  ride_id: ride.id,
  pickup: ride.pickup,
  drop: ride.drop,
  distance_km: ride.distance_km,
  duration_min: ride.duration_min ?? FALLBACK_DURATION_MIN,
  fare: ride.fare,
  currency: "INR",
  status: ride.status,
});

const mapRideDetails = async (ride: RideDocument) => {
  const driver = await getDriverDetails(ride.driver_id ? String(ride.driver_id) : null);

  return {
    ride_id: ride.id,
    customer_id: String(ride.customer_id),
    vehicle_type_id: ride.vehicle_type_id ? String(ride.vehicle_type_id) : null,
    driver_id: ride.driver_id ? String(ride.driver_id) : null,
    pickup: ride.pickup,
    drop: ride.drop,
    distance_km: ride.distance_km,
    duration_min: ride.duration_min ?? FALLBACK_DURATION_MIN,
    fare: ride.fare,
    currency: "INR",
    status: ride.status,
    client_status: toFlexibleClientStatus(ride),
    payment_mode: ride.payment_mode ?? "CASH",
    payment_status: ride.payment_status ?? "PENDING",
    otp: typeof ride.otp === "number" ? ride.otp : null,
    otp_verified: Boolean(ride.otp_verified),
    drop_otp: typeof ride.drop_otp === "number" ? ride.drop_otp : null,
    drop_otp_verified: Boolean(ride.drop_otp_verified),
    drop_reached: Boolean(ride.drop_reached),
    actual_drop: ride.actual_drop ?? null,
    actual_distance_km: ride.actual_distance_km ?? null,
    actual_duration_min: ride.actual_duration_min ?? null,
    driver,
    createdAt: ride.createdAt,
    updatedAt: ride.updatedAt,
  };
};

const generateRideOtp = (): number =>
  Math.floor(Math.random() * (OTP_MAX - OTP_MIN + 1)) + OTP_MIN;

const getDriverDetails = async (driverId?: string | null) => {
  if (!driverId) {
    return null;
  }

  const driver = await UserModel.findOne({ _id: driverId, role: "DRIVER" });
  if (!driver) {
    return null;
  }

  return {
    id: driver.id,
    name: driver.name,
    phone: driver.phone ?? null,
    status: driver.driver_status ?? "OFFLINE",
  };
};

type OsrmRouteResponse = {
  routes?: Array<{
    distance: number;
    duration: number;
  }>;
};

const haversineDistanceKm = (
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number
): number => {
  const earthRadiusKm = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Number((earthRadiusKm * c).toFixed(2));
};

const estimateDurationMin = (distanceKm: number): number =>
  Number(Math.max(5, (distanceKm / 30) * 60).toFixed(2));

const getTripMetricsFromOsrm = async (
  pickupLat: number,
  pickupLng: number,
  dropLat: number,
  dropLng: number
) => {
  try {
    const url =
      `${env.OSRM_URL}/route/v1/driving/` +
      `${pickupLng},${pickupLat};${dropLng},${dropLat}?overview=false`;

    const response = await axios.get<OsrmRouteResponse>(url);
    const route = response.data.routes?.[0];
    if (!route || typeof route.distance !== "number" || typeof route.duration !== "number") {
      throw new Error("No route available from OSRM");
    }
    if (route.distance <= 0 || route.duration <= 0) {
      throw new Error("Invalid route metrics from OSRM");
    }

    return {
      distance_km: Number((route.distance / 1000).toFixed(2)),
      duration_min: Number((route.duration / 60).toFixed(2)),
    };
  } catch (error) {
    const distance_km = Math.max(
      haversineDistanceKm(pickupLat, pickupLng, dropLat, dropLng),
      0.1
    );
    logger.warn(
      { error, distance_km },
      "OSRM route fetch failed. Using straight-line distance fallback"
    );
    return {
      distance_km,
      duration_min: estimateDurationMin(distance_km),
    };
  }
};

type RidePaymentInput = {
  payment_mode?: "ONLINE" | "CASH";
};

export const requestRide = async (
  customerIdInput: string | undefined,
  pickupLat: number,
  pickupLng: number,
  pickupAddress: string,
  dropLat: number,
  dropLng: number,
  dropAddress: string,
  vehicleTypeId: string,
  options?: RidePaymentInput
) => {
  const customerId = ensureCustomerId(customerIdInput);
  await ensureCustomerCanCreateRide(customerId);

  await validateRideLocations(
    { lat: pickupLat, lng: pickupLng },
    { lat: dropLat, lng: dropLng }
  );

  const clearedIds = await cancelAllActiveRidesForCustomer(customerId);
  if (clearedIds.length > 0) {
    logger.info({ customerId, clearedIds }, "Cancelled stale ride(s) before new request");
  }

  if (!isValidObjectId(vehicleTypeId)) {
    throw new HttpError(400, "Invalid vehicle type");
  }

  const vehicleType = await VehicleTypeModel.findById(vehicleTypeId);
  if (!vehicleType) {
    throw new HttpError(400, "Invalid vehicle type");
  }

  const { distance_km, duration_min } = await getTripMetricsFromOsrm(
    pickupLat,
    pickupLng,
    dropLat,
    dropLng
  );
  const resolvedFare = resolveTripFare(distance_km, vehicleType.per_km_rate);
  const resolvedPaymentMode = options?.payment_mode ?? "CASH";

  const ride = await RideModel.create({
    customer_id: customerId,
    vehicle_type_id: vehicleType.id,
    pickup: { lat: pickupLat, lng: pickupLng, address: pickupAddress?.trim?.() ? pickupAddress.trim() : "" },
    drop: { lat: dropLat, lng: dropLng, address: dropAddress?.trim?.() ? dropAddress.trim() : "" },
    distance_km,
    duration_min,
    fare: resolvedFare,
    payment_mode: resolvedPaymentMode,
    payment_status: "PENDING",
    otp: OTP_MIN,
    otp_verified: false,
    status: "PENDING_CONFIRMATION",
    driver_id: null,
  });

  return {
    ride_id: ride.id,
    distance_km,
    duration_min,
    vehicle_type: vehicleType.name,
    fare: resolvedFare,
    status: ride.status,
    ride: await mapRideDetails(ride),
  };
};

export const confirmRide = async (
  customerIdInput: string | undefined,
  rideIdInput?: string,
  options?: RidePaymentInput
) => {
  const customerId = ensureCustomerId(customerIdInput);
  const rideId = ensureRideId(rideIdInput);

  const ride = await RideModel.findById(rideId);
  if (!ride) {
    throw new HttpError(404, "Ride not found");
  }

  ensureRideOwnership(ride, customerId);

  if (ride.status !== "PENDING_CONFIRMATION") {
    throw new HttpError(400, "Ride is not in pending confirmation state");
  }

  if (!ride.fare || ride.fare <= 0) {
    let recalculatedFare = 0;

    if (ride.distance_km > 0 && ride.vehicle_type_id) {
      const vehicleType = await VehicleTypeModel.findById(ride.vehicle_type_id);
      if (vehicleType) {
        recalculatedFare = resolveTripFare(ride.distance_km, vehicleType.per_km_rate);
      }
    }

    ride.fare = recalculatedFare;
  }
  if (options?.payment_mode) {
    ride.payment_mode = options.payment_mode;
  } else if (ride.payment_mode == null) {
    ride.payment_mode = "CASH";
  }
  ride.payment_status = "PENDING";
  console.log("Final Fare (backend calculated):", ride.fare);

  const generatedOtp = generateRideOtp();
  ride.otp = generatedOtp;
  ride.otp_verified = false;
  ride.status = "SEARCHING_DRIVER";
  await ride.save();
  console.log("Ride confirmed:", ride.id, ride.status);
  logger.info(
    {
      ride_id: ride.id,
      customer_id: customerId,
      otp: generatedOtp,
    },
    "Ride OTP generated"
  );

  const newRidePayload = {
    ride_id: ride.id,
    pickup: ride.pickup,
    drop: ride.drop,
    fare: ride.fare,
    distance_km: ride.distance_km,
    payment_mode: ride.payment_mode ?? "CASH",
    status: "SEARCHING_DRIVER",
    vehicle_type_id: ride.vehicle_type_id ? String(ride.vehicle_type_id) : null,
  };
  await dispatchNewRideToNearbyDrivers(ride.pickup, newRidePayload, {
    vehicleTypeId: ride.vehicle_type_id ? String(ride.vehicle_type_id) : null,
    rejectedDriverIds: ride.rejected_driver_ids ?? [],
  });
  const rideDetails = await mapRideDetails(ride);
  emitCustomerAndRide(customerId, ride.id, "ride_created", {
    ride_id: ride.id,
    status: "SEARCHING_DRIVER",
    ride: rideDetails,
  });
  emitCustomerAndRide(customerId, ride.id, "otp_generated", {
    ride_id: ride.id,
    otp: generatedOtp,
  });
  joinRideRoomForUser(customerId, ride.id);

  return {
    message: "Ride confirmed",
    ride: rideDetails,
  };
};

export const getActiveRide = async (customerIdInput: string | undefined) => {
  const customerId = ensureCustomerId(customerIdInput);

  const ride = await RideModel.findOne({
    customer_id: customerId,
    status: { $nin: INACTIVE_RIDE_STATUSES },
  }).sort({ createdAt: -1 });

  if (!ride) {
    return { message: "No active ride" };
  }

  return await mapRideDetails(ride);
};

export const getRideStatus = async (customerIdInput: string | undefined, rideIdInput?: string) => {
  const customerId = ensureCustomerId(customerIdInput);
  const rideId = ensureRideId(rideIdInput);

  const ride = await RideModel.findById(rideId);
  if (!ride) {
    throw new HttpError(404, "Ride not found");
  }

  ensureRideOwnership(ride, customerId);
  return await mapRideDetails(ride);
};

export const cancelRide = async (customerIdInput: string | undefined, rideIdInput?: string) => {
  const customerId = ensureCustomerId(customerIdInput);
  const rideId = ensureRideId(rideIdInput);

  const ride = await RideModel.findById(rideId);
  if (!ride) {
    throw new HttpError(404, "Ride not found");
  }

  ensureRideOwnership(ride, customerId);

  const isCancellable =
    ride.status === "PENDING_CONFIRMATION" || ride.status === "SEARCHING_DRIVER";
  if (!isCancellable) {
    throw new HttpError(400, "This ride cannot be cancelled in current status");
  }

  ride.status = "CANCELLED";
  await ride.save();

  await emitRideCancelledEvents(ride);

  return {
    message: "Ride cancelled successfully",
  };
};

/** Clears any non-completed ride so the customer can start a fresh booking from home. */
export const abandonActiveRide = async (customerIdInput: string | undefined) => {
  const customerId = ensureCustomerId(customerIdInput);
  const clearedIds = await cancelAllActiveRidesForCustomer(customerId);

  if (clearedIds.length === 0) {
    return { message: "No active ride", cleared: false, ride_ids: [] as string[] };
  }

  return {
    message: "Active ride(s) cleared",
    cleared: true,
    ride_id: clearedIds[0],
    ride_ids: clearedIds,
  };
};

export const getRideHistory = async (customerIdInput: string | undefined) => {
  const customerId = ensureCustomerId(customerIdInput);

  const rides = await RideModel.find({ customer_id: customerId }).sort({ createdAt: -1 });

  const ridesWithDriver = await Promise.all(
    rides.map(async (ride: any) => mapRideDetails(ride))
  );

  return {
    rides: ridesWithDriver,
  };
};

export const getRideHistoryById = async (
  customerIdInput: string | undefined,
  rideIdInput?: string
) => {
  const customerId = ensureCustomerId(customerIdInput);
  const rideId = ensureRideId(rideIdInput);

  const ride = await RideModel.findById(rideId);
  if (!ride) {
    throw new HttpError(404, "Ride not found");
  }

  ensureRideOwnership(ride, customerId);

  return {
    ride: await mapRideDetails(ride),
  };
};

export const getCustomerRideInvoice = async (
  customerIdInput: string | undefined,
  rideIdInput?: string
) => {
  const customerId = ensureCustomerId(customerIdInput);
  const rideId = ensureRideId(rideIdInput);

  const ride = await RideModel.findById(rideId);
  if (!ride) {
    throw new HttpError(404, "Ride not found");
  }
  ensureRideOwnership(ride, customerId);

  const driver = await getDriverDetails(ride.driver_id ? String(ride.driver_id) : null);

  return {
    ride_id: ride.id,
    pickup_address: ride.pickup?.address ?? "",
    drop_address: ride.drop?.address ?? "",
    distance: ride.actual_distance_km ?? ride.distance_km,
    duration: ride.actual_duration_min ?? ride.duration_min ?? FALLBACK_DURATION_MIN,
    fare: ride.fare,
    payment_mode: ride.payment_mode ?? "CASH",
    payment_status: ride.payment_status ?? "PENDING",
    driver,
    createdAt: ride.createdAt,
  };
};
