import type { Server } from "socket.io";
import { logger } from "../config/logger";
import {
  emitNewRideToNearbyDrivers,
  emitRideUnavailableToDrivers,
  type NearbyDispatchOptions,
} from "../utils/nearby-drivers.util";
import { forwardSocketBridge, isSocketBridgeConfigured } from "./socket-bridge.client";
import { getIoSafe } from "./socket";

type EmitPayload = Record<string, unknown>;
type NearbyDispatchResult = { targeted: number; broadcastAll: boolean };

const emitLocal = (io: Server, room: string, event: string, payload: EmitPayload) => {
  io.to(room).emit(event, payload);
};

/** Emit to one room — works on Vercel (bridge) or long-running server (local io). */
export const emitToRoom = async (
  room: string,
  event: string,
  payload: EmitPayload
): Promise<void> => {
  const io = getIoSafe();
  if (io) {
    emitLocal(io, room, event, payload);
    return;
  }

  const forwarded = await forwardSocketBridge({ type: "room", room, event, payload });
  if (!forwarded) {
    logger.debug({ room, event }, "Socket emit skipped (no local io, bridge not configured)");
  }
};

export const emitToRooms = async (
  rooms: string[],
  event: string,
  payload: EmitPayload
): Promise<void> => {
  const io = getIoSafe();
  if (io) {
    for (const room of rooms) {
      emitLocal(io, room, event, payload);
    }
    return;
  }

  const forwarded = await forwardSocketBridge({ type: "rooms", rooms, event, payload });
  if (!forwarded) {
    logger.debug({ rooms, event }, "Socket multi-room emit skipped");
  }
};

export const dispatchNewRideToNearbyDrivers = async (
  pickup: { lat: number; lng: number },
  payload: EmitPayload,
  options: NearbyDispatchOptions = {}
): Promise<NearbyDispatchResult> => {
  const io = getIoSafe();
  if (io) {
    return emitNewRideToNearbyDrivers(io, pickup, payload, options);
  }

  const forwarded = await forwardSocketBridge({
    type: "new_ride",
    pickup,
    payload,
    options: {
      maxRadiusMeters: options.maxRadiusMeters,
      vehicleTypeId: options.vehicleTypeId ?? null,
      rejectedDriverIds: (options.rejectedDriverIds ?? []).map(String),
    },
  });
  if (!forwarded) {
    logger.info(
      { ride_id: payload.ride_id },
      "new_ride not pushed via socket — drivers will receive via REST polling"
    );
  }
  return { targeted: 0, broadcastAll: false };
};

export const dispatchRideUnavailableToDrivers = async (rideId: string): Promise<void> => {
  const io = getIoSafe();
  if (io) {
    emitRideUnavailableToDrivers(io, rideId);
    return;
  }

  await forwardSocketBridge({ type: "ride_unavailable", rideId });
};

export const socketRealtimeMode = (): "local" | "bridge" | "polling_only" => {
  if (getIoSafe()) return "local";
  if (isSocketBridgeConfigured()) return "bridge";
  return "polling_only";
};
