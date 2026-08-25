import { NextFunction, Request, Response } from "express";
import {
  createPaymentOrder,
  listAdminPaymentHistory,
  listCustomerPaymentHistory,
  listDriverPaymentHistory,
  verifyPayment,
} from "./payment.service";
import { successResponse } from "../../utils/api-response";

export const createPaymentOrderController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const data = await createPaymentOrder(req.authUser?.userId, req.body.ride_id as string);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const verifyPaymentController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await verifyPayment(req.authUser?.userId, {
      ride_id: req.body.ride_id as string,
      order_id: req.body.order_id as string,
      payment_id: req.body.payment_id as string,
      signature: req.body.signature as string,
    });
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const customerPaymentHistoryController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const limit = Number(req.query.limit ?? 50);
    const payments = await listCustomerPaymentHistory(req.authUser?.userId, limit);
    return res.status(200).json(successResponse("Payment history fetched", { payments }));
  } catch (error) {
    return next(error);
  }
};

export const driverPaymentHistoryController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const limit = Number(req.query.limit ?? 50);
    const payments = await listDriverPaymentHistory(req.authUser?.userId, limit);
    return res.status(200).json(successResponse("Driver payment history fetched", { payments }));
  } catch (error) {
    return next(error);
  }
};

export const adminPaymentHistoryController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const limit = Number(req.query.limit ?? 100);
    const payments = await listAdminPaymentHistory(limit);
    return res.status(200).json(successResponse("Admin payment history fetched", { payments }));
  } catch (error) {
    return next(error);
  }
};
