import { Router } from "express";
import { loginController, refreshController } from "./auth.controller";
import { validate } from "../../middlewares/validate.middleware";
import { loginSchema, refreshSchema } from "./auth.validation";

const authRouter = Router();

authRouter.post("/login", validate(loginSchema), loginController);
authRouter.post("/refresh", validate(refreshSchema), refreshController);

export default authRouter;
