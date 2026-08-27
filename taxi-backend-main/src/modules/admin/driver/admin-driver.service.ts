import { isValidObjectId } from "mongoose";
import { HttpError } from "../../../utils/http-error";
import { RideModel } from "../../customer/ride/ride.model";
import { RatingModel } from "../../rating/rating.model";
import { DriverProfileModel } from "../../driver-profile/driver-profile.model";
import { UserModel } from "../../users/users.model";
import { VehicleTypeModel } from "../../vehicle-type/vehicle-type.model";
import { adminFinalApproveDriver } from "../../driver-documents/driver-document.service";

const toPositiveInt = (value: unknown, fallback: number) => {
  const num = Number(value);
  if (!Number.isFinite(num) || num < 1) {
    return fallback;
  }
  return Math.floor(num);
};

const ensureDriverId = (driverId: string) => {
  if (!isValidObjectId(driverId)) {
    throw new HttpError(400, "Invalid driver id");
  }
};

const getDriverOrThrow = async (driverId: string) => {
  ensureDriverId(driverId);

  const driver = await UserModel.findOne({ _id: driverId, role: "DRIVER" });
  if (!driver) {
    throw new HttpError(404, "Driver not found");
  }

  return driver;
};

export const getAdminDrivers = async (
  pageInput?: unknown,
  limitInput?: unknown,
  searchInput?: unknown,
  pendingApprovalOnly?: boolean,
) => {
  const page = toPositiveInt(pageInput, 1);
  const limit = Math.min(toPositiveInt(limitInput, 10), 500);
  const search = typeof searchInput === "string" ? searchInput.trim() : "";

  const query: Record<string, unknown> = { role: "DRIVER" };
  if (pendingApprovalOnly) {
    query.driver_verification_status = { $ne: "APPROVED" };
  }
  if (search) {
    query.$or = [{ email: { $regex: search, $options: "i" } }, { name: { $regex: search, $options: "i" } }];
  }

  const [drivers, total] = await Promise.all([
    UserModel.find(query)
      .sort({ created_at: -1 })
      .skip((page - 1) * limit)
      .limit(limit),
    UserModel.countDocuments(query),
  ]);

  const driverIds = drivers.map((driver) => driver._id);
  const [tripCounts, ratingAverages, driverProfiles] = await Promise.all([
    RideModel.aggregate<{ _id: string; total_trips: number }>([
      { $match: { driver_id: { $in: driverIds } } },
      { $group: { _id: "$driver_id", total_trips: { $sum: 1 } } },
    ]),
    RatingModel.aggregate<{ _id: string; overall_rating: number }>([
      { $match: { to_user_id: { $in: driverIds }, to_role: "DRIVER" } },
      { $group: { _id: "$to_user_id", overall_rating: { $avg: "$rating" } } },
      { $project: { _id: 1, overall_rating: { $round: ["$overall_rating", 1] } } },
    ]),
    DriverProfileModel.find({ user_id: { $in: driverIds } })
      .select("user_id vehicle_type_id vehicle_reg_number vehicle_model")
      .lean(),
  ]);

  const vehicleTypeIds = driverProfiles
    .map((profile) => profile.vehicle_type_id)
    .filter((id): id is NonNullable<typeof id> => Boolean(id));
  const vehicleTypes = vehicleTypeIds.length
    ? await VehicleTypeModel.find({ _id: { $in: vehicleTypeIds } }).select("name").lean()
    : [];

  const tripCountByDriverId = new Map(tripCounts.map((item) => [String(item._id), item.total_trips]));
  const ratingByDriverId = new Map(ratingAverages.map((item) => [String(item._id), item.overall_rating]));
  const profileByDriverId = new Map(driverProfiles.map((profile) => [String(profile.user_id), profile]));
  const vehicleTypeById = new Map(vehicleTypes.map((vehicleType) => [String(vehicleType._id), vehicleType.name]));

  return {
    page,
    limit,
    total,
    total_pages: Math.ceil(total / limit) || 1,
    drivers: drivers.map((driver) => ({
      id: driver.id,
      name: driver.name,
      email: driver.email,
      phone: driver.phone ?? null,
      driver_status: driver.driver_status ?? "OFFLINE",
      vehicle_type: profileByDriverId.get(driver.id)?.vehicle_type_id
        ? vehicleTypeById.get(String(profileByDriverId.get(driver.id)?.vehicle_type_id)) ?? null
        : null,
      vehicle_number: profileByDriverId.get(driver.id)?.vehicle_reg_number ?? null,
      vehicle_model: profileByDriverId.get(driver.id)?.vehicle_model ?? null,
      is_driver_verified: driver.is_driver_verified === true,
      driver_verification_status: driver.driver_verification_status ?? "PENDING",
      is_blocked: driver.is_blocked,
      blocked_reason: driver.blocked_reason ?? null,
      total_trips: tripCountByDriverId.get(driver.id) ?? 0,
      overall_rating: ratingByDriverId.get(driver.id) ?? 0,
      createdAt: driver.get("created_at"),
    })),
  };
};

