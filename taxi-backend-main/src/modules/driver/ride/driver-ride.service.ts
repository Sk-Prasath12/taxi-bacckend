import { isValidObjectId } from "mongoose";
import { calculateCommission } from "../../common/commission.service";
import { processRidePayment } from "../../finance/finance.service";
import { generateInvoice } from "../../invoice/invoice.service";
import { logger } from "../../../config/logger";
import { sendPushNotification } from "../../../services/notification.service";
import { HttpError } from "../../../utils/http-error";
import { RideDocument, RideModel, RideStatus } from "../../customer/ride/ride.model";
import { UserModel } from "../../users/users.model";
import { emitToCustomer, emitToRide, joinRideRoomForUser } from "../../../socket/socket";
import { VehicleTypeModel } from "../../vehicle-type/vehicle-type.model";
import { buildRideEmitPayload, toFlexibleClientStatus } from "../../../utils/ride-emit.util";
import {
  dispatchNewRideToNearbyDrivers,
  dispatchRideUnavailableToDrivers,
} from "../../../socket/socket-emit.service";
import {
  getDriverLocationForMatching,
  distanceMeters,
  getNearbyDriverRadiusMeters,
  getNearbyDriverRadiusKm,
} from "../../../utils/nearby-drivers.util";
import { expireSearchingRideIfNeeded } from "../../../utils/ride-search-timeout.util";
import { persistUserLocation } from "../../../utils/driver-location-persist.util";
import { acceptRideAtomically } from "../../../socket/ride-booking/ride-booking.repository";
import { upsertOnlineDriver } from "../../../socket/ride-booking/ride-booking.store";
import { emitCustomerAndRide, emitRideStatusToParties, emitAdminRideUpdate } from "../../../utils/ride-socket-events.util";
import {
  driverMatchesVehicleType,
  getDriverVehicleTypeId,
} from "../../../utils/driver-vehicle-type.util";

const ensureDriverId = (driverId?: string) => {
  if (!driverId) {
    throw new HttpError(401, "Unauthorized");
  }
  return driverId;
};

const ensureRideId = (rideId?: string) => {
  if (!rideId || !isValidObjectId(rideId)) {
    logger.warn({ rideId }, "Invalid ride id received in driver ride flow");
    throw new HttpError(400, "Invalid ride id");
  }
  return rideId;
};

const getDriverOrThrow = async (driverIdInput?: string) => {
  const driverId = ensureDriverId(driverIdInput);
  const driver = await UserModel.findOne({ _id: driverId, role: "DRIVER" });
  if (!driver) {
    throw new HttpError(404, "Driver not found");
  }
  return driver;
};

const ensureDriverCanTakeIncomingRides = async (driverIdInput?: string) => {
  const driver = await getDriverOrThrow(driverIdInput);
  if (driver.is_blocked) {
    const reason = driver.blocked_reason?.trim() || "No reason provided";
    throw new HttpError(403, `You can't take the ride. Incoming rides are blocked. Reason: ${reason}`);
  }
  const isVerified =
    driver.is_driver_verified === true && driver.driver_verification_status === "APPROVED";
  if (!isVerified) {
    throw new HttpError(403, "You are not verified please verify first");
  }
  if (driver.driver_status !== "ONLINE") {
    throw new HttpError(403, "Go online to receive ride requests");
  }
  const activeRide = await RideModel.findOne({
    driver_id: driver._id,
    status: { $nin: ["COMPLETED", "CANCELLED"] },
  }).select("_id status");
  if (activeRide) {
    throw new HttpError(409, "You already have an active ride");
  }
  return driver;
};

const getRideByIdOrThrow = async (rideIdInput?: string) => {
  const rideId = ensureRideId(rideIdInput);
  const ride = await RideModel.findById(rideId);
  if (!ride) {
    throw new HttpError(404, "Ride not found");
  }
  return ride;
};

const mapIncomingRide = (
  ride: RideDocument,
  customer?: { name?: string; phone?: string | null } | null
) => ({
  ride_id: ride.id,
  pickup: ride.pickup,
  drop: ride.drop,
  distance_km: ride.distance_km,
  duration_min: ride.duration_min ?? null,
  fare: ride.fare,
  status: ride.status,
  vehicle_type_id: ride.vehicle_type_id ? String(ride.vehicle_type_id) : null,
  createdAt: ride.createdAt,
  nearby_km: getNearbyDriverRadiusKm(),
  customer: customer
    ? {
        id: String(ride.customer_id),
        name: customer.name ?? "Customer",
        phone: customer.phone ?? null,
      }
    : null,
});

const OTP_MIN = 1001;
const OTP_MAX = 9999;
const PLACEHOLDER_RIDE_OTP = 1000;

const generateRideOtp = (): number =>
  Math.floor(Math.random() * (OTP_MAX - OTP_MIN + 1)) + OTP_MIN;

