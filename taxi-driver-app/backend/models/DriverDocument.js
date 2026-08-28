const mongoose = require("mongoose");

const DRIVER_DOC_TYPES = ["PERSONAL", "IDENTITY", "VEHICLE", "BANK"];
const DOC_REVIEW_STATUS = ["PENDING", "APPROVED", "REJECTED"];

const driverDocumentSchema = new mongoose.Schema(
  {
    driver_id: { type: mongoose.Schema.Types.ObjectId, ref: "Driver", required: true, index: true },
    document_type: { type: String, enum: DRIVER_DOC_TYPES, required: true },
    document_slot: { type: String, required: true, trim: true },
    file_url: { type: String, required: true },
    file_name: { type: String, default: "" },
    mime_type: { type: String, default: "application/octet-stream" },
    status: { type: String, enum: DOC_REVIEW_STATUS, default: "PENDING" },
    rejection_reason: { type: String, default: "" }
  },
  { timestamps: true }
);

driverDocumentSchema.index({ driver_id: 1, document_slot: 1 }, { unique: true });

module.exports = {
  DriverDocument: mongoose.model("DriverDocument", driverDocumentSchema),
  DRIVER_DOC_TYPES,
  DOC_REVIEW_STATUS,
  REQUIRED_DOCUMENT_SLOTS: [
    "driver_photo",
    "license",
    "rc",
    "insurance",
    "aadhaar",
    "vehicle_photos"
  ]
};
