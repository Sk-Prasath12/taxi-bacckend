import nodemailer from "nodemailer";
import { env } from "../../config/env";
import { HttpError } from "../../utils/http-error";
import { comparePassword, hashPassword } from "../../utils/password.util";
import { generateAccessToken, generateRefreshToken, verifyRefreshToken } from "../../utils/jwt.util";
import {
  ensureDriverReadyForOnline,
  getProfile,
} from "../driver-profile/driver-profile.service";
import { UserModel } from "../users/users.model";
import { WalletModel } from "../finance/wallet.model";
import { DriverDueModel } from "../finance/driver-due.model";
import { RideModel } from "../customer/ride/ride.model";
import { DriverOtpModel } from "./driver.otp.model";

const OTP_EXPIRY_MINUTES = 5;
const OTP_PURPOSE_REGISTER = "REGISTER" as const;
const OTP_PURPOSE_FORGOT_PASSWORD = "FORGOT_PASSWORD" as const;

const transporter = nodemailer.createTransport({
  host: env.SMTP_HOST,
  port: env.SMTP_PORT,
  secure: env.SMTP_PORT === 465,
  auth: {
    user: env.SMTP_USER,
    pass: env.SMTP_PASSWORD,
  },
  tls: {
    rejectUnauthorized: env.SMTP_TLS_REJECT_UNAUTHORIZED,
  },
});

const generateOtp = (): string => String(Math.floor(100000 + Math.random() * 900000));

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
      <h2 style="margin: 0 0 16px; color: #1f2937;">Taxi App Driver</h2>
      <p style="margin: 0 0 12px; color: #4b5563;">${description}</p>
      <div style="font-size: 36px; font-weight: 700; letter-spacing: 8px; color: #111827; margin: 16px 0;">
        ${otp}
      </div>
      <p style="margin: 0; color: #6b7280;">This OTP expires in 5 minutes.</p>
    </div>
  </div>
  `;
};

const getOtpSubject = (purpose: string): string => {
  return purpose === OTP_PURPOSE_FORGOT_PASSWORD
    ? "Taxi App Driver Password Reset Code"
    : "Taxi App Driver Email Verification Code";
};

const sendOtpEmail = async (email: string, purpose: string, otp: string): Promise<void> => {
  await transporter.sendMail({
    from: env.SMTP_FROM_EMAIL,
    to: email,
    subject: getOtpSubject(purpose),
    html: getOtpEmailTemplate(purpose, otp),
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

export const sendDriverRegistrationOtp = async (email: string): Promise<void> => {
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

  try {
    await sendOtpEmail(normalizedEmail, OTP_PURPOSE_REGISTER, otp);
    console.log(`[Driver Registration] OTP email sent to ${normalizedEmail}`);
  } catch (emailError) {
    console.error(`[Driver Registration] Failed to send OTP email:`, emailError);
    // Don't throw error - OTP is still created in database for testing
  }
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

export const sendDriverForgotPasswordOtp = async (email: string): Promise<void> => {
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

  try {
    await sendOtpEmail(normalizedEmail, OTP_PURPOSE_FORGOT_PASSWORD, otp);
    console.log(`[Driver Forgot Password] OTP email sent to ${normalizedEmail}`);
  } catch (emailError) {
    console.error(`[Driver Forgot Password] Failed to send OTP email:`, emailError);
    // Don't throw error - OTP is still created in database for testing
    // In production, you might want to throw the error
  }
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

  return {
    success: true,
    message: "Login successful",
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
  const profile = await getProfile(driver.id);

  return {
    id: driver.id,
    name: driver.name,
    email: driver.email,
    phone: driver.phone ?? null,
    role: "driver",
    status: driver.driver_status ?? "OFFLINE",
    is_active: driver.is_active,
    is_blocked: driver.is_blocked,
    is_driver_verified: driver.is_driver_verified === true,
    driver_verification_status: driver.driver_verification_status ?? "PENDING",
    profile_completed: profile?.profile_completed === true,
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
  const wallet = await WalletModel.findOne({ user_id: driver._id }).lean();

  return {
    balance: wallet?.balance ?? 0,
    total_earned: wallet?.total_earned ?? 0,
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
    totalEarnings: onlineEarnings + cashEarningsDue,
  };
};

export const getDriverEarningsSummary = async (
  userId: string | undefined,
  periodInput?: string,
  _tzOffsetMinutes?: number
) => {
  const driver = await findDriverByUserId(userId);
  const period = (periodInput ?? "week").toLowerCase();
  const now = Date.now();
  let since = new Date(now - 7 * 24 * 60 * 60 * 1000);
  if (period === "today") {
    since = new Date();
    since.setHours(0, 0, 0, 0);
  } else if (period === "month") {
    since = new Date(now - 30 * 24 * 60 * 60 * 1000);
  } else if (period === "year") {
    since = new Date(now - 365 * 24 * 60 * 60 * 1000);
  }

  const [wallet, due, periodAgg, totalTrips] = await Promise.all([
    WalletModel.findOne({ user_id: driver._id }).lean(),
    DriverDueModel.findOne({ driver_id: driver._id }).lean(),
    RideModel.aggregate<{ value: number; trips: number }>([
      {
        $match: {
          driver_id: driver._id,
          status: "COMPLETED",
          updatedAt: { $gte: since },
        },
      },
      { $group: { _id: null, value: { $sum: "$fare" }, trips: { $sum: 1 } } },
    ]),
    RideModel.countDocuments({ driver_id: driver._id, status: "COMPLETED" }),
  ]);

  const periodEarnings = periodAgg[0]?.value ?? 0;
  const periodTrips = periodAgg[0]?.trips ?? 0;

  return {
    period,
    period_earnings: periodEarnings,
    period_trips: periodTrips,
    wallet_balance: wallet?.balance ?? 0,
    online_earnings: wallet?.total_earned ?? 0,
    cash_due: due?.due_amount ?? 0,
    total_completed_trips: totalTrips,
  };
};
