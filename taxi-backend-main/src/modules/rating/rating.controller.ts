import { NextFunction, Request, Response } from "express";
import {
  createRating,
  getAllRatings,
  getAverageRating,
  getRatingsForUser,
} from "./rating.service";

const getAuthUser = (req: Request) => ({
  userId: req.authUser?.userId as string,
  role: req.authUser?.role as "ADMIN" | "CUSTOMER" | "DRIVER",
});

export const createRatingController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await createRating(getAuthUser(req), {
      ride_id: req.body.ride_id as string,
      rating: req.body.rating as number,
      review: req.body.review as string | undefined,
    });
    return res.status(201).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getMyRatingsController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await getRatingsForUser(req.authUser?.userId as string);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getMyRatingSummaryController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await getAverageRating(req.authUser?.userId as string);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getAdminRatingsController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await getAllRatings({
      role: req.query.role as string | undefined,
      rating: req.query.rating as string | undefined,
    });
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

