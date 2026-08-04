import { NextFunction, Request, Response } from "express";
import { successResponse } from "../../utils/api-response";
import { loginUser, refreshAccessToken } from "./auth.service";

export const loginController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { email, password } = req.body;
    const data = await loginUser(email, password);
    return res.status(200).json(successResponse("Login successful", data));
  } catch (error) {
    return next(error);
  }
};

export const refreshController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { refreshToken } = req.body;
    const data = await refreshAccessToken(refreshToken);
    return res.status(200).json(successResponse("Token refreshed", data));
  } catch (error) {
    return next(error);
  }
};
