import { RideDocument } from "../modules/customer/ride/ride.model";
import { DriverProfileModel } from "../modules/driver-profile/driver-profile.model";
import { UserModel } from "../modules/users/users.model";
import { VehicleTypeModel } from "../modules/vehicle-type/vehicle-type.model";
import { normalizeVehicleDisplayName } from "../constants/vehicle-types.constants";

export const getDriverContactDetails = async (driverId?: string | null) => {
  if (!driverId) return null;
  const driver = await UserModel.findOne({ _id: driverId, role: "DRIVER" }).lean();
  if (!driver) return null;

  const profile = await DriverProfileModel.findOne({ user_id: driver._id }).lean();
  let vehicleTypeName: string | null = null;
  if (profile?.vehicle_type_id) {
    const vt = await VehicleTypeModel.findById(profile.vehicle_type_id).lean();
    if (vt?.name) vehicleTypeName = normalizeVehicleDisplayName(vt.name);
  }

  const phone = (driver.phone ?? profile?.phone ?? null)?.toString().trim() || null;

  return {
    id: String(driver._id),
    name: driver.name,
    phone,
    status: driver.driver_status ?? "OFFLINE",
    vehicle_type: vehicleTypeName,
    vehicle_number: profile?.vehicle_reg_number ?? null,
    vehicle_model: profile?.vehicle_model ?? null,
    vehicle_color: profile?.vehicle_color ?? null,
    vehicle: {
      type: vehicleTypeName,
      number: profile?.vehicle_reg_number ?? null,
      model: profile?.vehicle_model ?? null,
      color: profile?.vehicle_color ?? null,
    },
  };
};

export const getCustomerContactDetails = async (customerId?: string | null) => {
  if (!customerId) return null;
  const customer = await UserModel.findOne({ _id: customerId, role: "CUSTOMER" }).lean();
  if (!customer) return null;
  return {
    id: String(customer._id),
    name: customer.name,
    phone: customer.phone ?? null,
    email: customer.email ?? null,
  };
};

/** Client-facing status including flexible drop-reached stages. */
export const toFlexibleClientStatus = (ride: RideDocument): string => {
  if (ride.status === "SEARCHING_DRIVER") return "SEARCHING";
  if (ride.status === "DRIVER_ASSIGNED") return "ACCEPTED";
  if (ride.status === "ARRIVED_AT_PICKUP") return "ARRIVED";
  if (ride.status === "STARTED") return "STARTED";
  if (ride.status === "PICKED_UP" || ride.status === "IN_TRANSIT") {
    const dropReached = (ride as RideDocument & { drop_reached?: boolean }).drop_reached === true;
    const dropVerified =
      (ride as RideDocument & { drop_otp_verified?: boolean }).drop_otp_verified === true;
    if (dropReached && !dropVerified) return "DROP_REACHED";
    if (dropVerified) return "DROP_OTP_VERIFIED";
    return "IN_TRANSIT";
  }
  if (ride.status === "COMPLETED") return "COMPLETED";
  if (ride.status === "CANCELLED") return "CANCELLED";
  return ride.status;
};

export const buildRideEmitPayload = async (ride: RideDocument) => {
  const driver = await getDriverContactDetails(ride.driver_id ? String(ride.driver_id) : null);
  const customer = await getCustomerContactDetails(String(ride.customer_id));
  const extended = ride as RideDocument & {
    drop_otp?: number;
    drop_otp_verified?: boolean;
    drop_reached?: boolean;
    actual_drop?: { lat: number; lng: number; address: string };
    actual_distance_km?: number;
    actual_duration_min?: number;
    trip_started_at?: Date;
  };

  return {
    ride_id: ride.id,
    id: ride.id,
    customer_id: String(ride.customer_id),
    vehicle_type_id: ride.vehicle_type_id ? String(ride.vehicle_type_id) : null,
    vehicle_type: driver?.vehicle_type ?? null,
    driver_id: ride.driver_id ? String(ride.driver_id) : null,
    pickup: ride.pickup,
    drop: ride.drop,
    actual_drop: extended.actual_drop ?? null,
    distance_km: extended.actual_distance_km ?? ride.distance_km,
    booked_distance_km: ride.distance_km,
    actual_distance_km: extended.actual_distance_km ?? null,
    duration_min: extended.actual_duration_min ?? ride.duration_min ?? 0,
    actual_duration_min: extended.actual_duration_min ?? null,
    fare: ride.fare,
    driver_earning: ride.driver_earning ?? null,
    commission_amount: ride.commission_amount ?? null,
    currency: "INR",
    status: ride.status,
    client_status: toFlexibleClientStatus(ride),
    payment_mode: ride.payment_mode ?? "CASH",
    payment_status: ride.payment_status ?? "PENDING",
    otp: typeof ride.otp === "number" && ride.otp !== 1000 ? ride.otp : null,
    otp_verified: Boolean(ride.otp_verified),
    drop_otp: typeof extended.drop_otp === "number" ? extended.drop_otp : null,
    drop_otp_verified: Boolean(extended.drop_otp_verified),
    drop_reached: Boolean(extended.drop_reached),
    accepted_at: ride.accepted_at ?? null,
    trip_started_at: extended.trip_started_at ?? null,
    finance_processed: Boolean(ride.finance_processed),
    completed_at: ride.completed_at ?? (ride.status === "COMPLETED" ? ride.updatedAt ?? null : null),
    cancelled_at: ride.cancelled_at ?? null,
    cancelled_by: ride.cancelled_by ?? null,
    cancellation_reason: ride.cancellation_reason ?? null,
    previous_status: ride.previous_status ?? null,
    can_cancel:
      !ride.otp_verified &&
      !ride.trip_started_at &&
      ["PENDING_CONFIRMATION", "SEARCHING_DRIVER", "DRIVER_ASSIGNED", "ARRIVED_AT_PICKUP"].includes(
        ride.status
      ),
    emergency_alerted: Boolean(ride.emergency_alerted),
    emergency_at: ride.emergency_at ?? null,
    emergency_location: ride.emergency_location ?? null,
    driver,
    customer,
    driver_name: driver?.name ?? null,
    driver_phone: driver?.phone ?? null,
    customer_name: customer?.name ?? null,
    customer_phone: customer?.phone ?? null,
    createdAt: ride.createdAt,
    updatedAt: ride.updatedAt,
    created_at: ride.createdAt ?? null,
    updated_at: ride.updatedAt ?? null,
  };
};