const hasUsablePickupOtp = (otp: unknown): otp is number =>
  typeof otp === "number" && otp >= OTP_MIN && otp <= OTP_MAX && otp !== PLACEHOLDER_RIDE_OTP;

const emitRideLifecycle = async (ride: RideDocument, statusForClient?: string) => {
  const customerId = String(ride.customer_id);
  const ridePayload = await buildRideEmitPayload(ride);
  const clientStatus = statusForClient ?? toFlexibleClientStatus(ride);
  const payload = {
    ride_id: ride.id,
    status: clientStatus,
    ride: ridePayload,
    pickup: ride.pickup,
    drop: ride.drop,
    actual_drop: ride.actual_drop ?? null,
    driver: ridePayload.driver,
    otp: ride.otp,
    otp_verified: ride.otp_verified,
    drop_otp: ride.drop_otp ?? null,
    drop_otp_verified: ride.drop_otp_verified ?? false,
    drop_reached: ride.drop_reached ?? false,
    actual_distance_km: ride.actual_distance_km ?? null,
    actual_duration_min: ride.actual_duration_min ?? null,
    fare: ride.fare,
    payment_mode: ride.payment_mode,
    payment_status: ride.payment_status,
  };
  emitRideStatusToParties(customerId, ride.id, clientStatus, payload);
  void emitAdminRideUpdate(
    clientStatus === "COMPLETED"
      ? "ride_completed"
      : clientStatus === "ARRIVED"
        ? "driver_arrived"
        : clientStatus === "STARTED"
          ? "ride_started"
          : "ride_status_update",
    payload
  );
};

const calculateDynamicFare = async (ride: RideDocument): Promise<number> => {
  const baseFare = 40;
  const perMin = 2;
  let perKm = 12;
  if (ride.vehicle_type_id) {
    const vehicleType = await VehicleTypeModel.findById(ride.vehicle_type_id);
    if (vehicleType?.per_km_rate) {
      perKm = vehicleType.per_km_rate;
    }
  }
  const km = ride.actual_distance_km ?? ride.distance_km;
  const min = ride.actual_duration_min ?? ride.duration_min ?? 0;
  return Number((baseFare + km * perKm + min * perMin).toFixed(2));
};

const finalizeCompletedRide = async (ride: RideDocument) => {
  if (ride.payment_mode === "CASH") {
    ride.payment_status = "SUCCESS";
  }
  ride.status = "COMPLETED";
  ride.completed_at = new Date();
  await ride.save();

  if (ride.driver_id) {
    await UserModel.updateOne(
      { _id: ride.driver_id, role: "DRIVER" },
      { $set: { driver_status: "ONLINE" } }
    );
  }

  if (ride.payment_mode === "CASH") {
    try {
      await processRidePayment(ride);
      await generateInvoice(ride);
    } catch (error) {
      logger.error({ error, ride_id: ride.id }, "Cash finance/invoice flow failed");
    }
  } else if (ride.payment_status === "SUCCESS") {
    try {
      await processRidePayment(ride);
      await generateInvoice(ride);
    } catch (error) {
      logger.error({ error, ride_id: ride.id }, "Online finance/invoice flow failed");
    }
  } else {
    try {
      await generateInvoice(ride);
    } catch (error) {
      logger.error({ error, ride_id: ride.id }, "Online invoice generation failed");
    }
  }

  const customerId = String(ride.customer_id);
  await emitRideLifecycle(ride, "COMPLETED");
  emitCustomerAndRide(customerId, ride.id, "ride_completed", {
    ride_id: ride.id,
    status: "COMPLETED",
    fare: ride.fare,
    actual_distance_km: ride.actual_distance_km,
    actual_duration_min: ride.actual_duration_min,
    payment_status: ride.payment_status,
    payment_mode: ride.payment_mode,
    finance_processed: Boolean(ride.finance_processed),
  });
  void emitAdminRideUpdate("ride_completed", {
    ride_id: ride.id,
    status: "COMPLETED",
    fare: ride.fare,
    payment_status: ride.payment_status,
    payment_mode: ride.payment_mode,
    customer_id: customerId,
    driver_id: ride.driver_id ? String(ride.driver_id) : null,
    finance_processed: Boolean(ride.finance_processed),
  });
  await sendRideStatusPush(
    customerId,
    ride.id,
    "RIDE_COMPLETED",
    "Ride Completed ✅",
    "Thank you for riding with us"
  );
};

const sendRideStatusPush = async (customerId: string, rideId: string, type: string, title: string, body: string) => {
  try {
    const customer = await UserModel.findById(customerId).select("fcm_token").lean();
    const token = customer?.fcm_token?.trim();
    if (!token) return;
    await sendPushNotification({
      token,
      title,
      body,
      data: { type, ride_id: rideId },
    });
  } catch (error) {
    logger.error({ error, customerId, rideId, type }, "Ride status push notification failed");
  }
};

