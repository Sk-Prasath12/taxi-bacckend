import { Types } from "mongoose";
import { HttpError } from "../../utils/http-error";
import { UserModel } from "../users/users.model";
import { VehicleTypeModel } from "../vehicle-type/vehicle-type.model";
import { DriverProfileModel, type DriverProfileDocument } from "./driver-profile.model";
import type { UpsertDriverProfileInput } from "./driver-profile.validation";

function normalizePhone(raw: string | undefined): string | undefined {
  if (raw === undefined) {
    return undefined;
  }
  const compact = raw.replace(/\s/g, "");
  return compact.length > 0 ? compact : undefined;
}

function normalizeAadhaar(raw: string | undefined): string | undefined {
  if (raw === undefined) {
    return undefined;
  }
  const digits = raw.replace(/\s/g, "");
  return digits.length > 0 ? digits : undefined;
}

function isNonEmpty(value: string | null | undefined): boolean {
  return typeof value === "string" && value.trim().length > 0;
}

function isPopulatedDate(value: Date | null | undefined): boolean {
  return value instanceof Date && !Number.isNaN(value.getTime());
}

function getMissingRequiredFields(doc: {
  dob?: Date | null;
  phone?: string | null;
  address?: string | null;
  license_number?: string | null;
  vehicle_reg_number?: string | null;
  vehicle_type_id?: Types.ObjectId | null;
  pan_number?: string | null;
  aadhaar_number?: string | null;
  account_holder_name?: string | null;
  account_number?: string | null;
  ifsc_code?: string | null;
}): string[] {
  const missing: string[] = [];
  if (!isPopulatedDate(doc.dob)) missing.push("dob");
  if (!isNonEmpty(doc.phone)) missing.push("phone");
  if (!isNonEmpty(doc.address)) missing.push("address");
  if (!isNonEmpty(doc.license_number)) missing.push("license_number");
  if (!isNonEmpty(doc.vehicle_reg_number)) missing.push("vehicle_reg_number");
  if (!doc.vehicle_type_id) missing.push("vehicle_type_id");
  if (!isNonEmpty(doc.pan_number)) missing.push("pan_number");
  if (!isNonEmpty(doc.aadhaar_number)) missing.push("aadhaar_number");
  if (!isNonEmpty(doc.account_holder_name)) missing.push("account_holder_name");
  if (!isNonEmpty(doc.account_number)) missing.push("account_number");
  if (!isNonEmpty(doc.ifsc_code)) missing.push("ifsc_code");
  return missing;
}

async function syncProfileToUserDocument(
  userId: string,
  dto: ReturnType<typeof profileToDto>
): Promise<void> {
  const setPayload: Record<string, unknown> = {
    driver_profile: {
      dob: dto.dob,
      phone: dto.phone,
      address: dto.address,
      emergency_contact: dto.emergency_contact,
      license_number: dto.license_number,
      vehicle_reg_number: dto.vehicle_reg_number,
      vehicle_type_id: dto.vehicle_type_id,
      vehicle_model: dto.vehicle_model,
      vehicle_color: dto.vehicle_color,
      pan_number: dto.pan_number,
      aadhaar_number: dto.aadhaar_number,
      voter_id: dto.voter_id,
      account_holder_name: dto.account_holder_name,
      bank_name: dto.bank_name,
      branch_name: dto.branch_name,
      account_number: dto.account_number,
      ifsc_code: dto.ifsc_code,
      account_type: dto.account_type,
      upi_id: dto.upi_id,
      profile_completed: dto.profile_completed,
      updatedAt: dto.updatedAt,
    },
  };
  if (dto.phone) {
    setPayload.phone = dto.phone;
  }

  await UserModel.updateOne({ _id: userId, role: "DRIVER" }, { $set: setPayload });
}

