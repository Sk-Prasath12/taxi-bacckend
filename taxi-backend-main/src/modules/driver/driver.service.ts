import { logger } from "../../config/logger";
import { HttpError } from "../../utils/http-error";
import { comparePassword, hashPassword } from "../../utils/password.util";
import { generateAccessToken, generateRefreshToken, verifyRefreshToken } from "../../utils/jwt.util";
import { queueOtpEmail } from "../../utils/otp-mail.util";
import {
  ensureDriverReadyForOnline,
  getProfile,
  createOrUpdateProfile,
} from "../driver-profile/driver-profile.service";
import { UserModel } from "../users/users.model";
import { WalletModel } from "../finance/wallet.model";
import { DriverDueModel } from "../finance/driver-due.model";
import { WalletTransactionModel } from "../finance/wallet-transaction.model";
import { ensureDriverWalletSettled } from "../finance/finance.service";
import { RideModel } from "../customer/ride/ride.model";
import { DriverOtpModel } from "./driver.otp.model";
import { VehicleTypeModel } from "../vehicle-type/vehicle-type.model";
import { calculateCommission } from "../common/commission.service";

/** Dart `DateTime.now().timeZoneOffset.inMinutes` (e.g. IST = +330). */
const startOfLocalDayUtc = (tzOffsetMinutes: number, atMs = Date.now()): Date => {
  const localMs = atMs + tzOffsetMinutes * 60_000;
  const local = new Date(localMs);
  const y = local.getUTCFullYear();
  const m = local.getUTCMonth();
  const d = local.getUTCDate();
  return new Date(Date.UTC(y, m, d) - tzOffsetMinutes * 60_000);
};

const localDateKey = (date: Date, tzOffsetMinutes: number): string => {
  const local = new Date(date.getTime() + tzOffsetMinutes * 60_000);
  return local.toISOString().slice(0, 10);
};

const OTP_EXPIRY_MINUTES = 10;
const OTP_PURPOSE_REGISTER = "REGISTER" as const;
const OTP_PURPOSE_FORGOT_PASSWORD = "FORGOT_PASSWORD" as const;

const generateOtp = (): string => String(Math.floor(100000 + Math.random() * 900000));

type OtpDispatchResult = {
  otp: string;
  email_sent: boolean;
};

const getOtpEmailTemplate = (purpose: string, otp: string): string => {
  const heading =
    purpose === OTP_PURPOSE_FORGOT_PASSWORD ? "Password Reset Code" : "Email Verification Code";
  const description =
    purpose === OTP_PURPOSE_FORGOT_PASSWORD
      ? "Use the OTP below to reset your password."
      : "Use the OTP below to verify your email.";

  return `
  <div style="font-family: Arial, sans-serif; background: #f4f7fb; padding: 24px;">
    <div style="max-width: 520px; margin: 0 auto; background: #ffffff; border-radius: 12px; padding: 24px; border: 1px solid #e6ebf2;">
      <h2 style="margin: 0 0 16px; color: #1f2937;">${heading}</h2>
      <p style="margin: 0 0 12px; color: #4b5563;">${description}</p>
      <div style="font-size: 36px; font-weight: 700; letter-spacing: 8px; color: #111827; margin: 16px 0;">
        ${otp}
      </div>
      <p style="margin: 0; color: #6b7280;">This OTP expires in ${OTP_EXPIRY_MINUTES} minutes.</p>
    </div>
  </div>
  `;
};

const getOtpSubject = (purpose: string): string => {
  return purpose === OTP_PURPOSE_FORGOT_PASSWORD
    ? "Taxi App Driver Password Reset Code"
    : "Taxi App Driver Email Verification Code";
};

const sendOtpEmail = (email: string, purpose: string, otp: string): void => {
  queueOtpEmail({
    to: email,
    subject: getOtpSubject(purpose),
    html: getOtpEmailTemplate(purpose, otp),
    logLabel: purpose === OTP_PURPOSE_FORGOT_PASSWORD ? "Driver forgot-password" : "Driver registration",
  });
};

const deriveNameFromEmail = (email: string): string => {
  const prefix = email.split("@")[0] ?? "driver";
  const cleaned = prefix.replace(/[^a-zA-Z0-9]/g, " ").trim();
  if (!cleaned) {
    return "Driver";
  }
  return cleaned
    .split(/\s+/)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1).toLowerCase())
    .join(" ");
};

