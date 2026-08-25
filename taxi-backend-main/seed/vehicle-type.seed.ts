import { VehicleTypeModel } from "../src/modules/vehicle-type/vehicle-type.model";
import { CANONICAL_VEHICLE_TYPES } from "../src/constants/vehicle-types.constants";
import { Seed } from "./seed.types";

async function upsertCanonicalVehicleType(vehicleType: (typeof CANONICAL_VEHICLE_TYPES)[number]) {
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
    return;
  }

  await VehicleTypeModel.create({ ...vehicleType, is_active: true });
}

const run = async (): Promise<void> => {
  const allowedCodes = CANONICAL_VEHICLE_TYPES.map((v) => v.code);
  const allowedNames = CANONICAL_VEHICLE_TYPES.map((v) => v.name);

  for (const vehicleType of CANONICAL_VEHICLE_TYPES) {
    await upsertCanonicalVehicleType(vehicleType);
  }

  // Deactivate overlapping / legacy categories (Luxury, Hybrid, Van, old 5/7 Seater, etc.)
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

  console.log(
    "Canonical vehicle types synced:",
    CANONICAL_VEHICLE_TYPES.map((v) => `${v.code} (₹${v.per_km_rate}/km, ${v.max_passengers} seats)`).join(", ")
  );
};

const seed: Seed = {
  name: "vehicle-type-seed",
  run,
};

export default seed;
