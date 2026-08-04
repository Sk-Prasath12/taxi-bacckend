import { NextFunction, Request, Response } from "express";
import {
  createZone,
  getAllZones,
  toggleZoneStatus,
  updateZone,
} from "./operational-zone.service";
import { HttpError } from "../../utils/http-error";

export const createOperationalZoneController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const adminId = req.authUser?.userId;
    if (!adminId) {
      throw new HttpError(401, "Unauthorized");
    }

    const { zone_name, coordinates } = req.body;
    const data = await createZone({
      zone_name,
      coordinates,
      created_by: adminId,
    });

    return res.status(201).json({
      success: true,
      message: "Operational zone created successfully",
      data,
    });
  } catch (error) {
    return next(error);
  }
};

export const getOperationalZonesController = async (
  _req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const data = await getAllZones();
    return res.status(200).json({
      success: true,
      message: "Operational zones fetched successfully",
      data,
    });
  } catch (error) {
    return next(error);
  }
};

export const updateOperationalZoneController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const { id } = req.params;
    const { zone_name, coordinates } = req.body;
    const data = await updateZone(String(id), { zone_name, coordinates });

    return res.status(200).json({
      success: true,
      message: "Operational zone updated successfully",
      data,
    });
  } catch (error) {
    return next(error);
  }
};

export const toggleOperationalZoneStatusController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const { id } = req.params;
    const { is_active } = req.body;
    const data = await toggleZoneStatus(String(id), is_active);

    return res.status(200).json({
      success: true,
      message: "Operational zone status updated successfully",
      data,
    });
  } catch (error) {
    return next(error);
  }
};