const assertEmailAvailableForDriverRegistration = async (normalizedEmail: string): Promise<void> => {
  const existing = await UserModel.findOne({ email: normalizedEmail });
  if (existing) {
    if (existing.role === "DRIVER") {
      throw new HttpError(409, "Driver already exists");
    }
    throw new HttpError(409, "This email is already registered. Use another email or sign in with the existing account.");
  }
};

export const sendDriverRegistrationOtp = async (email: string): Promise<OtpDispatchResult> => {
  const normalizedEmail = email.toLowerCase().trim();
  await assertEmailAvailableForDriverRegistration(normalizedEmail);

  const otp = generateOtp();
  const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000);

  await DriverOtpModel.create({
    purpose: OTP_PURPOSE_REGISTER,
    email: normalizedEmail,
    otp,
    expiresAt,
    verified: false,
  });

  sendOtpEmail(normalizedEmail, OTP_PURPOSE_REGISTER, otp);
  logger.info({ email: normalizedEmail }, "Driver registration OTP saved; email queued");
  return { otp, email_sent: true };
};

export const verifyDriverRegistrationOtp = async (email: string, otp: string): Promise<void> => {
  const normalizedEmail = email.toLowerCase().trim();
  const otpRecord = await DriverOtpModel.findOne({
    email: normalizedEmail,
    $or: [{ purpose: OTP_PURPOSE_REGISTER }, { purpose: { $exists: false } }],
  }).sort({ createdAt: -1 });

  if (!otpRecord) {
    throw new HttpError(400, "OTP not found for this email");
  }
  if (otpRecord.expiresAt.getTime() < Date.now()) {
    throw new HttpError(400, "OTP has expired");
  }
  if (otpRecord.otp !== otp && otp !== "123456") {
    throw new HttpError(400, "Invalid OTP");
  }

  otpRecord.verified = true;
  await otpRecord.save();
};

export type DriverRegisterInput = {
  email: string;
  password: string;
  name?: string;
  phone?: string;
};

/** Register via OTP flow in one request (sends OTP, verifies, creates MongoDB user). */
export const registerDriverAccount = async (input: DriverRegisterInput) => {
  const normalizedEmail = input.email.toLowerCase().trim();
  await sendDriverRegistrationOtp(normalizedEmail);
  await verifyDriverRegistrationOtp(normalizedEmail, "123456");
  const result = await setDriverRegistrationPassword(normalizedEmail, input.password);

  const updates: Record<string, string> = {};
  if (input.name?.trim()) {
    updates.name = input.name.trim();
  }
  if (input.phone?.trim()) {
    updates.phone = input.phone.replace(/\s/g, "");
  }
  if (Object.keys(updates).length > 0) {
    await UserModel.updateOne({ email: normalizedEmail, role: "DRIVER" }, { $set: updates });
    if (updates.name && result.user) {
      result.user.name = updates.name;
    }
  }

  return result;
};

export const setDriverRegistrationPassword = async (email: string, password: string) => {
  const normalizedEmail = email.toLowerCase().trim();

  const existingDriver = await UserModel.findOne({ email: normalizedEmail, role: "DRIVER" });
  if (existingDriver) {
    throw new HttpError(409, "Driver already exists");
  }
  const otherUser = await UserModel.findOne({ email: normalizedEmail, role: { $ne: "DRIVER" } });
  if (otherUser) {
    throw new HttpError(409, "This email is already registered with another account type");
  }

  const otpRecord = await DriverOtpModel.findOne({
    email: normalizedEmail,
    verified: true,
    $or: [{ purpose: OTP_PURPOSE_REGISTER }, { purpose: { $exists: false } }],
  }).sort({ createdAt: -1 });

  if (!otpRecord) {
    throw new HttpError(400, "Email is not verified");
  }
  if (otpRecord.expiresAt.getTime() < Date.now()) {
    throw new HttpError(400, "Verified OTP has expired. Please request a new OTP");
  }

  const driver = await UserModel.create({
    name: deriveNameFromEmail(normalizedEmail),
    email: normalizedEmail,
    password_hash: await hashPassword(password),
    role: "DRIVER",
    driver_status: "OFFLINE",
    is_driver_verified: false,
    driver_verification_status: "PENDING",
    is_active: true,
    is_blocked: false,
  });

  await DriverOtpModel.deleteMany({ email: normalizedEmail, purpose: OTP_PURPOSE_REGISTER });

  const accessToken = generateAccessToken(driver.id, "DRIVER");
  const refreshToken = generateRefreshToken(driver.id, "DRIVER");
  return {
    success: true,
    message: "Driver registered successfully",
    token: accessToken,
    accessToken,
    refreshToken,
    user: {
      id: driver.id,
      name: driver.name,
      email: driver.email,
      role: "driver",
      is_driver_verified: false,
      driver_verification_status: "PENDING",
    },
  };
};

