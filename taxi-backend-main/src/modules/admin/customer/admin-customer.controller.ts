import { NextFunction, Request, Response } from "express";
import { successResponse } from "../../../utils/api-response";
import {
  adminApproveCustomerAccount,
  adminApproveCustomerByEmail,
  getAdminCustomerDetails,
  getAdminCustomerRideHistory,
  getAdminCustomers,
  updateAdminCustomerBlockStatus,
} from "./admin-customer.service";

export const adminApproveCustomerAccountController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const customerId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const data = await adminApproveCustomerAccount(customerId);
    return res.status(200).json(successResponse("Customer approved", data));
  } catch (error) {
    return next(error);
  }
};

export const adminApproveCustomerByEmailController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const email = String(req.body?.email ?? "").trim();
    if (!email) {
      return res.status(400).json({ success: false, message: "email is required" });
    }
    const data = await adminApproveCustomerByEmail(email);
    return res.status(200).json(successResponse("Customer approved", data));
  } catch (error) {
    return next(error);
  }
};

export const getAdminCustomersController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const { page, limit, search } = req.query;
    const data = await getAdminCustomers(page, limit, search);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getAdminCustomerDetailsController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const customerId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const data = await getAdminCustomerDetails(customerId);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const updateAdminCustomerBlockStatusController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const customerId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const { is_blocked, reason } = req.body;
    const data = await updateAdminCustomerBlockStatus(customerId, is_blocked, reason);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getAdminCustomerRideHistoryController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const customerId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const data = await getAdminCustomerRideHistory(customerId);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};