const ensureRideBelongsToDriver = (ride: RideDocument, driverId: string) => {
  if (!ride.driver_id || String(ride.driver_id) !== driverId) {
    throw new HttpError(403, "This ride is not assigned to you");
  }
};

const toClientStatus = (status: RideStatus): string => {
  switch (status) {
    case "SEARCHING_DRIVER":
      return "SEARCHING";
    case "DRIVER_ASSIGNED":
      return "ACCEPTED";
    case "ARRIVED_AT_PICKUP":
      return "ARRIVED";
    case "STARTED":
      return "STARTED";
    case "PICKED_UP":
    case "IN_TRANSIT":
      return "IN_TRANSIT";
    case "COMPLETED":
      return "COMPLETED";
    case "CANCELLED":
      return "CANCELLED";
    default:
      return status;
  }
};

const moveRideStatus = async (
  driverIdInput: string | undefined,
  rideIdInput: string | undefined,
  expectedStatus: RideStatus,
  nextStatus: RideStatus,
  successMessage: string
) => {
  const driver = await getDriverOrThrow(driverIdInput);
  const ride = await getRideByIdOrThrow(rideIdInput);

  ensureRideBelongsToDriver(ride, driver.id);
  if (ride.status !== expectedStatus) {
    throw new HttpError(400, `Ride must be in ${expectedStatus} state`);
  }

  ride.status = nextStatus;
  if (nextStatus === "COMPLETED") {
    if (ride.payment_mode === "CASH") {
      ride.payment_status = "SUCCESS";
    } else {
      ride.payment_status = "PENDING";
    }
  }
  await ride.save();
  if (nextStatus === "COMPLETED") {
    console.log("Commission Test:", calculateCommission(ride.fare));

    // CASH FLOW: due/admin revenue first, then invoice with SUCCESS.
    if (ride.payment_mode === "CASH") {
      console.log("CASH FLOW START");
      try {
        await processRidePayment(ride);
        await generateInvoice(ride);
        console.log("CASH FLOW DONE");
      } catch (error) {
        logger.error({ error, ride_id: ride.id }, "Cash finance/invoice flow failed");
      }
    }

    // ONLINE FLOW: create invoice as PENDING at ride completion.
    if (ride.payment_mode === "ONLINE") {
      console.log("ONLINE FLOW INIT");
      try {
        await generateInvoice(ride);
        console.log("Invoice created, waiting for payment");
      } catch (error) {
        logger.error({ error, ride_id: ride.id }, "Online invoice generation failed");
      }
    }
  }
  const customerId = String(ride.customer_id);
  const statusForClient = toClientStatus(ride.status);
  console.log("STATUS EMIT:", statusForClient);
  console.log("Emitting to customer:", customerId);
  await emitRideLifecycle(ride, statusForClient);
  if (nextStatus === "COMPLETED" && ride.payment_mode === "ONLINE" && ride.payment_status === "PENDING") {
    emitCustomerAndRide(customerId, ride.id, "payment_pending", {
      ride_id: ride.id,
      status: "PAYMENT_PENDING",
      payment_mode: ride.payment_mode,
      payment_status: ride.payment_status,
      fare: ride.fare,
    });
  }
  if (nextStatus === "ARRIVED_AT_PICKUP") {
    await sendRideStatusPush(
      customerId,
      ride.id,
      "DRIVER_ARRIVED",
      "Driver Arrived 📍",
      "Your driver has reached pickup"
    );
  } else if (nextStatus === "COMPLETED") {
    await sendRideStatusPush(
      customerId,
      ride.id,
      "RIDE_COMPLETED",
      "Ride Completed ✅",
      "Please complete payment"
    );
  }

  return {
    message: successMessage,
    ride_id: ride.id,
    status: ride.status,
  };
};

export const getDriverRideById = async (
  driverIdInput: string | undefined,
  rideIdInput?: string
) => {
  const driver = await getDriverOrThrow(driverIdInput);
  const ride = await getRideByIdOrThrow(rideIdInput);
  ensureRideBelongsToDriver(ride, driver.id);

  return {
    message: "Ride details",
    ride: await buildRideEmitPayload(ride),
  };
};

export const getDriverActiveRide = async (driverIdInput: string | undefined) => {
  const driver = await getDriverOrThrow(driverIdInput);
  const ride = await RideModel.findOne({
    driver_id: driver.id,
    status: { $nin: ["COMPLETED", "CANCELLED"] as RideStatus[] },
  }).sort({ createdAt: -1 });

  if (!ride) {
    return { message: "No active ride", ride: null };
  }

  return {
    message: "Active ride",
    ride: await buildRideEmitPayload(ride),
  };
};

