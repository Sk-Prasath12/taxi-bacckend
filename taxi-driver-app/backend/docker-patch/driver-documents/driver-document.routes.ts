import { Router } from "express";
import multer from "multer";
import path from "path";
import fs from "fs";
import { requireAuth } from "../../middlewares/auth.middleware";
import { requireRole } from "../../middlewares/role.middleware";
import { DriverDocumentModel } from "./driver-document.model";

const uploadRoot = path.join(process.cwd(), "uploads", "drivers");
fs.mkdirSync(uploadRoot, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, _file, cb) => {
    const driverId = String((req as { user?: { sub?: string } }).user?.sub ?? "unknown");
    const dir = path.join(uploadRoot, driverId);
    fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: (_req, file, cb) => {
    const safe = file.originalname.replace(/[^a-zA-Z0-9._-]/g, "_");
    cb(null, `${Date.now()}_${safe}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 8 * 1024 * 1024 },
});

export const driverDocumentRouter = Router();

driverDocumentRouter.get(
  "/api/drivers/documents",
  requireAuth,
  requireRole("DRIVER"),
  async (req, res, next) => {
    try {
      const driverId = String(req.user?.sub ?? "");
      const documents = await DriverDocumentModel.find({ driver_id: driverId })
        .sort({ updated_at: -1 })
        .lean();
      res.json({ success: true, documents });
    } catch (error) {
      next(error);
    }
  }
);

driverDocumentRouter.post(
  "/api/drivers/documents",
  requireAuth,
  requireRole("DRIVER"),
  upload.single("file"),
  async (req, res, next) => {
    try {
      const driverId = String(req.user?.sub ?? "");
      const documentType = String(req.query.document_type ?? "PERSONAL").toUpperCase();
      const documentSlot = String(req.query.document_slot ?? req.file?.originalname ?? "document");
      if (!req.file) {
        res.status(400).json({ success: false, message: "file is required" });
        return;
      }

      const relative = path
        .relative(process.cwd(), req.file.path)
        .split(path.sep)
        .join("/");
      const fileUrl = `/${relative}`;

      const document = await DriverDocumentModel.findOneAndUpdate(
        { driver_id: driverId, document_slot: documentSlot },
        {
          driver_id: driverId,
          document_type: documentType,
          document_slot: documentSlot,
          file_url: fileUrl,
          file_name: req.file.originalname,
          mime_type: req.file.mimetype,
          status: "PENDING",
          rejection_reason: null,
        },
        { upsert: true, new: true, setDefaultsOnInsert: true }
      ).lean();

      res.status(201).json({ success: true, document });
    } catch (error) {
      next(error);
    }
  }
);
