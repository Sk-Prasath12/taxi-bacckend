import type { Request } from "express";
import multer from "multer";

/** Allowed multipart field names for the actual file (Postman-friendly). */
const DRIVER_DOC_FIELD_NAMES = ["file", "aadhar", "document"] as const;

export const driverDocumentFileUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 15 * 1024 * 1024 },
}).fields(
  DRIVER_DOC_FIELD_NAMES.map((name) => ({
    name,
    maxCount: 1,
  }))
);

export function getDriverUploadedFile(req: Request): Express.Multer.File | undefined {
  const files = req.files as Record<string, Express.Multer.File[]> | undefined;
  if (!files) {
    return undefined;
  }
  for (const name of DRIVER_DOC_FIELD_NAMES) {
    const file = files[name]?.[0];
    if (file) {
      return file;
    }
  }
  return undefined;
}