export const rejectIncomingRide = async (driverIdInput: string | undefined, rideIdInput?: string) => {
  const driver = await ensureDriverCanTakeIncomingRides(driverIdInput);
  const ride = await getRideByIdOrThrow(rideIdInput);

  if (ride.status !== "SEARCHING_DRIVER") {
    throw new HttpError(400, "Ride is not available for rejection");
  }
  if (ride.driver_id) {
    throw new HttpError(409, "Ride already accepted");
  }

  const rejected = ride.rejected_driver_ids ?? [];
  const alreadyRejected = rejected.some((id) => String(id) === driver.id);
  if (!alreadyRejected) {
    ride.rejected_driver_ids = [...rejected, driver._id];
    await ride.save();
  }

  try {
    const pickupForMatching = {
      lat: Number(ride.pickup?.lat),
      lng: Number(ride.pickup?.lng),
    };
    if (!Number.isFinite(pickupForMatching.lat) || !Number.isFinite(pickupForMatching.lng)) {
      throw new Error("Ride pickup location is missing or invalid");
    }
    await dispatchNewRideToNearbyDrivers(
      pickupForMatching,
      {
        ride_id: ride.id,
        pickup: ride.pickup,
        drop: ride.drop,
        fare: ride.fare,
        distance_km: ride.distance_km,
        payment_mode: ride.payment_mode ?? "CASH",
        status: "SEARCHING_DRIVER",
        vehicle_type_id: ride.vehicle_type_id ? String(ride.vehicle_type_id) : null,
      },
      {
        rejectedDriverIds: ride.rejected_driver_ids ?? [],
        vehicleTypeId: ride.vehicle_type_id ? String(ride.vehicle_type_id) : null,
      }
    );
  } catch (error) {
    logger.warn({ error, ride_id: ride.id }, "Re-broadcast after reject failed");
  }

  return {
    message: "Ride rejected",
    ride_id: ride.id,
    success: true,
  };
};

export type IncomingRidesOptions = {
  lat?: number;
  lng?: number;
};

export const getIncomingRides = async (
  driverIdInput: string | undefined,
  options: IncomingRidesOptions = {}
) => {
  const driver = await ensureDriverCanTakeIncomingRides(driverIdInput);

  if (
    typeof options.lat === "number" &&
    typeof options.lng === "number" &&
    Number.isFinite(options.lat) &&
    Number.isFinite(options.lng)
  ) {
    void persistUserLocation({
      userId: driver.id,
      role: "DRIVER",
      lat: options.lat,
      lng: options.lng,
    });
    upsertOnlineDriver({
      driverId: driver.id,
      socketId: "",
      location: { lat: options.lat, lng: options.lng },
      updatedAt: Date.now(),
    });
  }

  let driverLocation = await getDriverLocationForMatching(driver.id);
  if (
    !driverLocation &&
    typeof options.lat === "number" &&
    typeof options.lng === "number" &&
    Number.isFinite(options.lat) &&
    Number.isFinite(options.lng)
  ) {
    driverLocation = { lat: options.lat, lng: options.lng };
  }
  if (!driverLocation) {
    return { rides: [] };
  }

  const driverVehicleTypeId = await getDriverVehicleTypeId(driver.id);
  const maxRadiusM = getNearbyDriverRadiusMeters();
  const rides = await RideModel.find({
    status: "SEARCHING_DRIVER",
    driver_id: null,
    rejected_driver_ids: { $nin: [driver._id] },
  })
    .sort({ createdAt: -1 })
    .limit(30);

  const activeRides: RideDocument[] = [];
  for (const ride of rides) {
    const current = await expireSearchingRideIfNeeded(ride);
    if (current.status !== "SEARCHING_DRIVER" || current.driver_id) continue;
    if (!current.pickup?.lat || !current.pickup?.lng) continue;
    if (
      current.vehicle_type_id &&
      !driverMatchesVehicleType(driverVehicleTypeId, String(current.vehicle_type_id))
    ) {
      continue;
    }
    if (
      distanceMeters(driverLocation, {
        lat: current.pickup.lat,
        lng: current.pickup.lng,
      }) > maxRadiusM
    ) {
      continue;
    }
    activeRides.push(current);
  }

  const customerIds = [...new Set(activeRides.map((r) => String(r.customer_id)))];
  const customers = customerIds.length
    ? await UserModel.find({ _id: { $in: customerIds }, role: "CUSTOMER" })
        .select("name phone")
        .lean()
    : [];
  const customerById = new Map(customers.map((c) => [String(c._id), c]));

  return {
    rides: activeRides.slice(0, 20).map((ride) =>
      mapIncomingRide(ride, customerById.get(String(ride.customer_id)) ?? null)
    ),
  };
};

