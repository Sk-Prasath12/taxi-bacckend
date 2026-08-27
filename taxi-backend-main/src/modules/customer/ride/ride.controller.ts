import { NextFunction, Request, Response } from "express";
import {
  abandonActiveRide,
  cancelRide,
  confirmRide,
  getActiveRide,
  getRideHistoryById,
  getCustomerRideInvoice,
  getRideHistory,
  getRideStatus,
  requestRide,
  triggerRideEmergency,
} from "./ride.service";

export const requestRideController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const {
      pickup_lat,
      pickup_lng,
      pickup_address,
      drop_lat,
      drop_lng,
      drop_address,
      vehicle_type_id,
      payment_mode,
    } = req.body;
    const data = await requestRide(
      req.authUser?.userId,
      pickup_lat,
      pickup_lng,
      typeof pickup_address === "string" ? pickup_address : "",
      drop_lat,
      drop_lng,
      typeof drop_address === "string" ? drop_address : "",
      vehicle_type_id,
      { payment_mode }
    );
    return res.status(201).json(data);
  } catch (error) {
    return next(error);
  }
};

export const confirmRideController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { ride_id, payment_mode } = req.body;
    const data = await confirmRide(req.authUser?.userId, ride_id, { payment_mode });
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getActiveRideController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const data = await getActiveRide(req.authUser?.userId);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const abandonActiveRideController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const data = await abandonActiveRide(req.authUser?.userId);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getRideStatusController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const rideId = Array.isArray(req.params.rideId) ? req.params.rideId[0] : req.params.rideId;
    const data = await getRideStatus(req.authUser?.userId, rideId);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const cancelRideController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const rideId = Array.isArray(req.params.rideId) ? req.params.rideId[0] : req.params.rideId;
    const data = await cancelRide(req.authUser?.userId, rideId);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getRideHistoryController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const data = await getRideHistory(req.authUser?.userId);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getRideHistoryByIdController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const rideId = Array.isArray(req.params.rideId) ? req.params.rideId[0] : req.params.rideId;
    const data = await getRideHistoryById(req.authUser?.userId, rideId);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getRideInvoiceController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const rideId = Array.isArray(req.params.rideId) ? req.params.rideId[0] : req.params.rideId;
    const data = await getCustomerRideInvoice(req.authUser?.userId, rideId);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const triggerRideEmergencyController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const rideId = Array.isArray(req.params.rideId) ? req.params.rideId[0] : req.params.rideId;
    const data = await triggerRideEmergency(req.authUser?.userId, rideId, {
      lat: typeof req.body?.lat === "number" ? req.body.lat : undefined,
      lng: typeof req.body?.lng === "number" ? req.body.lng : undefined,
      address: typeof req.body?.address === "string" ? req.body.address : undefined,
    });
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};