export function profileToDto(doc: DriverProfileDocument) {
  const lean = doc.toObject();
  return {
    id: lean._id.toString(),
    user_id: lean.user_id.toString(),
    dob: lean.dob ?? null,
    phone: lean.phone ?? null,
    address: lean.address ?? null,
    emergency_contact: lean.emergency_contact ?? null,
    license_number: lean.license_number ?? null,
    vehicle_reg_number: lean.vehicle_reg_number ?? null,
    vehicle_type_id: lean.vehicle_type_id ? String(lean.vehicle_type_id) : null,
    vehicle_model: lean.vehicle_model ?? null,
    vehicle_color: lean.vehicle_color ?? null,
    pan_number: lean.pan_number ?? null,
    aadhaar_number: lean.aadhaar_number ?? null,
    voter_id: lean.voter_id ?? null,
    account_holder_name: lean.account_holder_name ?? null,
    bank_name: lean.bank_name ?? null,
    branch_name: lean.branch_name ?? null,
    account_number: lean.account_number ?? null,
    ifsc_code: lean.ifsc_code ?? null,
    account_type: lean.account_type ?? null,
    upi_id: lean.upi_id ?? null,
    profile_completed: lean.profile_completed === true,
    createdAt: lean.createdAt ?? null,
    updatedAt: lean.updatedAt ?? null,
  };
}

async function ensureDriverUser(userId: string): Promise<void> {
  const user = await UserModel.findOne({ _id: userId, role: "DRIVER" }).lean();
  if (!user) {
    throw new HttpError(404, "Driver not found");
  }
}

async function ensureVehicleTypeExists(vehicleTypeId: Types.ObjectId): Promise<void> {
  const exists = await VehicleTypeModel.exists({ _id: vehicleTypeId });
  if (!exists) {
    throw new HttpError(400, "vehicle_type_id does not reference a valid vehicle type");
  }
}

export async function createOrUpdateProfile(
  userId: string,
  payload: UpsertDriverProfileInput
): Promise<ReturnType<typeof profileToDto>> {
  await ensureDriverUser(userId);

  const set: Record<string, unknown> = {};

  if (payload.dob !== undefined) {
    set.dob = payload.dob;
  }
  if (payload.phone !== undefined) {
    const n = normalizePhone(payload.phone);
    set.phone = n ?? null;
  }
  if (payload.address !== undefined) {
    set.address = payload.address ?? null;
  }
  if (payload.emergency_contact !== undefined) {
    set.emergency_contact = payload.emergency_contact ?? null;
  }
  if (payload.license_number !== undefined) {
    set.license_number = payload.license_number ?? null;
  }
  if (payload.vehicle_reg_number !== undefined) {
    set.vehicle_reg_number = payload.vehicle_reg_number ?? null;
  }
  if (payload.vehicle_type_id !== undefined) {
    if (!payload.vehicle_type_id) {
      set.vehicle_type_id = null;
    } else {
      const oid = new Types.ObjectId(payload.vehicle_type_id);
      await ensureVehicleTypeExists(oid);
      set.vehicle_type_id = oid;
    }
  }
  if (payload.vehicle_model !== undefined) {
    set.vehicle_model = payload.vehicle_model ?? null;
  }
  if (payload.vehicle_color !== undefined) {
    set.vehicle_color = payload.vehicle_color ?? null;
  }
  if (payload.pan_number !== undefined) {
    set.pan_number = payload.pan_number ? payload.pan_number.toUpperCase() : null;
  }
  if (payload.aadhaar_number !== undefined) {
    set.aadhaar_number = normalizeAadhaar(payload.aadhaar_number) ?? null;
  }
  if (payload.voter_id !== undefined) {
    set.voter_id = payload.voter_id ?? null;
  }
  if (payload.account_holder_name !== undefined) {
    set.account_holder_name = payload.account_holder_name ?? null;
  }
  if (payload.bank_name !== undefined) {
    set.bank_name = payload.bank_name ?? null;
  }
  if (payload.branch_name !== undefined) {
    set.branch_name = payload.branch_name ?? null;
  }
  if (payload.account_number !== undefined) {
    set.account_number = payload.account_number ?? null;
  }
  if (payload.ifsc_code !== undefined) {
    set.ifsc_code = payload.ifsc_code ? payload.ifsc_code.toUpperCase() : null;
  }
  if (payload.account_type !== undefined) {
    set.account_type = payload.account_type ?? null;
  }
  if (payload.upi_id !== undefined) {
    set.upi_id = payload.upi_id ?? null;
  }

  const userObjectId = new Types.ObjectId(userId);

  const updated = await DriverProfileModel.findOneAndUpdate(
    { user_id: userObjectId },
    { $set: set, $setOnInsert: { user_id: userObjectId, profile_completed: false } },
    { new: true, upsert: true, runValidators: true }
  );

  if (!updated) {
    throw new HttpError(500, "Unable to save driver profile");
  }

  const missing = getMissingRequiredFields(updated);
  const shouldComplete = missing.length === 0;
  if (updated.profile_completed !== shouldComplete) {
    updated.profile_completed = shouldComplete;
    await updated.save();
  }

  const dto = profileToDto(updated);
  await syncProfileToUserDocument(userId, dto);
  return dto;
}

