import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../../middlewares/auth.middleware";
import { validate } from "../../middlewares/validate.middleware";
import { usersController } from "./users.controller";

const usersRouter = Router();

const saveFcmTokenSchema = z.object({
  body: z.object({
    fcm_token: z.string().min(1, "fcm_token is required"),
  }),
  params: z.object({}),
  query: z.object({}),
});

usersRouter.get("/base", usersController.base);
usersRouter.post(
  "/save-fcm-token",
  requireAuth,
  validate(saveFcmTokenSchema),
  usersController.saveFcmToken
);

export default usersRouter;
