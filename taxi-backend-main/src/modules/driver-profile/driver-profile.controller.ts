import { NextFunction, Request, Response } from "express";
import { successResponse } from "../../utils/api-response";
import { HttpError } from "../../utils/http-error";
import {
  completeProfile,
  createOrUpdateProfile,
  getProfile,
} from "./driver-profile.service";
import type { UpsertDriverProfileInput } from "./driver-profile.validation";

function requireUserId(req: Request): string {
  const id = req.authUser?.userId;
  if (!id) {
    throw new HttpError(401, "Unauthorized");
  }
  return id;
}

export const upsertDriverProfileController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const userId = requireUserId(req);
    const body = req.body as UpsertDriverProfileInput;
    const profile = await createOrUpdateProfile(userId, body);
    return res.status(200).json(successResponse("Driver profile saved", profile));
  } catch (error) {
    return next(error as Error);
  }
};

export const getDriverProfileExtendedController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const userId = requireUserId(req);
    const profile = await getProfile(userId);
    return res.status(200).json(successResponse("Driver profile", profile));
  } catch (error) {
    return next(error as Error);
  }
};

export const completeDriverProfileController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const userId = requireUserId(req);
    const profile = await completeProfile(userId);
    return res.status(200).json(successResponse("Driver profile marked complete", profile));
  } catch (error) {
    return next(error as Error);
  }
};