export const getAdminDriverDetails = async (driverId: string) => {
  const driver = await getDriverOrThrow(driverId);
  const [totalTrips, completedTrips, cancelledTrips, activeTrips, ratingSummary, driverProfile] = await Promise.all([
    RideModel.countDocuments({ driver_id: driver.id }),
    RideModel.countDocuments({ driver_id: driver.id, status: "COMPLETED" }),
    RideModel.countDocuments({ driver_id: driver.id, status: "CANCELLED" }),
    RideModel.countDocuments({
      driver_id: driver.id,
      status: { $in: ["DRIVER_ASSIGNED", "ARRIVED_AT_PICKUP", "STARTED", "PICKED_UP", "IN_TRANSIT"] },
    }),
    RatingModel.aggregate<{ overall_rating: number }>([
      { $match: { to_user_id: driver._id, to_role: "DRIVER" } },
      { $group: { _id: null, overall_rating: { $avg: "$rating" } } },
      { $project: { _id: 0, overall_rating: { $round: ["$overall_rating", 1] } } },
    ]),
    DriverProfileModel.findOne({ user_id: driver._id }).lean(),
  ]);
  const overallRating = ratingSummary[0]?.overall_rating ?? 0;
  const vehicleType =
    driverProfile?.vehicle_type_id
      ? ((await VehicleTypeModel.findById(driverProfile.vehicle_type_id).select("name").lean())?.name ?? null)
      : null;
  const vehicleNumber = driverProfile?.vehicle_reg_number ?? null;
  const vehicleModel = driverProfile?.vehicle_model ?? null;

  return {
    id: driver.id,
    name: driver.name,
    email: driver.email,
    phone: driver.phone ?? null,
    is_active: driver.is_active,
    is_blocked: driver.is_blocked,
    blocked_reason: driver.blocked_reason ?? null,
    driver_status: driver.driver_status ?? "OFFLINE",
    is_driver_verified: driver.is_driver_verified === true,
    driver_verification_status: driver.driver_verification_status ?? "PENDING",
    vehicle_type: vehicleType,
    vehicle_number: vehicleNumber,
    vehicle_model: vehicleModel,
    overall_rating: overallRating,
    driver_profile: driverProfile ?? driver.driver_profile ?? null,
    createdAt: driver.get("created_at"),
    updatedAt: driver.get("updated_at"),
    stats: {
      total_trips: totalTrips,
      completed_trips: completedTrips,
      cancelled_trips: cancelledTrips,
      active_trips: activeTrips,
      rating: overallRating,
    },
  };
};

