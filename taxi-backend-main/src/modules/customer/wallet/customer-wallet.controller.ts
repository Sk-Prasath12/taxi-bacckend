import { NextFunction, Request, Response } from "express";
import {
  getCustomerWalletBalance,
  getCustomerWalletTransactions,
} from "./customer-wallet.service";

export const getCustomerWalletBalanceController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const data = await getCustomerWalletBalance(req.authUser?.userId);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getCustomerWalletTransactionsController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const limit = Number(req.query.limit ?? 50);
    const data = await getCustomerWalletTransactions(req.authUser?.userId, limit);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};
