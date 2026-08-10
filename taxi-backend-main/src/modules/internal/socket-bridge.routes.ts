import { Router } from "express";
import { z } from "zod";
import { env } from "../../config/env";
import { HttpError } from "../../utils/http-error";
import { getIoSafe } from "../../socket/socket";
import {
  emitNewRideToNearbyDrivers,
  emitRideUnavailableToDrivers,
} from "../../utils/nearby-drivers.util";
import { successResponse } from "../../utils/api-response";

const bridgeRouter = Router();

const bridgeSecretGuard = (secretHeader: string | undefined) => {
  const expected = env.SOCKET_BRIDGE_SECRET?.trim();
  if (!expected || secretHeader !== expected) {
    throw new HttpError(401, "Invalid socket bridge secret");
  }
};

const roomSchema = z.object({
  type: z.literal("room"),
  room: z.string().min(1),
  event: z.string().min(1),
  payload: z.record(z.unknown()).default({}),
});

const roomsSchema = z.object({
  type: z.literal("rooms"),
  rooms: z.array(z.string().min(1)).min(1),
  event: z.string().min(1),
  payload: z.record(z.unknown()).default({}),
});

const newRideSchema = z.object({
  type: z.literal("new_ride"),
  pickup: z.object({ lat: z.number(), lng: z.number() }),
  payload: z.record(z.unknown()),
  options: z
    .object({
      maxRadiusMeters: z.number().optional(),
      vehicleTypeId: z.string().nullable().optional(),
      rejectedDriverIds: z.array(z.string()).optional(),
    })
    .optional(),
});

const rideUnavailableSchema = z.object({
  type: z.literal("ride_unavailable"),
  rideId: z.string().min(1),
});

const bridgeBodySchema = z.discriminatedUnion("type", [
  roomSchema,
  roomsSchema,
  newRideSchema,
  rideUnavailableSchema,
]);

bridgeRouter.post("/emit", async (req, res, next) => {
  try {
    bridgeSecretGuard(req.header("x-socket-bridge-secret"));
    const io = getIoSafe();
    if (!io) {
      return res.status(503).json({
        success: false,
        message: "Socket.io not initialized on this host. Deploy server.ts (Railway/Render/VPS).",
      });
    }

    const body = bridgeBodySchema.parse(req.body);

    if (body.type === "room") {
      io.to(body.room).emit(body.event, body.payload);
    } else if (body.type === "rooms") {
      for (const room of body.rooms) {
        io.to(room).emit(body.event, body.payload);
      }
    } else if (body.type === "new_ride") {
      await emitNewRideToNearbyDrivers(io, body.pickup, body.payload, {
        maxRadiusMeters: body.options?.maxRadiusMeters,
        vehicleTypeId: body.options?.vehicleTypeId,
        rejectedDriverIds: body.options?.rejectedDriverIds,
      });
    } else if (body.type === "ride_unavailable") {
      emitRideUnavailableToDrivers(io, body.rideId);
    }

    return res.status(200).json(successResponse("Socket bridge emit applied"));
  } catch (error) {
    return next(error);
  }
});

bridgeRouter.get("/health", (_req, res) => {
  return res.status(200).json(
    successResponse("Socket bridge ready", {
      socket_initialized: Boolean(getIoSafe()),
    })
  );
});

export default bridgeRouter;
