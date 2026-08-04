import { z } from "zod";

const objectIdSchema = z.string().regex(/^[a-fA-F0-9]{24}$/, "Invalid ride id");
const vehicleTypeIdSchema = z.string().regex(/^[a-fA-F0-9]{24}$/, "Invalid vehicle type id");

export const requestRideSchema = z.object({
  body: z.object({
    pickup_lat: z.number(),
    pickup_lng: z.number(),
    pickup_address: z.string().trim().optional(),
    drop_lat: z.number(),
    drop_lng: z.number(),
    drop_address: z.string().trim().optional(),
    vehicle_type_id: vehicleTypeIdSchema,
    payment_mode: z.enum(["ONLINE", "CASH"]).optional(),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const confirmRideSchema = z.object({
  body: z.object({
    ride_id: objectIdSchema,
    payment_mode: z.enum(["ONLINE", "CASH"]).optional(),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const rideIdParamSchema = z.object({
  body: z.object({}).optional(),
  params: z.object({
    rideId: objectIdSchema,
  }),
  query: z.object({}),
});
