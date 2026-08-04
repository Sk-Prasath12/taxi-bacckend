import { Router } from "express";
import { z } from "zod";
import { validate } from "../../middlewares/validate.middleware";
import {
  getAdminDashboardMetricsController,
  getDriverDueController,
  getRevenueListController,
  getRevenueSummaryController,
} from "./finance.controller";

const driverIdParamSchema = z.object({
  params: z.object({
    driverId: z.string().regex(/^[a-fA-F0-9]{24}$/, "Invalid driver id"),
  }),
  body: z.object({}).optional(),
  query: z.object({}).optional(),
});

const financeRouter = Router();

financeRouter.get("/revenue/summary", getRevenueSummaryController);
financeRouter.get("/revenue/list", getRevenueListController);
financeRouter.get("/driver/:driverId/due", validate(driverIdParamSchema), getDriverDueController);
financeRouter.get("/dashboard/metrics", getAdminDashboardMetricsController);

export default financeRouter;
