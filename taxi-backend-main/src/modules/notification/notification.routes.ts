import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../../middlewares/auth.middleware";
import { validate } from "../../middlewares/validate.middleware";
import { saveNotificationTokenController } from "./notification.controller";

const saveNotificationTokenSchema = z.object({
  body: z.object({
    token: z.string().min(1, "token is required"),
  }),
  params: z.object({}),
  query: z.object({}),
});

const notificationRouter = Router();

notificationRouter.post(
  "/api/notifications/save-token",
  requireAuth,
  validate(saveNotificationTokenSchema),
  saveNotificationTokenController
);

export default notificationRouter;
