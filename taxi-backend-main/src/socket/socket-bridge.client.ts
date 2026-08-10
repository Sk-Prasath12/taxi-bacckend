import axios from "axios";
import { logger } from "../config/logger";
import { env } from "../config/env";

export type SocketBridgeRoomEmit = {
  type: "room";
  room: string;
  event: string;
  payload: Record<string, unknown>;
};

export type SocketBridgeRoomsEmit = {
  type: "rooms";
  rooms: string[];
  event: string;
  payload: Record<string, unknown>;
};

export type SocketBridgeNewRide = {
  type: "new_ride";
  pickup: { lat: number; lng: number };
  payload: Record<string, unknown>;
  options?: {
    maxRadiusMeters?: number;
    vehicleTypeId?: string | null;
    rejectedDriverIds?: string[];
  };
};

export type SocketBridgeRideUnavailable = {
  type: "ride_unavailable";
  rideId: string;
};

export type SocketBridgeRequest =
  | SocketBridgeRoomEmit
  | SocketBridgeRoomsEmit
  | SocketBridgeNewRide
  | SocketBridgeRideUnavailable;

const bridgeConfigured = () =>
  Boolean(env.SOCKET_BRIDGE_URL?.trim() && env.SOCKET_BRIDGE_SECRET?.trim());

/** Forward a socket emit to the long-running socket server (Railway/Render/VPS). */
export const forwardSocketBridge = async (body: SocketBridgeRequest): Promise<boolean> => {
  const baseUrl = env.SOCKET_BRIDGE_URL?.trim();
  const secret = env.SOCKET_BRIDGE_SECRET?.trim();
  if (!baseUrl || !secret) {
    return false;
  }

  const url = `${baseUrl.replace(/\/$/, "")}/internal/socket-bridge/emit`;
  try {
    await axios.post(url, body, {
      headers: { "x-socket-bridge-secret": secret },
      timeout: 8000,
    });
    return true;
  } catch (error) {
    logger.warn({ error, bridgeType: body.type }, "Socket bridge forward failed");
    return false;
  }
};

export const isSocketBridgeConfigured = () => bridgeConfigured();
