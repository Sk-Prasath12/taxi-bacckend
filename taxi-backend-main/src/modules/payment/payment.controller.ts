import { NextFunction, Request, Response } from "express";
import { createPaymentOrder, verifyPayment } from "./payment.service";

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
