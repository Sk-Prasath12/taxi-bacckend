import { z } from "zod";

const coordinateSchema = z
  .array(z.number().finite())
  .length(2, "Each coordinate must be [lng, lat]");

const coordinatesSchema = z
  .array(coordinateSchema)
  .min(3, "Coordinates must contain at least 3 points")
  .superRefine((coordinates, context) => {
    const normalized = coordinates.map((pair) => [pair[0], pair[1]] as [number, number]);
    const first = normalized[0];
    const last = normalized[normalized.length - 1];

    if (!first || !last) {
      return;
    }

    const isClosed = first[0] === last[0] && first[1] === last[1];
    if (!isClosed) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        message: "Polygon must be closed (first point should match last point)",
      });
    }
  });

export const createOperationalZoneSchema = z.object({
  body: z.object({
    zone_name: z.string().trim().min(1, "zone_name is required"),
    coordinates: coordinatesSchema,
  }),
  params: z.object({}),
  query: z.object({}),
});

export const updateOperationalZoneSchema = z.object({
  body: z
    .object({
      zone_name: z.string().trim().min(1, "zone_name cannot be empty").optional(),
      coordinates: coordinatesSchema.optional(),
    })
    .refine((value) => value.zone_name !== undefined || value.coordinates !== undefined, {
      message: "At least one field (zone_name or coordinates) is required",
    }),
  params: z.object({
    id: z.string().min(1, "id is required"),
  }),
  query: z.object({}),
});

export const toggleOperationalZoneStatusSchema = z.object({
  body: z.object({
    is_active: z.boolean(),
  }),
  params: z.object({
    id: z.string().min(1, "id is required"),
  }),
  query: z.object({}),
});
