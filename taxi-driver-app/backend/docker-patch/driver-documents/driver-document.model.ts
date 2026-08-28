import { Schema, model, HydratedDocument } from "mongoose";

export type DriverDocumentEntity = {
  driver_id: string;
  document_type: "PERSONAL" | "IDENTITY" | "VEHICLE";
  document_slot: string;
  file_url: string;
  file_name?: string;
  mime_type?: string;
  status: "PENDING" | "APPROVED" | "REJECTED";
  rejection_reason?: string | null;
};

export type DriverDocumentDoc = HydratedDocument<DriverDocumentEntity>;

const driverDocumentSchema = new Schema<DriverDocumentEntity>(
  {
    driver_id: { type: String, required: true, index: true },
    document_type: {
      type: String,
      enum: ["PERSONAL", "IDENTITY", "VEHICLE"],
      required: true,
    },
    document_slot: { type: String, required: true, trim: true },
    file_url: { type: String, required: true },
    file_name: { type: String },
    mime_type: { type: String },
    status: {
      type: String,
      enum: ["PENDING", "APPROVED", "REJECTED"],
      default: "PENDING",
    },
    rejection_reason: { type: String, default: null },
  },
  {
    collection: "driver_documents",
    timestamps: { createdAt: "created_at", updatedAt: "updated_at" },
  }
);

driverDocumentSchema.index({ driver_id: 1, document_slot: 1 }, { unique: true });

export const DriverDocumentModel = model<DriverDocumentEntity>(
  "DriverDocument",
  driverDocumentSchema
);
