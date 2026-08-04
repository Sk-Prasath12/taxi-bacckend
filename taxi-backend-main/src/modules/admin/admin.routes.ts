import { Router } from "express";
import { adminTestController, getActiveDriversController } from "./admin.controller";
import { requireAuth } from "../../middlewares/auth.middleware";
import { requireRole } from "../../middlewares/role.middleware";
import adminCustomerRouter from "./customer/admin-customer.routes";
import adminDriverRouter from "./driver/admin-driver.routes";
import financeRouter from "../finance/finance.routes";

const adminRouter = Router();

adminRouter.use(requireAuth, requireRole(["ADMIN"]));
adminRouter.get("/test", adminTestController);
adminRouter.get("/drivers/active", getActiveDriversController);
adminRouter.use("/customers", adminCustomerRouter);
adminRouter.use("/drivers", adminDriverRouter);
adminRouter.use("/", financeRouter);

export default adminRouter;