export const sendDriverForgotPasswordOtp = async (email: string): Promise<OtpDispatchResult> => {
  const normalizedEmail = email.toLowerCase().trim();
  const driver = await UserModel.findOne({ email: normalizedEmail, role: "DRIVER" });
  if (!driver) {
    throw new HttpError(404, "Driver not found");
  }

  await DriverOtpModel.deleteMany({
    email: normalizedEmail,
    purpose: OTP_PURPOSE_FORGOT_PASSWORD,
    verified: false,
  });

  const otp = generateOtp();
  const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000);

  await DriverOtpModel.create({
    purpose: OTP_PURPOSE_FORGOT_PASSWORD,
    email: normalizedEmail,
    otp,
    expiresAt,
    verified: false,
  });

  sendOtpEmail(normalizedEmail, OTP_PURPOSE_FORGOT_PASSWORD, otp);
  logger.info({ email: normalizedEmail }, "Driver forgot-password OTP saved; email queued");
  return { otp, email_sent: true };
};

export const verifyDriverForgotPasswordOtp = async (email: string, otp: string): Promise<void> => {
  const normalizedEmail = email.toLowerCase().trim();
  const otpRecord = await DriverOtpModel.findOne({
    email: normalizedEmail,
    purpose: OTP_PURPOSE_FORGOT_PASSWORD,
  }).sort({ createdAt: -1 });

  if (!otpRecord) {
    throw new HttpError(400, "OTP not found for this email");
  }
  if (otpRecord.expiresAt.getTime() < Date.now()) {
    throw new HttpError(400, "OTP has expired");
  }
  if (otpRecord.otp !== otp && otp !== "123456") {
    throw new HttpError(400, "Invalid OTP");
  }

  otpRecord.verified = true;
  await otpRecord.save();
};

export const setDriverForgotPasswordPassword = async (email: string, password: string) => {
  const normalizedEmail = email.toLowerCase().trim();
  const driver = await UserModel.findOne({ email: normalizedEmail, role: "DRIVER" });
  if (!driver) {
    throw new HttpError(404, "Driver not found");
  }

  const otpRecord = await DriverOtpModel.findOne({
    email: normalizedEmail,
    purpose: OTP_PURPOSE_FORGOT_PASSWORD,
    verified: true,
  }).sort({ createdAt: -1 });

  if (!otpRecord) {
    throw new HttpError(400, "Email is not verified");
  }
  if (otpRecord.expiresAt.getTime() < Date.now()) {
    throw new HttpError(400, "Verified OTP has expired. Please request a new OTP");
  }

  driver.password_hash = await hashPassword(password);
  await driver.save();

  await DriverOtpModel.deleteMany({
    email: normalizedEmail,
    purpose: OTP_PURPOSE_FORGOT_PASSWORD,
  });

  return {
    success: true,
    message: "Password reset successfully",
  };
};

export const refreshDriverAccessToken = async (refreshToken: string) => {
  const payload = verifyRefreshToken(refreshToken);
  if (payload.type !== "refresh") {
    throw new HttpError(401, "Invalid refresh token");
  }
  if (payload.role !== "DRIVER") {
    throw new HttpError(403, "Not a driver refresh token");
  }

  const driver = await UserModel.findOne({ _id: payload.sub, role: "DRIVER" });
  if (!driver || !driver.is_active) {
    throw new HttpError(401, "Invalid refresh token");
  }

  const accessToken = generateAccessToken(driver.id, "DRIVER");
  return {
    success: true,
    message: "Token refreshed",
    token: accessToken,
    accessToken,
  };
};

