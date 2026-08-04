import { NextFunction, Request, Response } from "express";
import {
  acceptIncomingRide,
  completeRideAfterPayment,
  confirmCashReceived,
  getDriverActiveRide,
  getDriverRideById,
  getDriverRideHistory,
  getIncomingRides,
  markRideArrivedAtPickup,
  markRideDropped,
  markRideInTransit,
  markRidePickedUp,
  rejectIncomingRide,
  verifyDropOtp,
  verifyRideOtpAndStartRide,
  updateRideStatusByDriver,
} from "./driver-ride.service";

const getRideIdParam = (req: Request) =>
  Array.isArray(req.params.rideId) ? req.params.rideId[0] : req.params.rideId;

export const getDriverActiveRideController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await getDriverActiveRide(req.authUser?.userId);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getIncomingRidesController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const latRaw = req.query.lat;
    const lngRaw = req.query.lng;
    const lat = typeof latRaw === "string" ? Number(latRaw) : undefined;
    const lng = typeof lngRaw === "string" ? Number(lngRaw) : undefined;
    const data = await getIncomingRides(req.authUser?.userId, {
      lat: Number.isFinite(lat) ? lat : undefined,
      lng: Number.isFinite(lng) ? lng : undefined,
    });
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const rejectIncomingRideController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await rejectIncomingRide(req.authUser?.userId, getRideIdParam(req));
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const acceptIncomingRideController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await acceptIncomingRide(req.authUser?.userId, getRideIdParam(req));
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const acceptIncomingRideByBodyController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const data = await acceptIncomingRide(req.authUser?.userId, req.body.ride_id as string);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const markRideArrivedAtPickupController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const data = await markRideArrivedAtPickup(req.authUser?.userId, getRideIdParam(req));
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const markRidePickedUpController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await markRidePickedUp(req.authUser?.userId, getRideIdParam(req));
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const markRideInTransitController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await markRideInTransit(req.authUser?.userId, getRideIdParam(req));
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const verifyRideOtpController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await verifyRideOtpAndStartRide(
      req.authUser?.userId,
      getRideIdParam(req),
      req.body.otp as number
    );
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const markRideDroppedController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const body = req.body as Record<string, unknown>;
    const data = await markRideDropped(req.authUser?.userId, getRideIdParam(req), {
      fare: typeof body.fare === "number" ? body.fare : undefined,
      lat: typeof body.lat === "number" ? body.lat : undefined,
      lng: typeof body.lng === "number" ? body.lng : undefined,
      actual_distance_km:
        typeof body.actual_distance_km === "number" ? body.actual_distance_km : undefined,
      duration_min: typeof body.duration_min === "number" ? body.duration_min : undefined,
      address: typeof body.address === "string" ? body.address : undefined,
    });
    return res.status(200).json({ success: true, ...data });
  } catch (error) {
    return next(error);
  }
};

export const verifyDropOtpController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await verifyDropOtp(
      req.authUser?.userId,
      getRideIdParam(req),
      req.body.otp as number
    );
    return res.status(200).json({ success: true, ...data });
  } catch (error) {
    return next(error);
  }
};

export const confirmCashReceivedController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const data = await confirmCashReceived(req.authUser?.userId, getRideIdParam(req));
    return res.status(200).json({ success: true, ...data });
  } catch (error) {
    return next(error);
  }
};

export const completeRideController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await completeRideAfterPayment(req.authUser?.userId, getRideIdParam(req));
    return res.status(200).json({ success: true, ...data });
  } catch (error) {
    return next(error);
  }
};

export const getDriverRideByIdController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await getDriverRideById(req.authUser?.userId, getRideIdParam(req));
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getDriverRideHistoryController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const data = await getDriverRideHistory(req.authUser?.userId);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const updateRideStatusController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const rideId = Array.isArray(req.params.rideId) ? req.params.rideId[0] : req.params.rideId;
    const status = req.body.status as string;
    const data = await updateRideStatusByDriver(req.authUser?.userId, rideId, status);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};
