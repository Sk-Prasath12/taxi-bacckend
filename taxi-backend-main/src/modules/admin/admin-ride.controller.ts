import { NextFunction, Request, Response } from "express";
import { successResponse } from "../../utils/api-response";
import { getAdminLiveRideDetail, getAdminRideHistoryDetail, listAdminLiveRides, listAdminRideHistory } from "./admin-ride.service";

export const listLiveRidesController = async (
  _req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const rides = await listAdminLiveRides();
    return res.status(200).json(
      successResponse("Live rides fetched successfully", {
        total: rides.length,
        rides,
      })
    );
  } catch (error) {
    return next(error);
  }
};

export const getLiveRideDetailController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const rideId = String(req.params.rideId ?? "");
    const ride = await getAdminLiveRideDetail(rideId);
    if (!ride) {
      return res.status(404).json({ success: false, message: "Ride not found" });
    }
    return res.status(200).json(successResponse("Live ride detail fetched", { ride }));
  } catch (error) {
    return next(error);
  }
};

export const listRideHistoryController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const statusRaw = typeof req.query.status === "string" ? req.query.status : "all";
    const status =
      statusRaw === "active" ||
      statusRaw === "completed" ||
      statusRaw === "cancelled" ||
      statusRaw === "all"
        ? statusRaw
        : "all";
    const rides = await listAdminRideHistory({ status, limit: 150 });
    return res.status(200).json(
      successResponse("Ride history fetched successfully", {
        total: rides.length,
        rides,
      })
    );
  } catch (error) {
    return next(error);
  }
};

export const getRideHistoryDetailController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const rideId = String(req.params.rideId ?? "");
    const ride = await getAdminRideHistoryDetail(rideId);
    if (!ride) {
      return res.status(404).json({ success: false, message: "Ride not found" });
    }
    return res.status(200).json(successResponse("Ride detail fetched", { ride }));
  } catch (error) {
    return next(error);
  }
};
