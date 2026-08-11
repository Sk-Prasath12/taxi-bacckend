import { NextFunction, Request, Response } from "express";
import {
  changeCustomerPassword,
  getCustomerProfile,
  sendForgotPasswordOtp,
  loginCustomer,
  setForgotPasswordPassword,
  sendRegistrationOtp,
  updateCustomerProfile,
  verifyForgotPasswordOtp,
  setRegistrationPassword,
  verifyRegistrationOtp,
} from "./customer.service";

export const customerRegisterEmailController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const { name, email, phone } = req.body;
    await sendRegistrationOtp(name, email, phone);

    return res.status(200).json({
      success: true,
      message: "OTP sent successfully",
    });
  } catch (error) {
    return next(error);
  }
};

export const customerVerifyOtpController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const { email, otp } = req.body;
    await verifyRegistrationOtp(email, otp);

    return res.status(200).json({
      success: true,
      message: "Email verified successfully",
    });
  } catch (error) {
    return next(error);
  }
};

export const customerSetPasswordController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const { email, password } = req.body;
    const data = await setRegistrationPassword(email, password);

    return res.status(201).json(data);
  } catch (error) {
    return next(error);
  }
};

export const customerLoginController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const { email, password } = req.body;
    const data = await loginCustomer(email, password);

    return res.status(200).json({
      success: true,
      message: "Login successful",
      ...data,
      data,
    });
  } catch (error) {
    return next(error);
  }
};

export const customerGetProfileController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const data = await getCustomerProfile(req.authUser?.userId);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const customerUpdateProfileController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const { name, phone } = req.body;
    const data = await updateCustomerProfile(req.authUser?.userId, name, phone);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const customerForgotPasswordEmailController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const { email } = req.body;
    await sendForgotPasswordOtp(email);
    return res.status(200).json({
      success: true,
      message: "OTP sent successfully",
    });
  } catch (error) {
    return next(error);
  }
};

export const customerForgotPasswordVerifyOtpController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const { email, otp } = req.body;
    await verifyForgotPasswordOtp(email, otp);
    return res.status(200).json({
      success: true,
      message: "OTP verified successfully",
    });
  } catch (error) {
    return next(error);
  }
};

export const customerForgotPasswordSetPasswordController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const { email, password } = req.body;
    const data = await setForgotPasswordPassword(email, password);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const customerChangePasswordController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const { email, oldPassword, newPassword } = req.body;
    const data = await changeCustomerPassword(
      req.authUser?.userId,
      email,
      oldPassword,
      newPassword
    );
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};
