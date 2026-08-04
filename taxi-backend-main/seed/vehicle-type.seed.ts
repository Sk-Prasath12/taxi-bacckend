import { VehicleTypeModel } from "../src/modules/vehicle-type/vehicle-type.model";
import { Seed } from "./seed.types";

/** Only these 4 types are shown to customers. */
const CUSTOMER_VEHICLE_TYPES = [
  { name: "Bike", per_km_rate: 10, max_passengers: 1 },
  { name: "Auto", per_km_rate: 20, max_passengers: 3 },
  { name: "Small 5 Seater Car", per_km_rate: 30, max_passengers: 5 },
  { name: "Big 7 Seater Car", per_km_rate: 40, max_passengers: 7 },
];

const run = async (): Promise<void> => {
  const allowedNames = CUSTOMER_VEHICLE_TYPES.map((v) => v.name);

  for (const vehicleType of CUSTOMER_VEHICLE_TYPES) {
    await VehicleTypeModel.findOneAndUpdate(
      { name: vehicleType.name },
      { ...vehicleType, is_active: true },
      { upsert: true, new: true }
    );
  }

  await VehicleTypeModel.updateMany(
    { name: { $nin: allowedNames } },
    { $set: { is_active: false } }
  );

  console.log("Customer vehicle types synced (Bike, Auto, Small 5 Seater, Big 7 Seater)");
};

const seed: Seed = {
  name: "vehicle-type-seed",
  run,
};

export default seed;