export const acceptIncomingRide = async (driverIdInput: string | undefined, rideIdInput?: string) => {
  const driver = await ensureDriverCanTakeIncomingRides(driverIdInput);
  const rideId = ensureRideId(rideIdInput);

  const driverLocation = await getDriverLocationForMatching(driver.id);
  const rideBefore = await RideModel.findById(rideId);
  if (!rideBefore) {
    throw new HttpError(404, "Ride not found");
  }
  const currentRide = await expireSearchingRideIfNeeded(rideBefore);
  if (currentRide.status === "CANCELLED") {
    throw new HttpError(409, "Ride request expired");
  }
  if (currentRide.status !== "SEARCHING_DRIVER" || currentRide.driver_id) {
    throw new HttpError(409, "Ride already accepted by another driver.");
  }
  const driverVehicleTypeId = await getDriverVehicleTypeId(driver.id);
  if (
    currentRide.vehicle_type_id &&
    !driverMatchesVehicleType(driverVehicleTypeId, String(currentRide.vehicle_type_id))
  ) {
    throw new HttpError(403, "Your vehicle type does not match this ride request");
  }
  if (driverLocation && currentRide.pickup?.lat && currentRide.pickup?.lng) {
    const maxRadiusM = getNearbyDriverRadiusMeters();
    const dist = distanceMeters(driverLocation, {
      lat: currentRide.pickup.lat,
      lng: currentRide.pickup.lng,
    });
    if (dist > maxRadiusM) {
      throw new HttpError(
        403,
        `This ride is more than ${getNearbyDriverRadiusKm()} km from your location`
      );
    }
  }

  const ride = await acceptRideAtomically(rideId, driver.id);
  await UserModel.updateOne({ _id: driver._id }, { $set: { driver_status: "BUSY" } });

  await dispatchRideUnavailableToDrivers(ride.id);
  const customerId = String(ride.customer_id);
  const ridePayload = await buildRideEmitPayload(ride);
  console.log("Emitting to customer:", customerId);
  emitToCustomer(customerId, "ride_accepted", {
    ride_id: ride.id,
    driver_id: driver.id,
    status: "ACCEPTED",
    pickup: ride.pickup,
    drop: ride.drop,
    driver: ridePayload.driver,
    ride: ridePayload,
  });
  console.log("STATUS EMIT:", "ACCEPTED");
  emitToCustomer(customerId, "ride_status_update", {
    ride_id: ride.id,
    status: "ACCEPTED",
    ride: ridePayload,
    driver: ridePayload.driver,
  });
  emitToRide(ride.id, "ride_status_update", {
    ride_id: ride.id,
    status: "ACCEPTED",
    ride: ridePayload,
  });
  await sendRideStatusPush(
    customerId,
    ride.id,
    "DRIVER_ASSIGNED",
    "Driver Assigned 🚖",
    "Your driver is on the way"
  );
  joinRideRoomForUser(driver.id, ride.id);
  void emitAdminRideUpdate("ride_accepted", {
    ride_id: ride.id,
    status: "ACCEPTED",
    ride: ridePayload,
    driver_id: driver.id,
  });

  return {
    message: "Ride accepted successfully",
    ride_id: ride.id,
    status: ride.status,
  };
};

export const markRideArrivedAtPickup = async (driverIdInput: string | undefined, rideIdInput?: string) => {
  const driver = await getDriverOrThrow(driverIdInput);
  const ride = await getRideByIdOrThrow(rideIdInput);
  ensureRideBelongsToDriver(ride, driver.id);

  if (ride.status !== "DRIVER_ASSIGNED" && ride.status !== "ARRIVED_AT_PICKUP") {
    throw new HttpError(400, "Ride must be assigned before marking arrived");
  }

  // Keep the confirm-ride OTP. Never mint a new code on arrive/re-tap.
  if (!hasUsablePickupOtp(ride.otp)) {
    ride.otp = generateRideOtp();
    ride.otp_verified = false;
  }
  ride.status = "ARRIVED_AT_PICKUP";
  await ride.save();

  const customerId = String(ride.customer_id);
  await emitRideLifecycle(ride, "ARRIVED");
  emitCustomerAndRide(customerId, ride.id, "driver_arrived", {
    ride_id: ride.id,
    status: "ARRIVED",
    otp: ride.otp,
  });
  emitCustomerAndRide(customerId, ride.id, "pickup_otp_generated", {
    ride_id: ride.id,
    otp: ride.otp,
  });

  await sendRideStatusPush(
    customerId,
    ride.id,
    "DRIVER_ARRIVED",
    "Driver Arrived 📍",
    "Your driver has reached pickup. Share the pickup OTP."
  );

  return {
    message: "Driver arrived at pickup location",
    ride_id: ride.id,
    status: ride.status,
    otp: ride.otp,
  };
};