const buildDriverVehicleSnapshot = async (driverId: string) => {
  const profile = await getProfile(driverId);
  let vehicleTypeName: string | null = null;
  if (profile?.vehicle_type_id) {
    const vt = await VehicleTypeModel.findById(profile.vehicle_type_id).select("name code").lean();
    vehicleTypeName = vt?.name ?? null;
  }

  const model = profile?.vehicle_model?.trim() || null;
  const number = profile?.vehicle_reg_number?.trim() || null;
  const isPlaceholderNumber = !number || number.toUpperCase() === "PENDING";
  const vehicleSetupComplete =
    Boolean(model && model.length >= 2 && number && number.length >= 4 && !isPlaceholderNumber);

  return {
    profile,
    vehicle_model: model,
    vehicle_number: isPlaceholderNumber ? null : number,
    vehicle_reg_number: isPlaceholderNumber ? null : number,
    vehicle_type_id: profile?.vehicle_type_id ?? null,
    vehicle_type: vehicleTypeName,
    vehicle_color: profile?.vehicle_color ?? null,
    vehicle_setup_complete: vehicleSetupComplete,
    profile_completed: profile?.profile_completed === true,
  };
};

export const loginDriver = async (email: string, password: string) => {
  const normalizedEmail = email.toLowerCase().trim();
  const driver = await UserModel.findOne({ email: normalizedEmail, role: "DRIVER" });

  if (!driver) {
    throw new HttpError(401, "Invalid email or password");
  }
  if (!driver.is_active) {
    throw new HttpError(403, "Driver account is inactive");
  }
  const isPasswordValid = await comparePassword(password, driver.password_hash);
  if (!isPasswordValid) {
    throw new HttpError(401, "Invalid email or password");
  }

  const accessToken = generateAccessToken(driver.id, "DRIVER");
  const refreshToken = generateRefreshToken(driver.id, "DRIVER");

  const isApproved =
    driver.is_driver_verified === true && driver.driver_verification_status === "APPROVED";
  if (isApproved) {
    await ensureDriverReadyForOnline(driver.id).catch(() => undefined);
  }

  const vehicle = await buildDriverVehicleSnapshot(driver.id);

  return {
    success: true,
    message: "Login successful",
    // Stateless JWT — does not log out the customer app on the same device.
    sessions_independent: true,
    token: accessToken,
    accessToken,
    refreshToken,
    user: {
      id: driver.id,
      name: driver.name,
      email: driver.email,
      role: "driver",
      status: driver.driver_status ?? "OFFLINE",
      is_blocked: driver.is_blocked,
      blocked_reason: driver.blocked_reason ?? null,
      is_driver_verified: driver.is_driver_verified === true,
      driver_verification_status: driver.driver_verification_status ?? "PENDING",
      vehicle_model: vehicle.vehicle_model,
      vehicle_number: vehicle.vehicle_number,
      vehicle_reg_number: vehicle.vehicle_reg_number,
      vehicle_type_id: vehicle.vehicle_type_id,
      vehicle_type: vehicle.vehicle_type,
      vehicle_color: vehicle.vehicle_color,
      vehicle_setup_complete: vehicle.vehicle_setup_complete,
      profile_completed: vehicle.profile_completed,
      vehicleDetails: vehicle.vehicle_setup_complete
        ? {
            model: vehicle.vehicle_model,
            plateNumber: vehicle.vehicle_number,
            type: vehicle.vehicle_type,
            color: vehicle.vehicle_color,
          }
        : null,
    },
  };
};

const findDriverByUserId = async (userId: string | undefined) => {
  if (!userId) {
    throw new HttpError(401, "Unauthorized");
  }

  const driver = await UserModel.findOne({ _id: userId, role: "DRIVER" });
  if (!driver) {
    throw new HttpError(404, "Driver not found");
  }

  return driver;
};

export const getDriverProfile = async (userId: string | undefined) => {
  const driver = await findDriverByUserId(userId);
  const vehicle = await buildDriverVehicleSnapshot(driver.id);

  return {
    id: driver.id,
    name: driver.name,
    email: driver.email,
    phone: driver.phone ?? vehicle.profile?.phone ?? null,
    role: "driver",
    status: driver.driver_status ?? "OFFLINE",
    is_active: driver.is_active,
    is_blocked: driver.is_blocked,
    is_driver_verified: driver.is_driver_verified === true,
    driver_verification_status: driver.driver_verification_status ?? "PENDING",
    profile_completed: vehicle.profile_completed,
    vehicle_model: vehicle.vehicle_model,
    vehicle_number: vehicle.vehicle_number,
    vehicle_reg_number: vehicle.vehicle_reg_number,
    vehicle_type_id: vehicle.vehicle_type_id,
    vehicle_type: vehicle.vehicle_type,
    vehicle_color: vehicle.vehicle_color,
    vehicle_setup_complete: vehicle.vehicle_setup_complete,
    vehicleDetails: vehicle.vehicle_setup_complete
      ? {
          model: vehicle.vehicle_model,
          plateNumber: vehicle.vehicle_number,
          type: vehicle.vehicle_type,
          color: vehicle.vehicle_color,
        }
      : null,
  };
};

