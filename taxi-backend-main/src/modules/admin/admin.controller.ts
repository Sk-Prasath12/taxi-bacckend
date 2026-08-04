import { NextFunction, Request, Response } from "express";
import { successResponse } from "../../utils/api-response";
import { UserModel } from "../users/users.model";

export const adminTestController = (req: Request, res: Response) => {
  return res.status(200).json(
    successResponse("Admin route is accessible", {
      userId: req.authUser?.userId,
      role: req.authUser?.role,
      message: "Admin module base setup is working",
    })
  );
};

export const getActiveDriversController = async (
  _req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const drivers = await UserModel.find({
      role: "DRIVER",
      is_active: true,
      is_blocked: false,
      driver_status: { $in: ["ONLINE", "BUSY"] },
    })
      .select("name email phone driver_status is_active is_blocked blocked_reason created_at")
      .sort({ updated_at: -1, created_at: -1 })
      .lean();

    return res.status(200).json(
      successResponse("Active drivers fetched successfully", {
        total: drivers.length,
        drivers: drivers.map((driver) => ({
          id: String(driver._id),
          name: driver.name,
          email: driver.email,
          phone: driver.phone ?? null,
          status: driver.driver_status ?? "OFFLINE",
          is_active: driver.is_active,
          is_blocked: driver.is_blocked,
          blocked_reason: driver.blocked_reason ?? null,
          joined_at: (driver as { created_at?: Date }).created_at ?? null,
        })),
      })
    );
  } catch (error) {
    return next(error);
  }
};

/** Drivers who completed admin verification (KYC approved). */
export const getVerifiedDriversController = async (
  _req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const drivers = await UserModel.find({
      role: "DRIVER",
      is_driver_verified: true,
      driver_verification_status: "APPROVED",
    })
      .select(
        "name email phone driver_status is_driver_verified driver_verification_status created_at"
      )
      .sort({ updated_at: -1, created_at: -1 })
      .lean();

    return res.status(200).json(
      successResponse("Verified drivers fetched successfully", {
        total: drivers.length,
        drivers: drivers.map((driver) => ({
          id: String(driver._id),
          name: driver.name,
          email: driver.email,
          phone: driver.phone ?? null,
          driver_status: driver.driver_status ?? "OFFLINE",
          is_driver_verified: driver.is_driver_verified === true,
          driver_verification_status: driver.driver_verification_status ?? "PENDING",
          joined_at: (driver as { created_at?: Date }).created_at ?? null,
        })),
      })
    );
  } catch (error) {
    return next(error);
  }
};