export const markRidePickedUp = async (driverIdInput: string | undefined, rideIdInput?: string) => {
  const driver = await getDriverOrThrow(driverIdInput);
  const ride = await getRideByIdOrThrow(rideIdInput);
  ensureRideBelongsToDriver(ride, driver.id);

  if (!ride.otp_verified) {
    throw new HttpError(400, "Pickup OTP must be verified before pickup confirm");
  }
  if (ride.status !== "STARTED" && ride.status !== "PICKED_UP") {
    if (ride.status === "ARRIVED_AT_PICKUP") {
      throw new HttpError(400, "Verify pickup OTP before pickup confirm");
    }
    throw new HttpError(400, `Cannot confirm pickup from status ${ride.status}`);
  }

  ride.status = "PICKED_UP";
  await ride.save();
  await emitRideLifecycle(ride);
  return { message: "Passenger picked up", ride_id: ride.id, status: ride.status };
};

export const markRideInTransit = async (driverIdInput: string | undefined, rideIdInput?: string) => {
  const driver = await getDriverOrThrow(driverIdInput);
  const ride = await getRideByIdOrThrow(rideIdInput);
  ensureRideBelongsToDriver(ride, driver.id);

  if (!["STARTED", "PICKED_UP", "IN_TRANSIT"].includes(ride.status)) {
    throw new HttpError(400, `Cannot start trip to drop from status ${ride.status}`);
  }

  ride.status = "IN_TRANSIT";
  await ride.save();
  await emitRideLifecycle(ride);
  return { message: "Ride is in transit", ride_id: ride.id, status: ride.status };
};

export type DropReachedInput = {
  fare?: number;
  lat?: number;
  lng?: number;
  actual_distance_km?: number;
  duration_min?: number;
  address?: string;
};

/** Driver pressed DROP REACHED — no geo-fence; recalculates fare from actual GPS distance. */
export const markRideDropped = async (
  driverIdInput: string | undefined,
  rideIdInput?: string,
  input: DropReachedInput = {}
) => {
  const driver = await getDriverOrThrow(driverIdInput);
  const ride = await getRideByIdOrThrow(rideIdInput);
  ensureRideBelongsToDriver(ride, driver.id);

  if (!ride.otp_verified) {
    throw new HttpError(400, "Pickup OTP must be verified before drop reached");
  }
  if (!["STARTED", "PICKED_UP", "IN_TRANSIT"].includes(ride.status)) {
    throw new HttpError(400, `Cannot mark drop reached from status ${ride.status}`);
  }
  if (ride.drop_reached) {
    throw new HttpError(400, "Drop already marked for this ride");
  }

  if (typeof input.actual_distance_km === "number" && input.actual_distance_km >= 0) {
    ride.actual_distance_km = Number(input.actual_distance_km.toFixed(2));
  }
  if (typeof input.duration_min === "number" && input.duration_min >= 0) {
    ride.actual_duration_min = Number(input.duration_min.toFixed(1));
  }
  if (typeof input.lat === "number" && typeof input.lng === "number") {
    ride.actual_drop = {
      lat: input.lat,
      lng: input.lng,
      address: input.address?.trim() || ride.drop.address || "",
    };
  }

  ride.drop_reached = true;
  ride.drop_otp = generateRideOtp();
  ride.drop_otp_verified = false;
  ride.status = "IN_TRANSIT";
  ride.fare =
    typeof input.fare === "number" && input.fare > 0
      ? Number(input.fare.toFixed(2))
      : await calculateDynamicFare(ride);

  await ride.save();

  const customerId = String(ride.customer_id);
  await emitRideLifecycle(ride, "DROP_REACHED");
  emitCustomerAndRide(customerId, ride.id, "drop_reached", {
    ride_id: ride.id,
    status: "DROP_REACHED",
    fare: ride.fare,
    actual_distance_km: ride.actual_distance_km,
    actual_drop: ride.actual_drop,
  });
  emitCustomerAndRide(customerId, ride.id, "drop_otp_generated", {
    ride_id: ride.id,
    drop_otp: ride.drop_otp,
    fare: ride.fare,
  });

  return {
    message: "Drop reached. Verify drop OTP to proceed to payment.",
    ride_id: ride.id,
    status: ride.status,
    client_status: "DROP_REACHED",
    drop_otp: ride.drop_otp,
    fare: ride.fare,
    actual_distance_km: ride.actual_distance_km,
  };
};

