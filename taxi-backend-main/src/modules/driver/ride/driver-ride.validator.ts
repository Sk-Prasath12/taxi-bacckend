import { z } from "zod";

const objectIdSchema = z.string().regex(/^[a-fA-F0-9]{24}$/, "Invalid ride id");

export const driverRideIdParamSchema = z.object({
  body: z.object({}).optional(),
  params: z.object({
    rideId: objectIdSchema,
  }),
  query: z.object({}),
});

export const verifyRideOtpSchema = z.object({
  body: z.object({
    otp: z.number().int().min(1000, "OTP must be a 4-digit number").max(9999, "OTP must be a 4-digit number"),
  }),
  params: z.object({
    rideId: objectIdSchema,
  }),
  query: z.object({}),
});

export const acceptRideBodySchema = z.object({
  body: z.object({
    ride_id: objectIdSchema,
  }),
  params: z.object({}),
  query: z.object({}),
});

export const dropReachedBodySchema = z.object({
  body: z
    .object({
      fare: z.number().positive().optional(),
      lat: z.number().min(-90).max(90).optional(),
      lng: z.number().min(-180).max(180).optional(),
      actual_distance_km: z.number().min(0).optional(),
      duration_min: z.number().min(0).optional(),
      address: z.string().optional(),
    })
    .optional(),
  params: z.object({
    rideId: objectIdSchema,
  }),
  query: z.object({}),
});

export const updateRideStatusSchema = z.object({
  body: z.object({
    status: z.enum([
      "SEARCHING",
      "ACCEPTED",
      "DRIVER_ARRIVING",
      "ARRIVED",
      "STARTED",
      "COMPLETED",
      "CANCELLED",
    ]),
  }),
  params: z.object({
    rideId: objectIdSchema,
  }),
  query: z.object({}),
});
