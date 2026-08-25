import { Router } from "express";
import { adminTestController, getActiveDriversController } from "./admin.controller";
import { getLiveRideDetailController, getRideHistoryDetailController, listLiveRidesController, listRideHistoryController } from "./admin-ride.controller";
import { requireAuth } from "../../middlewares/auth.middleware";
import { requireRole } from "../../middlewares/role.middleware";
import adminCustomerRouter from "./customer/admin-customer.routes";
import adminDriverRouter from "./driver/admin-driver.routes";
import financeRouter from "../finance/finance.routes";

const adminRouter = Router();

adminRouter.use(requireAuth, requireRole(["ADMIN"]));
adminRouter.get("/test", adminTestController);
adminRouter.get("/drivers/active", getActiveDriversController);
adminRouter.get("/rides/live", listLiveRidesController);
adminRouter.get("/rides/live/:rideId", getLiveRideDetailController);
adminRouter.get("/rides/history", listRideHistoryController);
adminRouter.get("/rides/:rideId", getRideHistoryDetailController);
adminRouter.use("/customers", adminCustomerRouter);
adminRouter.use("/drivers", adminDriverRouter);
adminRouter.use("/", financeRouter);

export default adminRouter;
