import { NextFunction, Request, Response } from "express";
import multer from "multer";
import { logger } from "../config/logger";
import { errorResponse } from "../utils/api-response";

type ErrorWithStatus = Error & { statusCode?: number };

function multerClientMessage(err: multer.MulterError): string {
  if (err.code === "LIMIT_UNEXPECTED_FILE") {
    return `Unexpected form field "${err.field ?? ""}". Allowed file field names are: file, aadhar, document.`;
  }
  if (err.code === "LIMIT_FILE_SIZE") {
    return "File too large. Maximum size is 15 MB.";
  }
  return err.message || "Upload failed";
}

export const notFoundHandler = (req: Request, res: Response) => {
  return res.status(404).json(
    errorResponse("Route not found", {
      method: req.method,
      path: req.originalUrl,
      hint: "Check method and endpoint path. Example: POST /api/v1/auth/login",
    })
  );
};

export const globalErrorHandler = (
  err: ErrorWithStatus,
  req: Request,
  res: Response,
  _next: NextFunction
) => {
  if (err instanceof multer.MulterError) {
    logger.warn({ err }, "Multer upload rejected");
    return res.status(400).json(
      errorResponse(multerClientMessage(err), {
        method: req.method,
        path: req.originalUrl,
        code: err.code,
        field: err.field,
      })
    );
  }

  const statusCode = err.statusCode || 500;
  logger.error({ err }, "Request failed");

  if (statusCode >= 500) {
    return res.status(statusCode).json(
      errorResponse("Internal server error", {
        method: req.method,
        path: req.originalUrl,
      })
    );
  }

  return res.status(statusCode).json(
    errorResponse(err.message, {
      method: req.method,
      path: req.originalUrl,
    })
  );
};
