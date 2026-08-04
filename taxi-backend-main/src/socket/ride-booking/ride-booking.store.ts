import { ActiveRideState, DriverOnlineState } from "./ride-booking.types";

const driversOnline = new Map<string, DriverOnlineState>();
const activeRides = new Map<string, ActiveRideState>();

export const upsertOnlineDriver = (state: DriverOnlineState) => {
  driversOnline.set(state.driverId, state);
};

export const removeOnlineDriver = (driverId: string) => {
  driversOnline.delete(driverId);
};

export const listOnlineDrivers = (): DriverOnlineState[] => {
  return Array.from(driversOnline.values());
};

export const getOnlineDriver = (driverId: string): DriverOnlineState | null => {
  return driversOnline.get(driverId) ?? null;
};

export const upsertActiveRide = (ride: ActiveRideState) => {
  activeRides.set(ride.rideId, ride);
};

export const getActiveRide = (rideId: string): ActiveRideState | null => {
  return activeRides.get(rideId) ?? null;
};

export const removeActiveRide = (rideId: string) => {
  activeRides.delete(rideId);
};
