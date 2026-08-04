import { isValidObjectId } from "mongoose";
import { z } from "zod";

const PHONE_REGEX = /^\+?[0-9]{10,15}$/;
const IFSC_REGEX = /^[A-Z]{4}0[A-Z0-9]{6}$/i;
const AADHAAR_REGEX = /^\d{12}$/;
const PAN_REGEX = /^[A-Z]{5}[0-9]{4}[A-Z]$/i;

const optionalNonEmptyString = z
  .string()
  .trim()
  .optional()
  .transform((v) => (v === "" ? undefined : v));

const optionalPhone = optionalNonEmptyString.refine(
  (v) => v === undefined || PHONE_REGEX.test(v.replace(/\s/g, "")),
  { message: "phone must be 10–15 digits, optional leading +" }
);

const optionalIfsc = optionalNonEmptyString.refine(
  (v) => v === undefined || IFSC_REGEX.test(v),
  { message: "Invalid IFSC format (e.g. SBIN0001234)" }
);

const optionalAadhaar = optionalNonEmptyString.refine(
  (v) => v === undefined || AADHAAR_REGEX.test(v.replace(/\s/g, "")),
  { message: "aadhaar_number must be exactly 12 digits" }
);

const optionalPan = optionalNonEmptyString.refine(
  (v) => v === undefined || PAN_REGEX.test(v),
  { message: "Invalid PAN format (e.g. ABCDE1234F)" }
);

const optionalObjectIdString = optionalNonEmptyString.refine(
  (v) => v === undefined || isValidObjectId(v),
  { message: "vehicle_type_id must be a valid ObjectId" }
);

const optionalDate = z.preprocess((val) => {
  if (val === undefined || val === null || val === "") {
    return undefined;
  }
  if (val instanceof Date) {
    return val;
  }
  if (typeof val === "string" || typeof val === "number") {
    const d = new Date(val);
    return Number.isNaN(d.getTime()) ? val : d;
  }
  return val;
}, z.date().optional());

export const upsertDriverProfileBodySchema = z.object({
  dob: optionalDate,
  phone: optionalPhone,
  address: optionalNonEmptyString,
  emergency_contact: optionalNonEmptyString,
  license_number: optionalNonEmptyString,
  vehicle_reg_number: optionalNonEmptyString,
  vehicle_type_id: optionalObjectIdString,
  vehicle_model: optionalNonEmptyString,
  vehicle_color: optionalNonEmptyString,
  pan_number: optionalPan,
  aadhaar_number: optionalAadhaar,
  voter_id: optionalNonEmptyString,
  account_holder_name: optionalNonEmptyString,
  bank_name: optionalNonEmptyString,
  branch_name: optionalNonEmptyString,
  account_number: optionalNonEmptyString,
  ifsc_code: optionalIfsc,
  account_type: optionalNonEmptyString,
  upi_id: optionalNonEmptyString,
});

export const upsertDriverProfileSchema = z.object({
  body: upsertDriverProfileBodySchema,
  params: z.object({}),
  query: z.object({}),
});

export const completeDriverProfileSchema = z.object({
  body: z.object({}),
  params: z.object({}),
  query: z.object({}),
});

export type UpsertDriverProfileInput = z.infer<typeof upsertDriverProfileBodySchema>;
