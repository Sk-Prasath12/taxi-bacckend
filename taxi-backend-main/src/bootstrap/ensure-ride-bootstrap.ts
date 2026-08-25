import { logger } from "../config/logger";
import { findUserByEmail, createUser } from "../modules/users/users.repository";
import { OperationalZoneModel } from "../modules/operational-zone/operational-zone.model";
import { VehicleTypeModel } from "../modules/vehicle-type/vehicle-type.model";
import { hashPassword } from "../utils/password.util";
import { UserModel } from "../modules/users/users.model";
import { DriverProfileModel } from "../modules/driver-profile/driver-profile.model";

import { CANONICAL_VEHICLE_TYPES } from "../constants/vehicle-types.constants";

const CHENNAI_ZONE_NAME = "Tamil Nadu Service Area";
// Tamil Nadu service box (lng, lat) — matches customer app service bounds.
const CHENNAI_POLYGON: [number, number][] = [
  [76.0, 8.0],
  [80.45, 8.0],
  [80.45, 13.9],
  [76.0, 13.9],
  [76.0, 8.0],
];

const DUMMY_DRIVER_EMAIL = "dummy.driver@taxi.local";
const DUMMY_DRIVER_PASSWORD = "Driver@1234";
const DUMMY_LAT = 13.0067;
const DUMMY_LNG = 80.2206;

declare global {
  // eslint-disable-next-line no-var
  var __taxiRideBootstrapReady: Promise<void> | undefined;
}

async function ensureDummyDriver(): Promise<void> {
  const car =
    (await VehicleTypeModel.findOne({ code: "SEDAN", is_active: true })) ??
    (await VehicleTypeModel.findOne({ code: "MINI", is_active: true }));
  if (!car) return;

  const passwordHash = await hashPassword(DUMMY_DRIVER_PASSWORD);
  let driver = await UserModel.findOne({ email: DUMMY_DRIVER_EMAIL, role: "DRIVER" });
  const now = new Date();
  const geo = { type: "Point" as const, coordinates: [DUMMY_LNG, DUMMY_LAT] as [number, number] };

  if (!driver) {
    driver = await createUser({
      name: "Dummy Driver",
      email: DUMMY_DRIVER_EMAIL,
      password_hash: passwordHash,
      role: "DRIVER",
      is_active: true,
      is_blocked: false,
    });
  }

  await UserModel.updateOne(
    { _id: driver._id },
    {
      $set: {
        password_hash: passwordHash,
        phone: "9999990001",
        is_active: true,
        is_blocked: false,
        is_driver_verified: true,
        driver_verification_status: "APPROVED",
        driver_status: "ONLINE",
        driver_location: geo,
        driver_location_updated_at: now,
      },
    }
  );

  await DriverProfileModel.findOneAndUpdate(
    { user_id: driver._id },
    {
      $set: {
        user_id: driver._id,
        phone: "9999990001",
        address: "Guindy, Chennai",
        license_number: "TN-DUMMY-001",
        vehicle_reg_number: "TN01DM9999",
        vehicle_model: "Swift Dzire",
        vehicle_color: "White",
        vehicle_type_id: car._id,
        aadhaar_number: "999999999999",
        pan_number: "DUMMY9999D",
        account_holder_name: "Dummy Driver",
        account_number: "1234567890",
        ifsc_code: "DUMMY0001234",
        profile_completed: true,
      },
    },
    { upsert: true }
  );
}

async function ensureRideBootstrapOnce(): Promise<void> {
  const allowedCodes = CANONICAL_VEHICLE_TYPES.map((v) => v.code);
  const allowedNames = CANONICAL_VEHICLE_TYPES.map((v) => v.name);

  for (const vehicleType of CANONICAL_VEHICLE_TYPES) {
    const existing =
      (await VehicleTypeModel.findOne({ code: vehicleType.code })) ??
      (await VehicleTypeModel.findOne({ name: vehicleType.name }));
    if (existing) {
      existing.code = vehicleType.code;
      existing.name = vehicleType.name;
      existing.per_km_rate = vehicleType.per_km_rate;
      existing.max_passengers = vehicleType.max_passengers;
      existing.is_active = true;
      await existing.save();
    } else {
      await VehicleTypeModel.create({ ...vehicleType, is_active: true });
    }
  }

  await VehicleTypeModel.updateMany(
    {
      $or: [
        { code: { $exists: true, $nin: allowedCodes } },
        { code: { $in: [null, ""] }, name: { $nin: allowedNames } },
        { code: { $exists: false }, name: { $nin: allowedNames } },
      ],
    },
    { $set: { is_active: false } }
  );

  const polygon = {
    type: "Polygon" as const,
    coordinates: [CHENNAI_POLYGON],
  };

  const existingZone = await OperationalZoneModel.findOne({ zone_name: CHENNAI_ZONE_NAME });
  if (existingZone) {
    existingZone.polygon = polygon;
    existingZone.is_active = true;
    await existingZone.save();
  } else {
    const admin = await findUserByEmail("admin@taxigo.com");
    if (admin) {
      await OperationalZoneModel.create({
        zone_name: CHENNAI_ZONE_NAME,
        polygon,
        is_active: true,
        created_by: admin._id,
      });
    } else {
      logger.warn("Admin missing — Tamil Nadu zone not created yet");
    }
  }

  try {
    await ensureDummyDriver();
  } catch (error) {
    logger.warn({ error }, "Dummy driver bootstrap skipped");
  }

  logger.info("Ride bootstrap ready (vehicle types + Tamil Nadu zone + dummy driver)");
}

/** Idempotent — keeps Vercel/Atlas booking data ready on cold start. */
export function ensureRideBootstrap(): Promise<void> {
  if (!global.__taxiRideBootstrapReady) {
    global.__taxiRideBootstrapReady = ensureRideBootstrapOnce().catch((error) => {
      global.__taxiRideBootstrapReady = undefined;
      throw error;
    });
  }
  return global.__taxiRideBootstrapReady;
}
