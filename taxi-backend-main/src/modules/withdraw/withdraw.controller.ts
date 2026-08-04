import { NextFunction, Request, Response } from "express";
import { isValidObjectId } from "mongoose";
import { HttpError } from "../../utils/http-error";
import { withdrawAmount } from "./withdraw.service";

export const withdrawWalletController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const driverId = req.authUser?.userId;
    if (!driverId || !isValidObjectId(driverId)) {
      throw new HttpError(401, "Unauthorized");
    }

    const amount = req.body.amount as number;
    const data = await withdrawAmount(driverId, amount);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

