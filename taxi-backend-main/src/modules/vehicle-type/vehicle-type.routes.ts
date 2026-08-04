import { Router } from "express";
import {
  getActiveVehicleTypesController,
  getVehicleTypesController,
} from "./vehicle-type.controller";

const vehicleTypeRouter = Router();

vehicleTypeRouter.get("/", getVehicleTypesController);
vehicleTypeRouter.get("/active", getActiveVehicleTypesController);

export default vehicleTypeRouter;