export async function getProfile(userId: string): Promise<ReturnType<typeof profileToDto> | null> {
  const doc = await DriverProfileModel.findOne({ user_id: new Types.ObjectId(userId) });
  if (!doc) {
    return null;
  }
  return profileToDto(doc);
}

export async function completeProfile(userId: string): Promise<ReturnType<typeof profileToDto>> {
  // Kept for backward compatibility. Profile is auto-completed on save when required fields exist.
  await ensureDriverUser(userId);

  const doc = await DriverProfileModel.findOne({ user_id: new Types.ObjectId(userId) });
  if (!doc) {
    throw new HttpError(404, "Driver profile not found. Create your profile first.");
  }

  const missing = getMissingRequiredFields(doc);

  if (missing.length > 0) {
    throw new HttpError(
      400,
      `Profile cannot be marked complete. Missing or invalid required fields: ${missing.join(", ")}`
    );
  }

  if (doc.vehicle_type_id) {
    await ensureVehicleTypeExists(doc.vehicle_type_id as Types.ObjectId);
  }

  doc.profile_completed = true;
  await doc.save();

  const dto = profileToDto(doc);
  await syncProfileToUserDocument(userId, dto);
  return dto;
}

/**
 * Ensures the driver has a persisted profile marked complete.
 * Use before operations that require a fully onboarded driver (e.g. going ONLINE).
 */
export async function validateDriverProfile(userId: string): Promise<void> {
  const doc = await DriverProfileModel.findOne({ user_id: new Types.ObjectId(userId) }).lean();
  if (!doc || doc.profile_completed !== true) {
    throw new HttpError(403, "Driver profile incomplete");
  }
}

/**
 * After admin account approval, allow going online without manual profile/doc steps.
 * Creates a minimal completed profile when missing.
 */
export async function ensureDriverReadyForOnline(userId: string): Promise<void> {
  await ensureDriverUser(userId);

  const user = await UserModel.findOne({ _id: userId, role: "DRIVER" }).lean();
  if (!user) {
    throw new HttpError(404, "Driver not found");
  }

  let doc = await DriverProfileModel.findOne({ user_id: new Types.ObjectId(userId) });
  if (doc?.profile_completed === true) {
    return;
  }

  const defaultVehicleType = await VehicleTypeModel.findOne({ is_active: true })
    .select("_id")
    .lean();

  const patch = {
    dob: doc?.dob ?? new Date("1990-01-01"),
    phone: doc?.phone ?? user.phone ?? "9000000000",
    address: doc?.address ?? "To be updated",
    license_number: doc?.license_number ?? "PENDING",
    vehicle_reg_number: doc?.vehicle_reg_number ?? "PENDING",
    vehicle_type_id: doc?.vehicle_type_id ?? defaultVehicleType?._id ?? null,
    pan_number: doc?.pan_number ?? "PENDING",
    aadhaar_number: doc?.aadhaar_number ?? "000000000000",
    account_holder_name: doc?.account_holder_name ?? user.name,
    account_number: doc?.account_number ?? "0000000000",
    ifsc_code: doc?.ifsc_code ?? "PENDING0000",
    profile_completed: true,
  };

  if (!doc) {
    doc = await DriverProfileModel.create({
      user_id: new Types.ObjectId(userId),
      ...patch,
    });
  } else {
    doc.set(patch);
    await doc.save();
  }

  const dto = profileToDto(doc);
  await syncProfileToUserDocument(userId, dto);
}
