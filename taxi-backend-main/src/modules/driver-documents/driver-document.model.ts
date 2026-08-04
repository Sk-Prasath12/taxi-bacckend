import { Schema, Types, model, HydratedDocument } from "mongoose";

export const DRIVER_DOCUMENT_TYPES = ["IDENTITY", "VEHICLE", "BANK", "PERSONAL"] as const;
export type DriverDocumentType = (typeof DRIVER_DOCUMENT_TYPES)[number];

export const DRIVER_DOCUMENT_STATUSES = ["PENDING", "APPROVED", "REJECTED"] as const;
export type DriverDocumentStatus = (typeof DRIVER_DOCUMENT_STATUSES)[number];

export type DriverDocumentEntity = {
  user_id: Types.ObjectId;
  document_type: DriverDocumentType;
  file_url: string;
  file_key: string;
  status: DriverDocumentStatus;
  rejection_reason?: string;
};

export type DriverDocumentDocument = HydratedDocument<DriverDocumentEntity>;

const driverDocumentSchema = new Schema<DriverDocumentEntity>(
  {
    user_id: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    document_type: {
      type: String,
      enum: DRIVER_DOCUMENT_TYPES,
      required: true,
    },
    file_url: { type: String, required: true, trim: true },
    file_key: { type: String, required: true, trim: true },
    status: {
      type: String,
      enum: DRIVER_DOCUMENT_STATUSES,
      default: "PENDING",
    },
    rejection_reason: { type: String, default: undefined, trim: true },
  },
  {
    collection: "driver_documents",
    timestamps: true,
  }
);

/** Non-unique: multiple uploads per type are allowed; reupload replaces a specific doc by id. */
driverDocumentSchema.index({ user_id: 1, document_type: 1 });

export const DriverDocumentModel = model<DriverDocumentEntity>("DriverDocument", driverDocumentSchema);