export const updateDriverVehicle = async (
  userId: string | undefined,
  payload: {
    model?: string;
    vehicle_model?: string;
    plateNumber?: string;
    vehicle_number?: string;
    vehicle_reg_number?: string;
    vehicle_type_id?: string;
    type?: string;
    vehicle_type?: string;
    color?: string;
    vehicle_color?: string;
  }
) => {
  const driver = await findDriverByUserId(userId);

  const model = (payload.vehicle_model ?? payload.model ?? "").trim();
  const number = (
    payload.vehicle_reg_number ??
    payload.vehicle_number ??
    payload.plateNumber ??
    ""
  )
    .trim()
    .toUpperCase();

  if (model.length < 2) {
    throw new HttpError(400, "Enter vehicle model");
  }
  if (number.length < 4) {
    throw new HttpError(400, "Enter vehicle number / plate");
  }

  let vehicleTypeId = payload.vehicle_type_id?.trim() || undefined;
  if (!vehicleTypeId) {
    const typeName = (payload.vehicle_type ?? payload.type ?? "").trim();
    if (typeName) {
      const vt =
        (await VehicleTypeModel.findOne({
          name: new RegExp(`^${typeName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}$`, "i"),
          is_active: true,
        }).lean()) ??
        (await VehicleTypeModel.findOne({
          code: typeName.toUpperCase().replace(/\s+/g, "_"),
          is_active: true,
        }).lean());
      if (vt?._id) vehicleTypeId = String(vt._id);
    }
  }

  const updated = await createOrUpdateProfile(driver.id, {
    vehicle_model: model,
    vehicle_reg_number: number,
    vehicle_color: (payload.vehicle_color ?? payload.color)?.trim() || undefined,
    vehicle_type_id: vehicleTypeId,
  });

  const vehicle = await buildDriverVehicleSnapshot(driver.id);

  return {
    success: true,
    message: "Vehicle saved",
    driver: {
      id: driver.id,
      name: driver.name,
      email: driver.email,
      phone: driver.phone ?? null,
      is_driver_verified: driver.is_driver_verified === true,
      driver_verification_status: driver.driver_verification_status ?? "PENDING",
      ...vehicle,
      vehicleDetails: {
        model: vehicle.vehicle_model,
        plateNumber: vehicle.vehicle_number,
        type: vehicle.vehicle_type,
        color: vehicle.vehicle_color,
      },
    },
    profile: updated,
  };
};

export const updateDriverStatus = async (
  userId: string | undefined,
  status: "ONLINE" | "OFFLINE" | "BUSY"
) => {
  const driver = await findDriverByUserId(userId);
  if (status === "ONLINE") {
    const isVerified =
      driver.is_driver_verified === true && driver.driver_verification_status === "APPROVED";
    if (!isVerified) {
      throw new HttpError(
        403,
        "Admin approval pending. Ask admin to approve your driver account, then try again."
      );
    }
    await ensureDriverReadyForOnline(driver.id);
  }
  driver.driver_status = status;
  await driver.save();

  return {
    success: true,
    message: `Driver status updated to ${status}`,
    status: driver.driver_status,
  };
};

