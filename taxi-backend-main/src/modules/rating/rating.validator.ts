import { z } from "zod";

const objectIdRegex = /^[a-fA-F0-9]{24}$/;

export const createRatingSchema = z.object({
  body: z.object({
    ride_id: z.string().regex(objectIdRegex, "Invalid ride id"),
    rating: z.number().min(1).max(5),
    review: z.string().trim().optional(),
  }),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

export const adminRatingsQuerySchema = z.object({
  body: z.object({}).optional(),
  params: z.object({}).optional(),
  query: z.object({
    role: z.enum(["CUSTOMER", "DRIVER"]).optional(),
    rating: z
      .string()
      .regex(/^[1-5]$/, "rating must be between 1 and 5")
      .optional(),
  }),
});

