import { Request, Response } from "express";
import { successResponse } from "../../utils/api-response";
import { saveFcmToken } from "./users.service";

export const usersController = {
  base: (_req: Request, res: Response) =>
    res.status(200).json(successResponse("Users module ready")),
  saveFcmToken: async (req: Request, res: Response) => {
    const data = await saveFcmToken(req.authUser?.userId, String(req.body.fcm_token ?? ""));
    return res.status(200).json(successResponse(data.message));
  },
};