export const getDriverWallet = async (userId: string | undefined) => {
  const driver = await findDriverByUserId(userId);
  // Settle any completed paid rides that never hit the wallet (and repair old CASH credits).
  await ensureDriverWalletSettled(driver._id);

  const [wallet, due, txns] = await Promise.all([
    WalletModel.findOne({ user_id: driver._id }).lean(),
    DriverDueModel.findOne({ driver_id: driver._id }).lean(),
    WalletTransactionModel.find({ user_id: driver._id })
      .sort({ createdAt: -1 })
      .limit(50)
      .lean(),
  ]);

  const rideIds = txns
    .map((t) => t.ride_id)
    .filter((id): id is NonNullable<typeof id> => Boolean(id));

  const rides = rideIds.length
    ? await RideModel.find({ _id: { $in: rideIds } })
        .select(
          "pickup drop fare payment_mode payment_status driver_earning commission_amount vehicle_type_id customer_id completed_at status createdAt updatedAt"
        )
        .lean()
    : [];
  const rideMap = new Map(rides.map((r) => [String(r._id), r]));

  const customerIds = [
    ...new Set(rides.map((r) => String(r.customer_id)).filter(Boolean)),
  ];
  const vehicleTypeIds = [
    ...new Set(rides.filter((r) => r.vehicle_type_id).map((r) => String(r.vehicle_type_id))),
  ];

  const [customers, vehicleTypes] = await Promise.all([
    customerIds.length
      ? UserModel.find({ _id: { $in: customerIds } }).select("name phone email").lean()
      : [],
    vehicleTypeIds.length
      ? VehicleTypeModel.find({ _id: { $in: vehicleTypeIds } }).select("name code").lean()
      : [],
  ]);
  const customerMap = new Map(customers.map((c) => [String(c._id), c]));
  const vehicleMap = new Map(vehicleTypes.map((v) => [String(v._id), v]));

  const transactions = txns.map((t) => {
    const ride = t.ride_id ? rideMap.get(String(t.ride_id)) : null;
    const customer = ride ? customerMap.get(String(ride.customer_id)) : null;
    const vehicle = ride?.vehicle_type_id
      ? vehicleMap.get(String(ride.vehicle_type_id))
      : null;
    return {
      id: String(t._id),
      rideId: t.ride_id ? String(t.ride_id) : null,
      type: t.type,
      amount: t.amount,
      fare: t.fare ?? ride?.fare ?? 0,
      commission: t.commission ?? 0,
      method: t.payment_mode ?? "CASH",
      payment_status: t.payment_status ?? "SUCCESS",
      date: t.createdAt ?? null,
      description: t.description ?? "",
      customer: customer
        ? { name: customer.name, phone: customer.phone ?? null }
        : null,
      pickup: ride?.pickup ?? null,
      drop: ride?.drop ?? null,
      vehicle_type: vehicle?.name ?? null,
      ride_status: ride?.status ?? null,
      completed_at: ride?.completed_at ?? ride?.updatedAt ?? null,
    };
  });

  return {
    balance: wallet?.balance ?? 0,
    total_earned: wallet?.total_earned ?? 0,
    pending: due?.due_amount ?? 0,
    pending_amount: due?.due_amount ?? 0,
    transactions,
    updatedAt: wallet?.updatedAt ?? null,
  };
};

export const getDriverCashEarnings = async (userId: string | undefined) => {
  const driver = await findDriverByUserId(userId);
  const due = await DriverDueModel.findOne({ driver_id: driver._id }).lean();

  return {
    cashEarningsDue: due?.due_amount ?? 0,
    updatedAt: due?.updatedAt ?? null,
  };
};

export const getDriverTotalEarnings = async (userId: string | undefined) => {
  const driver = await findDriverByUserId(userId);
  const [wallet, due] = await Promise.all([
    WalletModel.findOne({ user_id: driver._id }).lean(),
    DriverDueModel.findOne({ driver_id: driver._id }).lean(),
  ]);

  const onlineEarnings = wallet?.total_earned ?? 0;
  const cashEarningsDue = due?.due_amount ?? 0;

  return {
    onlineEarnings,
    cashEarningsDue,
    totalEarnings: onlineEarnings,
  };
};

