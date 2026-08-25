import { RideModel } from "../customer/ride/ride.model";
import { UserModel } from "../users/users.model";
import { VehicleTypeModel } from "../vehicle-type/vehicle-type.model";
import { DriverProfileModel } from "../driver-profile/driver-profile.model";
import { buildRideEmitPayload, toFlexibleClientStatus } from "../../utils/ride-emit.util";
import type { RideDocument } from "../customer/ride/ride.model";

const ACTIVE_RIDE_STATUSES = [
  "PENDING_CONFIRMATION",
  "SEARCHING_DRIVER",
  "DRIVER_ASSIGNED",
  "ARRIVED_AT_PICKUP",
  "STARTED",
  "PICKED_UP",
  "IN_TRANSIT",
] as const;

export const listAdminLiveRides = async () => {
  const rides = await RideModel.find({ status: { $in: [...ACTIVE_RIDE_STATUSES] } })
    .sort({ updatedAt: -1 })
    .limit(100)
    .lean();

  const customerIds = [...new Set(rides.map((r) => String(r.customer_id)))];
  const driverIds = [
    ...new Set(rides.filter((r) => r.driver_id).map((r) => String(r.driver_id))),
  ];
  const vehicleTypeIds = [
    ...new Set(rides.filter((r) => r.vehicle_type_id).map((r) => String(r.vehicle_type_id))),
  ];

  const [customers, drivers, vehicleTypes, profiles] = await Promise.all([
    customerIds.length
      ? UserModel.find({ _id: { $in: customerIds } })
          .select("name phone email")
          .lean()
      : [],
    driverIds.length
      ? UserModel.find({ _id: { $in: driverIds } })
          .select("name phone email driver_status")
          .lean()
      : [],
    vehicleTypeIds.length
      ? VehicleTypeModel.find({ _id: { $in: vehicleTypeIds } })
          .select("name")
          .lean()
      : [],
    driverIds.length
      ? DriverProfileModel.find({ user_id: { $in: driverIds } })
          .select("user_id vehicle_reg_number vehicle_model")
          .lean()
      : [],
  ]);

  const customerMap = new Map(customers.map((c) => [String(c._id), c]));
  const driverMap = new Map(drivers.map((d) => [String(d._id), d]));
  const vehicleMap = new Map(vehicleTypes.map((v) => [String(v._id), v.name]));
  const profileMap = new Map(profiles.map((p) => [String(p.user_id), p]));

  return rides.map((ride) => {
    const customer = customerMap.get(String(ride.customer_id));
    const driver = ride.driver_id ? driverMap.get(String(ride.driver_id)) : null;
    const profile = ride.driver_id ? profileMap.get(String(ride.driver_id)) : null;
    return {
      ride_id: String(ride._id),
      status: ride.status,
      client_status: toFlexibleClientStatus(ride as RideDocument),
      pickup: ride.pickup,
      drop: ride.drop,
      fare: ride.fare,
      distance_km: ride.distance_km,
      duration_min: ride.duration_min ?? null,
      payment_mode: ride.payment_mode ?? "CASH",
      payment_status: ride.payment_status ?? "PENDING",
      vehicle_type: ride.vehicle_type_id
        ? vehicleMap.get(String(ride.vehicle_type_id)) ?? null
        : null,
      vehicle_type_id: ride.vehicle_type_id ? String(ride.vehicle_type_id) : null,
      customer: customer
        ? {
            id: String(customer._id),
            name: customer.name,
            phone: customer.phone ?? null,
            email: customer.email ?? null,
          }
        : null,
      driver: driver
        ? {
            id: String(driver._id),
            name: driver.name,
            phone: driver.phone ?? null,
            email: driver.email ?? null,
            status: driver.driver_status ?? "OFFLINE",
            vehicle_number: profile?.vehicle_reg_number ?? null,
            vehicle_model: profile?.vehicle_model ?? null,
          }
        : null,
      created_at: ride.createdAt ?? null,
      updated_at: ride.updatedAt ?? null,
      trip_started_at: (ride as { trip_started_at?: Date }).trip_started_at ?? null,
    };
  });
};

