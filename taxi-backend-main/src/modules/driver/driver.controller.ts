import { NextFunction, Request, Response } from "express";
import {
  getDriverCashEarnings,
  getDriverEarningsSummary,
  getDriverWallet,
  getDriverTotalEarnings,
  getDriverProfile,
  loginDriver,
  refreshDriverAccessToken,
  registerDriverAccount,
  sendDriverForgotPasswordOtp,
  sendDriverRegistrationOtp,
  setDriverForgotPasswordPassword,
  setDriverRegistrationPassword,
  updateDriverStatus,
  updateDriverVehicle,
  verifyDriverForgotPasswordOtp,
  verifyDriverRegistrationOtp,
} from "./driver.service";

export const driverRegisterController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { email, password, name, phone } = req.body;
    const data = await registerDriverAccount({ email, password, name, phone });
    return res.status(201).json(data);
  } catch (error) {
    return next(error);
  }
};

export const driverRefreshTokenController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const { refreshToken } = req.body;
    const data = await refreshDriverAccessToken(refreshToken);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const driverRegisterEmailController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const { email } = req.body;
    const result = await sendDriverRegistrationOtp(email);
    return res.status(200).json({
      success: true,
      message: "OTP sent successfully",
      email_sent: result.email_sent,
      otp: result.otp,
    });
  } catch (error) {
    return next(error);
  }
};

export const driverVerifyOtpController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { email, otp } = req.body;
    await verifyDriverRegistrationOtp(email, otp);
    return res.status(200).json({
      success: true,
      message: "Email verified successfully",
    });
  } catch (error) {
    return next(error);
  }
};

export const driverSetPasswordController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const { email, password } = req.body;
    const data = await setDriverRegistrationPassword(email, password);
    return res.status(201).json(data);
  } catch (error) {
    return next(error);
  }
};

export const driverForgotPasswordEmailController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const { email } = req.body;
    const result = await sendDriverForgotPasswordOtp(email);
    return res.status(200).json({
      success: true,
      message: "OTP sent successfully",
      email_sent: result.email_sent,
      otp: result.otp,
    });
  } catch (error) {
    return next(error);
  }
};

export const driverForgotPasswordVerifyOtpController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const { email, otp } = req.body;
    await verifyDriverForgotPasswordOtp(email, otp);
    return res.status(200).json({
      success: true,
      message: "OTP verified successfully",
    });
  } catch (error) {
    return next(error);
  }
};

export const driverForgotPasswordSetPasswordController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const { email, password } = req.body;
    const data = await setDriverForgotPasswordPassword(email, password);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const driverLoginController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { email, password } = req.body;
    const data = await loginDriver(email, password);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const driverGetProfileController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await getDriverProfile(req.authUser?.userId);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const driverUpdateVehicleController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const data = await updateDriverVehicle(req.authUser?.userId, req.body ?? {});
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const driverUpdateStatusController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { status } = req.body;
    const data = await updateDriverStatus(req.authUser?.userId, status);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const driverGetWalletController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await getDriverWallet(req.authUser?.userId);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const driverGetCashEarningsController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await getDriverCashEarnings(req.authUser?.userId);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const driverGetEarningsSummaryController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const period = typeof req.query.period === "string" ? req.query.period : undefined;
    const tzRaw = req.query.tz_offset;
    const tz =
      typeof tzRaw === "string" ? Number(tzRaw) : typeof tzRaw === "number" ? tzRaw : undefined;
    const data = await getDriverEarningsSummary(req.authUser?.userId, period, tz);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const driverGetTotalEarningsController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await getDriverTotalEarnings(req.authUser?.userId);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};
