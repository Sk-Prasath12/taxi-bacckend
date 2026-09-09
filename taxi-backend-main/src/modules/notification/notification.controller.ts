import { NextFunction, Request, Response } from "express";
import { HttpError } from "../../utils/http-error";
import { successResponse } from "../../utils/api-response";
import { UserModel } from "../users/users.model";

export const saveNotificationTokenController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const userId = req.authUser?.userId;
    const token = String(req.body?.token ?? "").trim();

    if (!userId) {
      throw new HttpError(401, "Unauthorized");
    }
    if (!token) {
      throw new HttpError(400, "token is required");
    }

    const user = await UserModel.findById(userId);
    if (!user) {
      throw new HttpError(404, "User not found");
    }

    const role = (req.authUser?.role ?? user.role ?? "CUSTOMER").toUpperCase();
    const update =
      role === "DRIVER" ? { driver_fcm_token: token } : { fcm_token: token };

    await UserModel.findByIdAndUpdate(userId, update, { new: true });
    console.log("✅ FCM token saved:", userId, role);

    return res.status(200).json(successResponse("FCM token saved"));
  } catch (error) {
    return next(error);
  }
};
