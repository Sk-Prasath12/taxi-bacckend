import { NextFunction, Request, Response } from "express";
import {
  getAdminDashboardMetrics,
  getDriverDueById,
  getRevenueList,
  getRevenueSummary,
} from "./finance.service";

export const getRevenueSummaryController = async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await getRevenueSummary();
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getRevenueListController = async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await getRevenueList();
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getDriverDueController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await getDriverDueById(req.params.driverId as string);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getAdminDashboardMetricsController = async (
  _req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const data = await getAdminDashboardMetrics();
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};
