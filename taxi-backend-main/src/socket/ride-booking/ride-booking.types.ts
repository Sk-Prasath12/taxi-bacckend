import { Socket } from "socket.io";

export type Coordinate = {
  lat: number;
  lng: number;
};

export type SocketIdentity = {
  userId: string;
  role: "customer" | "driver";
};

export type DriverOnlinePayload = {
  driverId?: string;
  location?: Coordinate;
};

export type RideRequestPayload = {
  customerId?: string;
  pickup: Coordinate;
  drop: Coordinate;
};

export type RideAcceptPayload = {
  rideId: string;
  driverId?: string;
};

export type RideLifecyclePayload = {
  rideId: string;
  driverId?: string;
};

export type ActiveRideState = {
  rideId: string;
  customerId: string;
  driverId: string | null;
  status: "SEARCHING_DRIVER" | "DRIVER_ASSIGNED" | "ARRIVED_AT_PICKUP" | "STARTED" | "COMPLETED";
};

export type DriverOnlineState = {
  driverId: string;
  socketId: string;
  location: Coordinate;
  updatedAt: number;
};

export type SocketWithIdentity = Socket & {
  data: {
    identity?: SocketIdentity;
  };
};