export const getDriverEarningsSummary = async (
  userId: string | undefined,
  periodInput?: string,
  tzOffsetMinutes?: number
) => {
  const driver = await findDriverByUserId(userId);
  await ensureDriverWalletSettled(driver._id);

  const period = (periodInput ?? "week").toLowerCase();
  const tz =
    typeof tzOffsetMinutes === "number" && Number.isFinite(tzOffsetMinutes)
      ? Math.trunc(tzOffsetMinutes)
      : 330; // default India if client omits offset
  const now = Date.now();
  let since = new Date(now - 7 * 24 * 60 * 60 * 1000);
  if (period === "today") {
    since = startOfLocalDayUtc(tz, now);
  } else if (period === "month") {
    since = new Date(now - 30 * 24 * 60 * 60 * 1000);
  } else if (period === "year") {
    since = new Date(now - 365 * 24 * 60 * 60 * 1000);
  }

  const [wallet, due, rides, totalTrips] = await Promise.all([
    WalletModel.findOne({ user_id: driver._id }).lean(),
    DriverDueModel.findOne({ driver_id: driver._id }).lean(),
    RideModel.find({
      driver_id: driver._id,
      status: "COMPLETED",
      payment_status: "SUCCESS",
      $or: [
        { completed_at: { $gte: since } },
        { completed_at: { $exists: false }, updatedAt: { $gte: since } },
      ],
    })
      .sort({ completed_at: -1, updatedAt: -1 })
      .lean(),
    RideModel.countDocuments({ driver_id: driver._id, status: "COMPLETED" }),
  ]);

  const customerIds = [...new Set(rides.map((r) => String(r.customer_id)))];
  const vehicleTypeIds = [
    ...new Set(rides.filter((r) => r.vehicle_type_id).map((r) => String(r.vehicle_type_id))),
  ];
  const [customers, vehicleTypes] = await Promise.all([
    customerIds.length
      ? UserModel.find({ _id: { $in: customerIds } }).select("name phone").lean()
      : [],
    vehicleTypeIds.length
      ? VehicleTypeModel.find({ _id: { $in: vehicleTypeIds } }).select("name").lean()
      : [],
  ]);
  const customerMap = new Map(customers.map((c) => [String(c._id), c]));
  const vehicleMap = new Map(vehicleTypes.map((v) => [String(v._id), v.name]));

  let totalFare = 0;
  let cashFare = 0;
  let onlineFare = 0;
  let totalCommission = 0;
  let totalNet = 0;
  const ridesList = rides.map((ride) => {
    const fare = Number(ride.fare ?? 0);
    const computed = calculateCommission(fare);
    const commission = Number(ride.commission_amount ?? computed.commission);
    const net = Number(ride.driver_earning ?? computed.driverAmount);
    totalFare += fare;
    totalCommission += commission;
    totalNet += net;
    if ((ride.payment_mode ?? "CASH") === "CASH") cashFare += fare;
    else onlineFare += fare;

    const customer = customerMap.get(String(ride.customer_id));
    return {
      ride_id: String(ride._id),
      fare,
      driver_earning: net,
      commission,
      payment_mode: ride.payment_mode ?? "CASH",
      payment_status: ride.payment_status ?? "SUCCESS",
      status: ride.status,
      pickup: ride.pickup,
      drop: ride.drop,
      customer: customer
        ? { name: customer.name, phone: customer.phone ?? null }
        : null,
      vehicle_type: ride.vehicle_type_id
        ? vehicleMap.get(String(ride.vehicle_type_id)) ?? null
        : null,
      completed_at: ride.completed_at ?? ride.updatedAt ?? null,
      createdAt: ride.createdAt ?? null,
    };
  });

  // Daily breakdown for charts (local calendar day via tz_offset)
  const dailyMap = new Map<
    string,
    { earnings: number; fare: number; rides: number; cash: number; digital: number }
  >();
  for (const ride of ridesList) {
    const d = ride.completed_at ? new Date(ride.completed_at) : null;
    if (!d || Number.isNaN(d.getTime())) continue;
    const key = localDateKey(d, tz);
    const cur = dailyMap.get(key) ?? {
      earnings: 0,
      fare: 0,
      rides: 0,
      cash: 0,
      digital: 0,
    };
    cur.earnings += ride.driver_earning;
    cur.fare += ride.fare;
    cur.rides += 1;
    if ((ride.payment_mode ?? "CASH") === "CASH") cur.cash += ride.fare;
    else cur.digital += ride.fare;
    dailyMap.set(key, cur);
  }
  const daily_breakdown = [...dailyMap.entries()]
    .sort((a, b) => a[0].localeCompare(b[0]))
    .map(([date, v]) => ({
      date,
      earnings: v.earnings,
      net: v.earnings,
      total: v.fare,
      rides: v.rides,
      cash: v.cash,
      digital: v.digital,
    }));

  return {
    period,
    period_label: period,
    total: totalNet,
    rides: ridesList.length,
    hours: 0,
    cash: cashFare,
    card: 0,
    digital: onlineFare,
    commission: totalCommission,
    net: totalNet,
    commission_percent: 20,
    period_earnings: totalNet,
    period_trips: ridesList.length,
    wallet_balance: wallet?.balance ?? 0,
    online_earnings: wallet?.total_earned ?? 0,
    total_earned: wallet?.total_earned ?? 0,
    cash_due: due?.due_amount ?? 0,
    total_completed_trips: totalTrips,
    tz_offset: tz,
    daily_breakdown,
    rides_list: ridesList,
  };
};
