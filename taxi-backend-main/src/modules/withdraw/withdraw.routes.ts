import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../../middlewares/auth.middleware";
import { requireRole } from "../../middlewares/role.middleware";
import { validate } from "../../middlewares/validate.middleware";
import { withdrawWalletController } from "./withdraw.controller";

const withdrawSchema = z.object({
  body: z.object({
    amount: z.number().positive(),
  }),
  params: z.object({}),
  query: z.object({}),
});

const withdrawRouter = Router();

withdrawRouter.post(
  "/api/driver/wallet/withdraw",
  requireAuth,
  requireRole(["DRIVER"]),
  validate(withdrawSchema),
  withdrawWalletController
);

export default withdrawRouter;

