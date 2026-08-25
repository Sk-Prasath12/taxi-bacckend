import { Types } from "mongoose";
import { DriverProfileModel } from "../modules/driver-profile/driver-profile.model";
import { UserModel } from "../modules/users/users.model";

/** Resolve each driver's canonical vehicle_type_id (profile first, then user snapshot). */
export const getDriverVehicleTypeIdMap = async (
  driverIds: string[]
): Promise<Map<string, string>> => {
  const map = new Map<string, string>();
  const validIds = driverIds.filter((id) => Types.ObjectId.isValid(id));
  if (validIds.length === 0) return map;

  const objectIds = validIds.map((id) => new Types.ObjectId(id));

  const profiles = await DriverProfileModel.find({ user_id: { $in: objectIds } })
    .select("user_id vehicle_type_id")
    .lean();

  for (const profile of profiles) {
    if (profile.vehicle_type_id) {
      map.set(String(profile.user_id), String(profile.vehicle_type_id));
    }
  }

  const missing = objectIds.filter((id) => !map.has(String(id)));
  if (missing.length > 0) {
    const users = await UserModel.find({ _id: { $in: missing }, role: "DRIVER" })
      .select("_id driver_profile")
      .lean();
    for (const user of users) {
      const id = String(user._id);
      if (map.has(id)) continue;
      const snapshot = user.driver_profile as { vehicle_type_id?: Types.ObjectId | string } | undefined;
      const vehicleTypeId = snapshot?.vehicle_type_id;
      if (vehicleTypeId) map.set(id, String(vehicleTypeId));
    }
  }

  return map;
};

export const getDriverVehicleTypeId = async (driverId: string): Promise<string | null> => {
  const map = await getDriverVehicleTypeIdMap([driverId]);
  return map.get(driverId) ?? null;
};

export const driverMatchesVehicleType = (
  driverVehicleTypeId: string | null | undefined,
  requestedVehicleTypeId: string | null | undefined
): boolean => {
  if (!requestedVehicleTypeId) return true;
  if (!driverVehicleTypeId) return false;
  return String(driverVehicleTypeId) === String(requestedVehicleTypeId);
};
