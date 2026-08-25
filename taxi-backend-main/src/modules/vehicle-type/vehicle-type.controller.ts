import { NextFunction, Request, Response } from "express";
import { getActiveVehicleTypes, getAllVehicleTypes } from "./vehicle-type.service";

export const getVehicleTypesController = async (
  _req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const data = await getAllVehicleTypes();
    return res.status(200).json({ data, vehicle_types: data });
  } catch (error) {
    return next(error);
  }
};

export const getActiveVehicleTypesController = async (
  _req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const data = await getActiveVehicleTypes();
    return res.status(200).json({ data, vehicle_types: data });
  } catch (error) {
    return next(error);
  }
};
