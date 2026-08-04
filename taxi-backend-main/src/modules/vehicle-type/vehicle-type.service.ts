import { VehicleTypeModel } from "./vehicle-type.model";

const mapVehicleType = (vehicleType: {
  id: string;
  name: string;
  per_km_rate: number;
  max_passengers: number;
  is_active: boolean;
}) => ({
  id: vehicleType.id,
  name: vehicleType.name,
  per_km_rate: vehicleType.per_km_rate,
  max_passengers: vehicleType.max_passengers,
  is_active: vehicleType.is_active,
});

export const getAllVehicleTypes = async () => {
  const vehicleTypes = await VehicleTypeModel.find().sort({ name: 1 });
  return vehicleTypes.map(mapVehicleType);
};

export const getActiveVehicleTypes = async () => {
  const vehicleTypes = await VehicleTypeModel.find({ is_active: true }).sort({ name: 1 });
  return vehicleTypes.map(mapVehicleType);
};