export const getAdminLiveRideDetail = async (rideId: string) => {
  const ride = await RideModel.findById(rideId);
  if (!ride) return null;
  return buildRideEmitPayload(ride);
};

const TERMINAL_STATUSES = ["COMPLETED", "CANCELLED"] as const;

export const listAdminRideHistory = async (options: {
  status?: "active" | "completed" | "cancelled" | "all";
  limit?: number;
} = {}) => {
  const limit = Math.min(options.limit ?? 100, 200);
  const statusFilter =
    options.status === "completed"
      ? { status: "COMPLETED" }
      : options.status === "cancelled"
        ? { status: "CANCELLED" }
        : options.status === "active"
          ? { status: { $nin: [...TERMINAL_STATUSES] } }
          : {};

  const rides = await RideModel.find(statusFilter).sort({ updatedAt: -1 }).limit(limit).lean();

  const customerIds = [...new Set(rides.map((r) => String(r.customer_id)))];
  const driverIds = [...new Set(rides.filter((r) => r.driver_id).map((r) => String(r.driver_id)))];
  const vehicleTypeIds = [
    ...new Set(rides.filter((r) => r.vehicle_type_id).map((r) => String(r.vehicle_type_id))),
  ];

  const [customers, drivers, vehicleTypes] = await Promise.all([
    customerIds.length
      ? UserModel.find({ _id: { $in: customerIds } }).select("name phone email").lean()
      : [],
    driverIds.length
      ? UserModel.find({ _id: { $in: driverIds } }).select("name phone email").lean()
      : [],
    vehicleTypeIds.length
      ? VehicleTypeModel.find({ _id: { $in: vehicleTypeIds } }).select("name code").lean()
      : [],
  ]);

  const customerMap = new Map(customers.map((c) => [String(c._id), c]));
  const driverMap = new Map(drivers.map((d) => [String(d._id), d]));
  const vehicleMap = new Map(
    vehicleTypes.map((v) => [String(v._id), { name: v.name, code: v.code }])
  );

  return rides.map((ride) => {
    const customer = customerMap.get(String(ride.customer_id));
    const driver = ride.driver_id ? driverMap.get(String(ride.driver_id)) : null;
    const vehicle = ride.vehicle_type_id
      ? vehicleMap.get(String(ride.vehicle_type_id))
      : null;
    return {
      ride_id: String(ride._id),
      status: ride.status,
      client_status: toFlexibleClientStatus(ride as RideDocument),
      pickup: ride.pickup,
      drop: ride.drop,
      fare: ride.fare,
      distance_km: ride.distance_km,
      duration_min: ride.duration_min ?? null,
      payment_mode: ride.payment_mode ?? "CASH",
      payment_status: ride.payment_status ?? "PENDING",
      vehicle_type: vehicle?.name ?? null,
      vehicle_type_code: vehicle?.code ?? null,
      customer: customer
        ? {
            id: String(customer._id),
            name: customer.name,
            phone: customer.phone ?? null,
            email: customer.email ?? null,
          }
        : null,
      driver: driver
        ? {
            id: String(driver._id),
            name: driver.name,
            phone: driver.phone ?? null,
            email: driver.email ?? null,
          }
        : null,
      created_at: ride.createdAt ?? null,
      updated_at: ride.updatedAt ?? null,
      trip_started_at: (ride as { trip_started_at?: Date }).trip_started_at ?? null,
      completed_at: ride.status === "COMPLETED" ? ride.updatedAt ?? null : null,
    };
  });
};

export const getAdminRideHistoryDetail = async (rideId: string) => {
  const ride = await RideModel.findById(rideId);
  if (!ride) return null;
  return buildRideEmitPayload(ride);
};
