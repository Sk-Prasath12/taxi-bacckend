import { NextFunction, Request, Response } from "express";
import { successResponse } from "../../../utils/api-response";
import {
  adminApproveDriverAccount,
  adminApproveDriverByEmail,
  getAdminDriverDetails,
  getAdminDriverRideDetails,
  getAdminDriverRideHistory,
  getAdminDrivers,
  updateAdminDriverBlockStatus,
} from "./admin-driver.service";

export const adminApproveDriverAccountController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const driverId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const data = await adminApproveDriverAccount(driverId);
    return res.status(200).json(successResponse("Driver account approved", data));
  } catch (error) {
    return next(error);
  }
};

export const adminApproveDriverByEmailController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const email = String(req.body?.email ?? "").trim();
    if (!email) {
      return res.status(400).json({ success: false, message: "email is required" });
    }
    const data = await adminApproveDriverByEmail(email);
    return res.status(200).json(successResponse("Driver account approved", data));
  } catch (error) {
    return next(error);
  }
};

export const getAdminDriversController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { page, limit, search, pending_approval } = req.query;
    const pendingApprovalOnly =
      pending_approval === "1" || pending_approval === "true" || pending_approval === "yes";
    const data = await getAdminDrivers(page, limit, search, pendingApprovalOnly);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getAdminDriverDetailsController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const driverId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const data = await getAdminDriverDetails(driverId);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const updateAdminDriverBlockStatusController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const driverId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const { is_blocked, reason } = req.body;
    const data = await updateAdminDriverBlockStatus(driverId, is_blocked, reason);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getAdminDriverRideHistoryController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const driverId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const data = await getAdminDriverRideHistory(driverId);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getAdminDriverRideDetailsController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const driverId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const rideId = Array.isArray(req.params.rideId) ? req.params.rideId[0] : req.params.rideId;
    const data = await getAdminDriverRideDetails(driverId, rideId);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};
