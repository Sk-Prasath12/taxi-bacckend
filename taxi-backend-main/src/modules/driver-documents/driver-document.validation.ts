import { z } from "zod";
import { Types } from "mongoose";
const objectIdParam = z
  .string()
  .min(1)
  .refine((value) => Types.ObjectId.isValid(value), { message: "Invalid id" });

/** Multipart body is file only; document_type is required on the query string. */
export const driverUploadDocumentSchema = z.object({
  body: z.object({}),
  params: z.object({}),
  query: z.object({
    document_type: z.enum(["IDENTITY", "VEHICLE", "BANK", "PERSONAL"], {
      errorMap: () => ({ message: "Invalid or missing document_type query param" }),
    }),
    document_slot: z.string().trim().min(1).max(64).optional(),
  }),
});

export const driverDocumentIdSchema = z.object({
  body: z.object({}),
  params: z.object({
    id: objectIdParam,
  }),
  query: z.object({}),
});

export const adminDriverIdSchema = z.object({
  body: z.object({}),
  params: z.object({
    driverId: objectIdParam,
  }),
  query: z.object({}),
});

export const adminDocumentIdSchema = z.object({
  body: z.object({}),
  params: z.object({
    id: objectIdParam,
  }),
  query: z.object({}),
});

export const adminDocumentStatusSchema = z.object({
  body: z
    .object({
      status: z.enum(["APPROVED", "REJECTED"], {
        errorMap: () => ({ message: "status must be APPROVED or REJECTED" }),
      }),
      reason: z.string().trim().optional(),
    })
    .superRefine((value, ctx) => {
      if (value.status === "REJECTED" && (!value.reason || value.reason.length === 0)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: "reason is required when status is REJECTED",
        });
      }
    }),
  params: z.object({
    id: objectIdParam,
  }),
  query: z.object({}),
});

export const adminFinalApproveSchema = z.object({
  body: z.object({}),
  params: z.object({
    driverId: objectIdParam,
  }),
  query: z.object({}),
});
