import { Router } from "express";
import { requireAuth } from "../../middlewares/auth.middleware";
import { requireRole } from "../../middlewares/role.middleware";
import { validate } from "../../middlewares/validate.middleware";
import {
  createRatingController,
  getAdminRatingsController,
  getMyRatingsController,
  getMyRatingSummaryController,
} from "./rating.controller";
import { adminRatingsQuerySchema, createRatingSchema } from "./rating.validator";

const ratingRouter = Router();
ratingRouter.post(
  "/api/ratings",
  requireAuth,
  requireRole(["CUSTOMER", "DRIVER"]),
  validate(createRatingSchema),
  createRatingController
);
ratingRouter.get("/api/ratings/me", requireAuth, requireRole(["CUSTOMER", "DRIVER"]), getMyRatingsController);
ratingRouter.get(
  "/api/ratings/me/summary",
  requireAuth,
  requireRole(["CUSTOMER", "DRIVER"]),
  getMyRatingSummaryController
);

/** Mounted at `/api/admin` — do NOT use router-level auth at app root (that blocks GET /). */
const adminRatingRouter = Router();
adminRatingRouter.get(
  "/ratings",
  requireAuth,
  requireRole(["ADMIN"]),
  validate(adminRatingsQuerySchema),
  getAdminRatingsController
);

export { ratingRouter, adminRatingRouter };