export const verifyDropOtp = async (
  driverIdInput: string | undefined,
  rideIdInput: string | undefined,
  otpInput: number
) => {
  const driver = await getDriverOrThrow(driverIdInput);
  const ride = await getRideByIdOrThrow(rideIdInput);
  ensureRideBelongsToDriver(ride, driver.id);

  if (!ride.drop_reached) {
    throw new HttpError(400, "Mark drop reached before verifying drop OTP");
  }
  if (ride.drop_otp_verified) {
    throw new HttpError(400, "Drop OTP already verified");
  }
  if (ride.drop_otp !== otpInput) {
    throw new HttpError(400, "Invalid drop OTP");
  }

  ride.drop_otp_verified = true;
  await ride.save();

  const customerId = String(ride.customer_id);
  await emitRideLifecycle(ride, "DROP_OTP_VERIFIED");
  emitCustomerAndRide(customerId, ride.id, "drop_otp_verified", {
    ride_id: ride.id,
    drop_otp_verified: true,
  });

  if (ride.payment_mode === "ONLINE") {
    ride.payment_status = "PENDING";
    await ride.save();
    emitCustomerAndRide(customerId, ride.id, "payment_pending", {
      ride_id: ride.id,
      fare: ride.fare,
      payment_mode: ride.payment_mode,
      payment_status: "PENDING",
    });
  }

  return {
    message: "Drop OTP verified",
    ride_id: ride.id,
    status: ride.status,
    client_status: "DROP_OTP_VERIFIED",
  };
};

export const confirmCashReceived = async (driverIdInput: string | undefined, rideIdInput?: string) => {
  const driver = await getDriverOrThrow(driverIdInput);
  const ride = await getRideByIdOrThrow(rideIdInput);
  ensureRideBelongsToDriver(ride, driver.id);

  if (!ride.drop_otp_verified) {
    throw new HttpError(400, "Drop OTP must be verified before cash confirmation");
  }
  if (ride.payment_mode !== "CASH") {
    throw new HttpError(400, "This ride is not a cash payment ride");
  }

  if (ride.status === "COMPLETED" && ride.payment_status === "SUCCESS") {
    return {
      message: "Cash payment already recorded and ride completed",
      ride_id: ride.id,
      status: ride.status,
      payment_status: ride.payment_status,
    };
  }

  ride.payment_status = "SUCCESS";
  await ride.save();

  const customerId = String(ride.customer_id);
  emitCustomerAndRide(customerId, ride.id, "payment_success", {
    ride_id: ride.id,
    payment_status: "SUCCESS",
    payment_mode: "CASH",
    fare: ride.fare,
  });

  // Complete + wallet/dues/invoice in one step so history and finance always persist.
  if (ride.status !== "COMPLETED") {
    await finalizeCompletedRide(ride);
  } else {
    try {
      await processRidePayment(ride);
      await generateInvoice(ride);
    } catch (error) {
      logger.error({ error, ride_id: ride.id }, "Cash finance after already-completed ride failed");
    }
  }

  return {
    message: "Cash payment recorded and ride completed",
    ride_id: ride.id,
    status: "COMPLETED",
    payment_status: "SUCCESS",
    fare: ride.fare,
  };
};

export const completeRideAfterPayment = async (driverIdInput: string | undefined, rideIdInput?: string) => {
  const driver = await getDriverOrThrow(driverIdInput);
  const ride = await getRideByIdOrThrow(rideIdInput);
  ensureRideBelongsToDriver(ride, driver.id);

  if (!ride.drop_otp_verified) {
    throw new HttpError(400, "Drop OTP must be verified before completing ride");
  }
  if (ride.status === "COMPLETED") {
    return { message: "Ride already completed", ride_id: ride.id, status: ride.status };
  }
  if (ride.payment_mode === "ONLINE" && ride.payment_status !== "SUCCESS") {
    throw new HttpError(400, "Online payment must be successful before completing ride");
  }

  await finalizeCompletedRide(ride);

  return {
    message: "Ride completed successfully",
    ride_id: ride.id,
    status: "COMPLETED",
    fare: ride.fare,
    actual_distance_km: ride.actual_distance_km,
    payment_status: ride.payment_status,
  };
};

export const verifyRideOtpAndStartRide = async (
  driverIdInput: string | undefined,
  rideIdInput: string | undefined,
  otpInput: number
) => {
  const driver = await getDriverOrThrow(driverIdInput);
  const ride = await getRideByIdOrThrow(rideIdInput);

  ensureRideBelongsToDriver(ride, driver.id);
  if (ride.status !== "ARRIVED_AT_PICKUP") {
    throw new HttpError(400, "Ride must be in ARRIVED_AT_PICKUP state");
  }
  if (ride.otp_verified) {
    throw new HttpError(400, "OTP already verified for this ride");
  }

  if (ride.otp !== otpInput) {
    logger.warn(
      {
        ride_id: ride.id,
        driver_id: driver.id,
      },
      "Ride OTP verification failed"
    );
    throw new HttpError(400, "Invalid OTP");
  }

  ride.otp_verified = true;
  ride.status = "STARTED";
  ride.trip_started_at = new Date();
  await ride.save();

  logger.info({ ride_id: ride.id, driver_id: driver.id }, "Pickup OTP verified — trip started");
  const customerId = String(ride.customer_id);
  await emitRideLifecycle(ride, "STARTED");
  emitCustomerAndRide(customerId, ride.id, "pickup_otp_verified", {
    ride_id: ride.id,
    status: "STARTED",
    otp_verified: true,
  });
  emitCustomerAndRide(customerId, ride.id, "trip_started", {
    ride_id: ride.id,
    status: "STARTED",
  });
  emitCustomerAndRide(customerId, ride.id, "gps_tracking_started", {
    ride_id: ride.id,
  });
  await sendRideStatusPush(customerId, ride.id, "RIDE_STARTED", "Ride Started 🟢", "Enjoy your trip");

  return {
    message: "OTP verified, ride started",
    ride_id: ride.id,
    status: ride.status,
    client_status: "TRIP_STARTED",
  };
};