export const updateAdminDriverBlockStatus = async (driverId: string, isBlocked: boolean, reason?: string) => {
  if (typeof isBlocked !== "boolean") {
    throw new HttpError(400, "is_blocked must be a boolean");
  }

  const driver = await getDriverOrThrow(driverId);

  if (isBlocked) {
    const blockedReason = reason?.trim();
    if (!blockedReason) {
      throw new HttpError(400, "Reason is required when blocking driver");
    }
    driver.is_blocked = true;
    driver.blocked_reason = blockedReason;
  } else {
    driver.is_blocked = false;
    driver.blocked_reason = undefined;
  }

  await driver.save();

  return {
    message: isBlocked ? "Driver blocked successfully" : "Driver unblocked successfully",
  };
};

/** One-click account approval (no documents required). */
export const adminApproveDriverAccount = async (driverId: string) => {
  return adminFinalApproveDriver(driverId);
};

export const adminApproveDriverByEmail = async (email: string) => {
  const normalized = email.toLowerCase().trim();
  const driver = await UserModel.findOne({ email: normalized, role: "DRIVER" });
  if (!driver) {
    throw new HttpError(404, "Driver not found for this email");
  }
  return adminFinalApproveDriver(driver.id);
};

export const getAdminDriverRideHistory = async (driverId: string) => {
  const driver = await getDriverOrThrow(driverId);
  const rides = await RideModel.find({ driver_id: driver.id }).sort({ createdAt: -1 });

  return {
    driver: {
      id: driver.id,
      name: driver.name,
      email: driver.email,
      phone: driver.phone ?? null,
    },
    rides: rides.map((ride) => ({
      ride_id: ride.id,
      customer_id: String(ride.customer_id),
      vehicle_type_id: ride.vehicle_type_id ? String(ride.vehicle_type_id) : null,
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
      otp_verified: ride.otp_verified,
      drop_otp_verified: Boolean(ride.drop_otp_verified),
      status: ride.status,
      completed_at: ride.completed_at ?? null,
      createdAt: ride.createdAt,
      updatedAt: ride.updatedAt,
    })),
  };
};

export const getAdminDriverRideDetails = async (driverId: string, rideId: string) => {
  const driver = await getDriverOrThrow(driverId);
  if (!isValidObjectId(rideId)) {
    throw new HttpError(400, "Invalid ride id");
  }

  const ride = await RideModel.findOne({ _id: rideId, driver_id: driver._id });
  if (!ride) {
    throw new HttpError(404, "Ride not found for this driver");
  }

  const [customer, vehicleType] = await Promise.all([
    UserModel.findOne({ _id: ride.customer_id, role: "CUSTOMER" }),
    ride.vehicle_type_id ? VehicleTypeModel.findById(ride.vehicle_type_id) : null,
  ]);

  return {
    ride: {
      ride_id: ride.id,
      status: ride.status,
      pickup: ride.pickup,
      drop: ride.drop,
      distance_km: ride.distance_km,
      duration_min: ride.duration_min ?? null,
      fare: ride.fare,
      payment_mode: ride.payment_mode ?? "CASH",
      payment_status: ride.payment_status ?? "PENDING",
      finance_processed: ride.finance_processed ?? false,
      otp: ride.otp,
      otp_verified: ride.otp_verified,
      createdAt: ride.createdAt,
      updatedAt: ride.updatedAt,
      customer: customer
        ? {
            id: customer.id,
            name: customer.name,
            email: customer.email,
            phone: customer.phone ?? null,
            is_blocked: customer.is_blocked,
          }
        : null,
      driver: {
        id: driver.id,
        name: driver.name,
        email: driver.email,
        phone: driver.phone ?? null,
        driver_status: driver.driver_status ?? "OFFLINE",
        is_blocked: driver.is_blocked,
        driver_verification_status: driver.driver_verification_status ?? "PENDING",
      },
      vehicle_type: vehicleType
        ? {
            id: vehicleType.id,
            name: vehicleType.name,
            per_km_rate: vehicleType.per_km_rate,
            is_active: vehicleType.is_active,
          }
        : null,
    },
  };
};
