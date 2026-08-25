import { VehicleTypeModel } from "./vehicle-type.model";
import {
  normalizeVehicleDisplayName,
  sortVehicleTypesByCanonicalOrder,
} from "../../constants/vehicle-types.constants";

const mapVehicleType = (vehicleType: {
  id: string;
  name: string;
  code?: string;
  per_km_rate: number;
  max_passengers: number;
  is_active: boolean;
}) => ({
  id: vehicleType.id,
  name: normalizeVehicleDisplayName(vehicleType.name),
  code: vehicleType.code ?? null,
  per_km_rate: vehicleType.per_km_rate,
  max_passengers: vehicleType.max_passengers,
  is_active: vehicleType.is_active,
});

export const getAllVehicleTypes = async () => {
  const vehicleTypes = await VehicleTypeModel.find().sort({ per_km_rate: 1, name: 1 });
  return sortVehicleTypesByCanonicalOrder(
    vehicleTypes.map((vt) =>
      mapVehicleType({
        id: vt.id,
        name: vt.name,
        code: vt.code,
        per_km_rate: vt.per_km_rate,
        max_passengers: vt.max_passengers,
        is_active: vt.is_active,
      })
    )
  );
};

export const getActiveVehicleTypes = async () => {
  const vehicleTypes = await VehicleTypeModel.find({ is_active: true }).sort({
    per_km_rate: 1,
    name: 1,
  });
  return sortVehicleTypesByCanonicalOrder(
    vehicleTypes.map((vt) =>
      mapVehicleType({
        id: vt.id,
        name: vt.name,
        code: vt.code,
        per_km_rate: vt.per_km_rate,
        max_passengers: vt.max_passengers,
        is_active: vt.is_active,
      })
    )
  );
};
