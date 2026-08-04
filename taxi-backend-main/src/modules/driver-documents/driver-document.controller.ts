import { NextFunction, Request, Response } from "express";
import { pipeline } from "node:stream/promises";
import { logger } from "../../config/logger";
import { successResponse } from "../../utils/api-response";
import { HttpError } from "../../utils/http-error";
import {
  adminFinalApproveDriver,
  adminGetDriverDocuments,
  adminGetDriversForVerification,
  adminUpdateDocumentStatus,
  streamAdminDocumentForDownload,
  streamDriverDocumentForDownload,
  type DocumentDownloadStream,
  getDocumentById,
  getDriverDocuments,
  reuploadDocument,
  submitDocumentsForAdminReview,
  uploadDocument,
} from "./driver-document.service";
import type { DriverDocumentType } from "./driver-document.model";
import { getDriverUploadedFile } from "./driver-document.upload";

type FileRequest = Request & { file?: Express.Multer.File };

function contentDispositionAttachment(filename: string): string {
  const ascii = filename.replace(/[^\x20-\x7E]/g, "_").replace(/"/g, '\\"');
  return `attachment; filename="${ascii}"`;
}

async function sendDocumentDownload(
  res: Response,
  next: NextFunction,
  load: () => Promise<DocumentDownloadStream>
): Promise<void> {
  try {
    const { stream, contentType, contentLength, filename } = await load();
    res.setHeader("Content-Type", contentType);
    res.setHeader("Content-Disposition", contentDispositionAttachment(filename));
    res.setHeader("Cache-Control", "private, no-store");
    if (contentLength != null && Number.isFinite(contentLength) && contentLength >= 0) {
      res.setHeader("Content-Length", String(contentLength));
    }
    await pipeline(stream, res);
  } catch (err) {
    if (!res.headersSent) {
      next(err as Error);
      return;
    }
    logger.warn({ err }, "document download stream failed after headers sent");
    res.destroy();
  }
}

export const driverUploadDocumentController = async (
  req: FileRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    if (!req.authUser?.userId) {
      return next(new HttpError(401, "Unauthorized"));
    }
    const uploaded = getDriverUploadedFile(req);
    if (!uploaded) {
      return next(
        new HttpError(
          400,
          'No file uploaded. Use form-data with field name "file", "aadhar", or "document".'
        )
      );
    }

    const documentType = req.query.document_type as DriverDocumentType;
    const data = await uploadDocument(req.authUser.userId, documentType, {
      buffer: uploaded.buffer,
      mimetype: uploaded.mimetype,
      originalname: uploaded.originalname,
    });

    return res.status(201).json(successResponse("Document uploaded successfully", data));
  } catch (error) {
    return next(error);
  }
};

export const driverListDocumentsController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    if (!req.authUser?.userId) {
      return next(new HttpError(401, "Unauthorized"));
    }

    const data = await getDriverDocuments(req.authUser.userId);
    return res.status(200).json(successResponse("Documents fetched successfully", data));
  } catch (error) {
    return next(error);
  }
};

export const driverGetDocumentController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    if (!req.authUser?.userId) {
      return next(new HttpError(401, "Unauthorized"));
    }

    const data = await getDocumentById(req.params.id as string, req.authUser.userId);
    return res.status(200).json(successResponse("Document fetched successfully", data));
  } catch (error) {
    return next(error);
  }
};

export const driverDownloadDocumentController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  if (!req.authUser?.userId) {
    return next(new HttpError(401, "Unauthorized"));
  }
  const docId = req.params.id as string;
  const userId = req.authUser.userId;
  await sendDocumentDownload(res, next, () => streamDriverDocumentForDownload(docId, userId));
};

export const driverReuploadDocumentController = async (
  req: FileRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    if (!req.authUser?.userId) {
      return next(new HttpError(401, "Unauthorized"));
    }
    const uploaded = getDriverUploadedFile(req);
    if (!uploaded) {
      return next(
        new HttpError(
          400,
          'No file uploaded. Use form-data with field name "file", "aadhar", or "document".'
        )
      );
    }

    const data = await reuploadDocument(req.params.id as string, req.authUser.userId, {
      buffer: uploaded.buffer,
      mimetype: uploaded.mimetype,
      originalname: uploaded.originalname,
    });

    return res.status(200).json(successResponse("Document re-uploaded successfully", data));
  } catch (error) {
    return next(error);
  }
};

export const driverSubmitDocumentsController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    if (!req.authUser?.userId) {
      return next(new HttpError(401, "Unauthorized"));
    }
    const data = await submitDocumentsForAdminReview(req.authUser.userId);
    return res.status(200).json(successResponse("Documents submitted for admin review", data));
  } catch (error) {
    return next(error);
  }
};

export const adminListDriversVerificationController = async (
  _req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const data = await adminGetDriversForVerification();
    return res.status(200).json(successResponse("Drivers pending verification", data));
  } catch (error) {
    return next(error);
  }
};

export const adminListDriverDocumentsController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const data = await adminGetDriverDocuments(req.params.driverId as string);
    return res.status(200).json(successResponse("Driver documents fetched successfully", data));
  } catch (error) {
    return next(error);
  }
};

export const adminUpdateDocumentStatusController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const { status, reason } = req.body as { status: "APPROVED" | "REJECTED"; reason?: string };
    const data = await adminUpdateDocumentStatus(req.params.id as string, status, reason);
    return res.status(200).json(successResponse("Document status updated", data));
  } catch (error) {
    return next(error);
  }
};

export const adminDownloadDocumentController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const docId = req.params.id as string;
  await sendDocumentDownload(res, next, () => streamAdminDocumentForDownload(docId));
};

export const adminFinalApproveDriverController = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const data = await adminFinalApproveDriver(req.params.driverId as string);
    return res.status(200).json(successResponse("Driver approved successfully", data));
  } catch (error) {
    return next(error);
  }
};
