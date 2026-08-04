import { Router } from "express";
import { requireAuth } from "../../middlewares/auth.middleware";
import { requireRole } from "../../middlewares/role.middleware";
import { validate } from "../../middlewares/validate.middleware";
import { getVerifiedDriversController } from "../admin/admin.controller";
import {
  adminDownloadDocumentController,
  adminFinalApproveDriverController,
  adminListDriverDocumentsController,
  adminListDriversVerificationController,
  adminUpdateDocumentStatusController,
  driverDownloadDocumentController,
  driverGetDocumentController,
  driverListDocumentsController,
  driverReuploadDocumentController,
  driverSubmitDocumentsController,
  driverUploadDocumentController,
} from "./driver-document.controller";
import {
  adminDocumentIdSchema,
  adminDocumentStatusSchema,
  adminDriverIdSchema,
  adminFinalApproveSchema,
  driverDocumentIdSchema,
  driverUploadDocumentSchema,
} from "./driver-document.validation";
import { driverDocumentFileUpload } from "./driver-document.upload";

export const driverDocumentsDriverRouter = Router();

driverDocumentsDriverRouter.post(
  "/api/drivers/documents/upload",
  requireAuth,
  requireRole(["DRIVER"]),
  driverDocumentFileUpload,
  validate(driverUploadDocumentSchema),
  driverUploadDocumentController
);

driverDocumentsDriverRouter.get(
  "/api/drivers/documents",
  requireAuth,
  requireRole(["DRIVER"]),
  driverListDocumentsController
);

driverDocumentsDriverRouter.post(
  "/api/drivers/documents/submit",
  requireAuth,
  requireRole(["DRIVER"]),
  driverSubmitDocumentsController
);

driverDocumentsDriverRouter.get(
  "/api/drivers/documents/:id",
  requireAuth,
  requireRole(["DRIVER"]),
  validate(driverDocumentIdSchema),
  driverGetDocumentController
);

driverDocumentsDriverRouter.get(
  "/api/drivers/documents/:id/download",
  requireAuth,
  requireRole(["DRIVER"]),
  validate(driverDocumentIdSchema),
  driverDownloadDocumentController
);

driverDocumentsDriverRouter.put(
  "/api/drivers/documents/:id/reupload",
  requireAuth,
  requireRole(["DRIVER"]),
  driverDocumentFileUpload,
  validate(driverDocumentIdSchema),
  driverReuploadDocumentController
);

export const driverDocumentsAdminRouter = Router();
driverDocumentsAdminRouter.use(requireAuth, requireRole(["ADMIN"]));

/** Literal route must be registered before `/drivers/:driverId/...` so "verified" is not captured as an id. */
driverDocumentsAdminRouter.get("/drivers/verified", getVerifiedDriversController);

driverDocumentsAdminRouter.get("/drivers/verification", adminListDriversVerificationController);

driverDocumentsAdminRouter.get(
  "/drivers/:driverId/documents",
  validate(adminDriverIdSchema),
  adminListDriverDocumentsController
);

driverDocumentsAdminRouter.get(
  "/documents/:id/download",
  validate(adminDocumentIdSchema),
  adminDownloadDocumentController
);

driverDocumentsAdminRouter.patch(
  "/documents/:id/status",
  validate(adminDocumentStatusSchema),
  adminUpdateDocumentStatusController
);

driverDocumentsAdminRouter.patch(
  "/drivers/:driverId/approve",
  validate(adminFinalApproveSchema),
  adminFinalApproveDriverController
);
