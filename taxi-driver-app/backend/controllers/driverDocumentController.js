const fs = require("fs");
const path = require("path");
const multer = require("multer");
const {
  DriverDocument,
  DRIVER_DOC_TYPES
} = require("../models/DriverDocument");
const { syncDriverVerificationState } = require("../services/driverVerification");

const uploadRoot = path.join(__dirname, "..", "uploads", "driver-docs");
fs.mkdirSync(uploadRoot, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dir = path.join(uploadRoot, String(req.driver._id));
    fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    const slot = String(req.query.document_slot || "document").replace(/[^\w-]/g, "_");
    const ext = path.extname(file.originalname || "") || ".jpg";
    cb(null, `${slot}${ext}`);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 8 * 1024 * 1024 }
});

const listDocuments = async (req, res) => {
  const documents = await DriverDocument.find({ driver_id: req.driver._id }).sort({ updatedAt: -1 });
  return res.json({ success: true, documents });
};

const uploadDocument = async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ success: false, message: "file is required." });
  }

  const documentType = String(req.query.document_type || "PERSONAL").toUpperCase();
  if (!DRIVER_DOC_TYPES.includes(documentType)) {
    return res.status(400).json({ success: false, message: "Invalid document_type." });
  }

  const documentSlot = String(req.query.document_slot || req.file.originalname || "document").trim();
  const relativeUrl = `/uploads/driver-docs/${req.driver._id}/${req.file.filename}`;

  const document = await DriverDocument.findOneAndUpdate(
    { driver_id: req.driver._id, document_slot: documentSlot },
    {
      $set: {
        driver_id: req.driver._id,
        document_type: documentType,
        document_slot: documentSlot,
        file_url: relativeUrl,
        file_name: req.file.originalname || req.file.filename,
        mime_type: req.file.mimetype || "application/octet-stream",
        status: "PENDING",
        rejection_reason: ""
      }
    },
    { upsert: true, new: true }
  );

  await syncDriverVerificationState(req.driver._id);

  return res.status(201).json({ success: true, document });
};

const submitForReview = async (req, res) => {
  const driver = await syncDriverVerificationState(req.driver._id);
  if (!driver) {
    return res.status(404).json({ success: false, message: "Driver not found." });
  }
  return res.json({
    success: true,
    message: "Documents saved (optional). Account approval is separate from admin.",
    driver_verification_status: driver?.driver_verification_status,
    is_driver_verified: driver?.is_driver_verified === true
  });
};

module.exports = {
  uploadMiddleware: upload.single("file"),
  listDocuments,
  uploadDocument,
  submitForReview
};