export const getDriverRideHistory = async (driverIdInput: string | undefined) => {
  const driver = await getDriverOrThrow(driverIdInput);

  const rides = await RideModel.find({ driver_id: driver.id }).sort({ createdAt: -1 });

  const detailedRides = await Promise.all(
    rides.map(async (ride) => {
      const customer = await UserModel.findOne({ _id: ride.customer_id, role: "CUSTOMER" });

      return {
        ride_id: ride.id,
        status: ride.status,
        pickup: ride.pickup,
        drop: ride.drop,
        actual_drop: ride.actual_drop ?? null,
        distance_km: ride.distance_km,
        actual_distance_km: ride.actual_distance_km ?? null,
        duration_min: ride.duration_min ?? null,
        actual_duration_min: ride.actual_duration_min ?? null,
        fare: ride.fare,
        payment_mode: ride.payment_mode ?? "CASH",
        payment_status: ride.payment_status ?? "PENDING",
        finance_processed: Boolean(ride.finance_processed),
        vehicle_type_id: ride.vehicle_type_id ? String(ride.vehicle_type_id) : null,
        drop_reached: Boolean(
          (ride as RideDocument & { drop_reached?: boolean }).drop_reached
        ),
        drop_otp_verified: Boolean(
          (ride as RideDocument & { drop_otp_verified?: boolean }).drop_otp_verified
        ),
        customer: customer
          ? {
              id: customer.id,
              name: customer.name,
              email: customer.email,
              phone: customer.phone ?? null,
            }
          : null,
        createdAt: ride.createdAt,
        updatedAt: ride.updatedAt,
        completed_at:
          ride.status === "COMPLETED"
            ? (ride as RideDocument & { completed_at?: Date }).completed_at ??
              ride.updatedAt ??
              null
            : null,
      };
    })
  );

  return {
    rides: detailedRides,
  };
};

const normalizeStatusAlias = (statusInput: string): RideStatus => {
  switch (statusInput) {
    case "SEARCHING":
      return "SEARCHING_DRIVER";
    case "ACCEPTED":
      return "DRIVER_ASSIGNED";
    case "DRIVER_ARRIVING":
      return "ARRIVED_AT_PICKUP";
    case "ARRIVED":
      return "ARRIVED_AT_PICKUP";
    case "STARTED":
      return "STARTED";
    case "COMPLETED":
      return "COMPLETED";
    case "CANCELLED":
      return "CANCELLED";
    default:
      throw new HttpError(400, "Unsupported status");
  }
};

export const updateRideStatusByDriver = async (
  driverIdInput: string | undefined,
  rideIdInput: string | undefined,
  statusInput: string
) => {
  const driver = await getDriverOrThrow(driverIdInput);
  const ride = await getRideByIdOrThrow(rideIdInput);
  ensureRideBelongsToDriver(ride, driver.id);

  const nextStatus = normalizeStatusAlias(statusInput);
  if (nextStatus === "COMPLETED") {
    if (!ride.drop_otp_verified) {
      throw new HttpError(400, "Drop OTP must be verified before completing ride");
    }
    if (ride.payment_mode === "ONLINE" && ride.payment_status !== "SUCCESS") {
      throw new HttpError(400, "Online payment must be successful before completing ride");
    }
    if (ride.status !== "COMPLETED") {
      if (ride.payment_mode === "CASH") {
        ride.payment_status = "SUCCESS";
      }
      await finalizeCompletedRide(ride);
    }
    return {
      message: "Ride completed successfully",
      ride_id: ride.id,
      status: "COMPLETED",
      payment_status: ride.payment_status,
    };
  }

  ride.status = nextStatus;
  await ride.save();

  const statusForClient = toClientStatus(ride.status);
  console.log("STATUS EMIT:", statusForClient);
  await emitRideLifecycle(ride, statusForClient);

  return {
    message: "Ride status updated",
    ride_id: ride.id,
    status: ride.status,
  };
};
